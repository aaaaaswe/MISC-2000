# MISC-2000 取指单元、异常管理与原子指令 Spec

## Why
MISC-2000 采用变长 CISC 指令集（2/4/6/8 字节），需要专用的取指单元解析指令长度并处理跨页取指。同时需要异常管理模块在异常入口记录指令长度，并在 ERET 时正确计算返回地址。原子指令（LL/SC/CAS）和 GETILEN 辅助指令也需要相应的硬件支持。

## What Changes
- 新增变长指令取指单元（Instruction Fetch Unit），支持 2/4/6/8 字节指令
- 新增异常与长度管理模块，含 CSR_ILLEN 寄存器
- 新增原子指令支持（LL/SC/CAS），禁止跨页
- 新增 GETILEN 辅助指令（操作码 0x14F）硬件实现
- 新增 CSR 模块（CSR_ILLEN、CSR_EPC 等）
- 新增仿真测试用例

## Impact
- Affected specs: misc2000-init（新增模块，不修改已有模块）
- Affected code: rtl/core/ifu.sv, rtl/core/exception.sv, rtl/core/atomic.sv, rtl/core/csr.sv, rtl/core/getilen.sv, rtl/core/lsu.sv（修改）

## ADDED Requirements

### Requirement: 变长指令取指单元
取指单元 SHALL 按 2 字节对齐从指令缓存/内存读取指令首部，解析 bit[7:6] 确定指令总长度（00→2字节，01→4字节，10→6字节，11→8字节），然后读取剩余字节。

#### Scenario: 2 字节指令取指
- **WHEN** 首字节 bit[7:6] = 00
- **THEN** 指令总长度为 2 字节，仅需一次读取

#### Scenario: 8 字节指令取指
- **WHEN** 首字节 bit[7:6] = 11
- **THEN** 指令总长度为 8 字节，需读取剩余 6 字节

### Requirement: 跨页取指与异常地址
取指单元 SHALL 在指令跨页时，先检查指令起始页的指令首部，确认指令长度。若后续页未映射，触发缺页异常，异常地址 MUST 是指令起始地址（第一页中的地址），而非取指失败的中间地址。

#### Scenario: 跨页缺页异常
- **WHEN** 4 字节指令前 2 字节在页 N，后 2 字节在页 N+1（未映射）
- **THEN** 触发缺页异常，异常地址 = 页 N 中指令起始地址

### Requirement: CSR_ILLEN 异常指令长度记录
异常入口时，硬件 SHALL 自动将触发异常的指令长度写入 CSR `CSR_ILLEN`，值为 2/4/6/8。

#### Scenario: 异常时记录指令长度
- **WHEN** 一条 4 字节指令触发异常
- **THEN** CSR_ILLEN 被写入值 4

### Requirement: ERET 返回地址计算
ERET 指令执行时，硬件 SHALL 自动计算返回地址：`PC = CSR_EPC + CSR_ILLEN`。

#### Scenario: ERET 返回
- **WHEN** 执行 ERET，CSR_EPC = 0x1000，CSR_ILLEN = 4
- **THEN** PC = 0x1004

### Requirement: 原子指令禁止跨页
所有原子指令（LL.D, SC.D, CAS.D，操作码在 0x144–0x148）为 4 字节定长，SHALL 被禁止跨页。若检测到跨页，触发非法指令异常。

#### Scenario: 原子指令跨页检测
- **WHEN** 原子指令地址跨页边界
- **THEN** 触发非法指令异常，异常地址 = 指令起始地址

### Requirement: LL/SC 独占监视
LL 指令 SHALL 记录 64 字节对齐的独占监视区域。异常、中断或其他核的写入 SHALL 清除监视。内存顺序模型 SHALL 采用 RVWMO，提供 FENCE 指令作为显式屏障。

#### Scenario: LL 设置监视
- **WHEN** 执行 LL.D 指令
- **THEN** 记录 64 字节对齐的独占监视区域

#### Scenario: SC 成功
- **WHEN** 执行 SC.D 且监视区域未被清除
- **THEN** 写入成功，返回 0

#### Scenario: SC 失败
- **WHEN** 执行 SC.D 且监视区域已被清除
- **THEN** 写入失败，返回非零值

### Requirement: GETILEN 辅助指令
GETILEN.IMM 指令（操作码 0x14F）SHALL 读取目标地址的首字节，根据 bit[7:6] 返回指令长度到 Rd（不执行目标指令）。若目标地址不可读，触发常规数据缺页异常，异常地址为 GETILEN 的操作数地址。

#### Scenario: GETILEN 正常执行
- **WHEN** 执行 GETILEN.IMM Rd, [addr]，地址内容 bit[7:6] = 10
- **THEN** Rd = 6

#### Scenario: GETILEN 缺页
- **WHEN** 目标地址不可读
- **THEN** 触发数据缺页异常，异常地址 = GETILEN 操作数地址