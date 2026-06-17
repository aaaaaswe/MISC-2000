# Tasks

- [x] Task 1: 实现变长指令取指单元 (rtl/core/ifu.sv)
  - [x] 按 2 字节对齐读取指令首部，解析 bit[7:6] 确定指令长度（00→2, 01→4, 10→6, 11→8）
  - [x] 状态机实现跨页取指（先读首部→确认长度→读剩余字节）
  - [x] 跨页缺页时异常地址返回指令起始地址（非中间地址）
  - [x] 输出接口：指令字、有效信号、异常信号、异常地址、指令长度

- [x] Task 2: 实现 CSR 寄存器模块 (rtl/core/csr.sv)
  - [x] 实现 CSR_EPC（异常程序计数器）
  - [x] 实现 CSR_ILLEN（异常指令长度，值 2/4/6/8）
  - [x] 实现 CSR 读写接口
  - [x] 异常入口时自动写入 CSR_EPC 和 CSR_ILLEN

- [x] Task 3: 实现异常与长度管理模块 (rtl/core/exception.sv)
  - [x] 异常入口时自动将指令长度写入 CSR_ILLEN
  - [x] ERET 时自动计算返回地址：PC = CSR_EPC + CSR_ILLEN
  - [x] 确保访存指令异常时"全或无"语义，异常返回后可安全重试
  - [x] 维护异常优先级（缺页 > 非法指令 > 原子指令跨页）

- [x] Task 4: 实现原子指令支持模块 (rtl/core/atomic.sv)
  - [x] 实现 LL.D 指令（记录 64 字节对齐独占监视区域）
  - [x] 实现 SC.D 指令（检查监视区域，成功写入返回 0，失败返回非零）
  - [x] 实现 CAS.D 指令（比较并交换）
  - [x] 原子指令跨页检测（触发非法指令异常）
  - [x] 异常/中断/其他核写入清除监视标志
  - [x] 实现 FENCE 指令作为显式内存屏障

- [x] Task 5: 实现 GETILEN 辅助指令 (rtl/core/getilen.sv)
  - [x] 格式：GETILEN.IMM Rd, [address]，操作码 0x14F
  - [x] 读取目标地址首字节的 bit[7:6]，返回指令长度到 Rd
  - [x] 目标地址不可读时触发数据缺页异常，异常地址为操作数地址

- [x] Task 6: 创建仿真测试用例
  - [x] test_ifu.sv：覆盖 2/4/6/8 字节取指、跨页取指、跨页缺页异常地址
  - [x] test_exception.sv：覆盖 CSR_ILLEN 写入、ERET 返回地址计算、全或无语义
  - [x] test_atomic.sv：覆盖 LL/SC/CAS、跨页检测、监视清除
  - [x] test_getilen.sv：覆盖正常读取、缺页异常

- [x] Task 7: 更新仿真 Makefile
  - [x] 添加新模块的编译和运行目标

- [x] Task 8: 验证与检查
  - [x] 运行所有仿真验证通过
  - [x] 确认标准指令集未被修改
  - [x] 确认 Apache 2.0 许可证声明完整

# Task Dependencies
- Task 1, 2 可并行执行（独立模块）
- Task 3 依赖 Task 1, 2（异常模块需要 CSR 和取指单元接口）
- Task 4 依赖 Task 3（原子指令需要异常处理）
- Task 5 依赖 Task 3（GETILEN 需要异常处理）
- Task 6 依赖 Task 1, 2, 3, 4, 5（仿真需要完整 RTL）
- Task 7 依赖 Task 6
- Task 8 依赖所有前置任务