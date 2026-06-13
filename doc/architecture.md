# MISC-2000 处理器架构设计文档

---

## 中文部分

---

## 1. 架构概述

### 设计理念

MISC-2000 是一款采用 **CISC 外壳 + RISC 内核** 混合架构的处理器。其核心设计思想在于：

- **CISC 外壳（外核层）**：向上层软件和编译器暴露出一个功能丰富、语义复杂的 CISC 宏指令集。该宏指令集提供了紧凑的代码密度和强大的单指令能力，例如复杂的寻址模式、字符串操作、硬件辅助循环等。这使得 MISC-2000 在代码存储效率和传统 CISC 软件生态兼容性方面具备优势。

- **RISC 内核（执行层）**：在处理器内部，复杂的 CISC 宏指令被前端译码器拆分（crack）为一条或多条简单的类 RISC 微操作（μOPs），随后由高性能 RISC 流水线执行。内核采用超标量、乱序执行的微架构，具备寄存器重命名、推测执行等现代 RISC 处理器的全部特征。

```
+----------------------------------------------------+
|                  CISC 外壳                          |
|  +------------------------------------------------+ |
|  |  宏指令集 (0x100–0x7CF)                         | |
|  |  复杂寻址模式 | 紧凑编码 | 丰富指令语义          | |
|  +------------------------------------------------+ |
|                       |                              |
|                       v (译码拆分)                    |
|  +------------------------------------------------+ |
|  |                RISC 内核 (MISC-R)                | |
|  |  +------------------------------------------+   | |
|  |  |  微操作区 (0x000–0x0FF)                    |   | |
|  |  |  双发射 | 乱序执行 | 寄存器重命名 | ROB      |   | |
|  |  +------------------------------------------+   | |
|  +------------------------------------------------+ |
+----------------------------------------------------+
```

这种架构在保持 CISC 指令集丰富表达能力和代码密度的同时，获得了 RISC 处理器易于实现高性能流水线、便于频率提升和功耗优化的优势。

---

## 2. 指令集分区

MISC-2000 的指令编码空间被严格划分为三个区域：

| 编码范围       | 数量   | 区域名称           | 权限模型                               |
|----------------|--------|--------------------|----------------------------------------|
| `0x000–0x0FF`  | 256    | 微操作区 (MISC-R)  | 厂商可定制，允许自由修改               |
| `0x100–0x7CF`  | 1744   | 标准宏指令集       | **强制开源，严禁修改**                 |
| `0x7D0–0xFFF`  | 560    | 保留区 / 系统扩展  | 预留，暂未分配                         |

### 微操作区 (MISC-R) — `0x000–0x0FF`

- 该区域编码的是处理器内部微操作（μOPs），由硬件译码器在拆分 CISC 宏指令时生成。
- 芯片厂商可以自由定制该区域的微操作以适配特定的微架构实现需求，例如增加专门的旁路网络优化微操作、功耗管理微操作等。
- 这些微操作**不对外暴露给软件层**，仅存在于处理器内部实现中，不具备指令集兼容性承诺。

### 标准宏指令集 — `0x100–0x7CF`

- 该区域定义了 MISC-2000 的公开指令集接口，是所有编译器、汇编器和操作系统必须遵循的规范。
- **强制开源原则**：指令编码、操作语义、异常行为必须以开放标准文档形式完整公开。
- **不可修改原则**：任何实现 MISC-2000 兼容处理器的厂商，不得对该区域任何指令的编码或语义进行变更，以确保跨厂商的二进制兼容性。
- 该区域按功能进一步划分为 7 个子区域（详见第 7 节）。

---

## 3. RISC 内核 (MISC-R)

MISC-R 是 MISC-2000 的高性能 RISC 执行内核，具备现代超标量处理器的完整特性。

### 3.1 双发射超标量

MISC-R 每个时钟周期可以从调度队列中同时发射（Issue）**最多 2 条**微操作到执行单元。双发射设计在性能与硬件复杂度之间取得了良好平衡。

### 3.2 乱序执行 (Out-of-Order Execution)

- 微操作在进入保留站（Reservation Station）后，只要其源操作数已准备好，即可被发射执行，无需严格遵循程序顺序。
- 调度算法基于 Tomasulo 算法的变体，结合年龄优先（Age-aware）的调度策略以保证公平性和向前推进保证。

### 3.3 重排序缓冲区 (Reorder Buffer, ROB)

| 参数           | 值       |
|----------------|----------|
| ROB 条目数     | 32       |
| 每周期退役数   | 最多 2   |
| 支持的最大飞行指令数 | 32  |

- ROB 是维护程序顺序语义的关键结构。所有微操作按程序顺序（Program Order）分配 ROB 条目，按执行完成乱序写入结果，但**严格按程序顺序退役（Retire/Commit）**。
- 遇异常或分支预测失败时，ROB 提供精确异常点恢复和流水线冲刷机制。

### 3.4 寄存器重命名

- 采用基于重命名映射表（Rename Map Table, RMT）的寄存器重命名方案。
- 物理寄存器文件大小 ≥ 逻辑寄存器数量 + ROB 深度，以支持足够的飞行状态。
- 消除由 WAW（写后写）和 WAR（写后读）引起的假数据依赖。

### 3.5 推测执行

- 分支预测器采用 **TAGE（TAgged GEometric）** 预测器与 **BTB（Branch Target Buffer）** 结合的方式。
- 在分支方向预测后，处理器沿预测路径推测执行。分支结果在 EX 阶段确认。
- 误预测时，从 ROB 中冲刷该分支之后的所有微操作，恢复 RMT 快照。

---

## 4. 寻址模式

MISC-2000 宏指令集支持 5 种寻址模式，格式后缀作为指令助记符的一部分：

| 后缀   | 模式名称         | 格式                     | 说明                                   |
|--------|------------------|--------------------------|----------------------------------------|
| `.IMM` | 立即数寻址       | `OP Rd, #imm`            | 操作数为指令中编码的立即数             |
| `.REG` | 寄存器寻址       | `OP Rd, Rs`              | 操作数位于寄存器中                     |
| `.DIR` | 直接内存寻址     | `OP Rd, [addr]`          | 操作数位于指定内存地址                 |
| `.IDX` | 索引寻址         | `OP Rd, [Rb + offset]`   | 有效地址 = 基址寄存器 + 偏移量         |
| `.STK` | 栈寻址           | `OP Rd, [SP + disp]`     | 有效地址 = 栈指针 + 位移量             |

**示例：**

```asm
ADD.IMM   R1, R2, #42        ; R1 = R2 + 42
ADD.REG   R1, R2, R3         ; R1 = R2 + R3
LD.DIR    R1, [0x1000]       ; R1 = MEM[0x1000]
LD.IDX    R1, [R2 + 8]       ; R1 = MEM[R2 + 8]
PUSH.STK  R1                 ; MEM[SP] = R1; SP -= 8
```

---

## 5. 数据类型

### 5.1 整数类型

| 后缀 | 类型       | 位宽    | 范围（有符号）                                          |
|------|------------|---------|--------------------------------------------------------|
| `.B` | Byte       | 8-bit   | -128 ~ +127                                            |
| `.W` | Word       | 16-bit  | -32,768 ~ +32,767                                      |
| `.D` | Doubleword | 32-bit  | -2,147,483,648 ~ +2,147,483,647                        |
| `.Q` | Quadword   | 64-bit  | -9,223,372,036,854,775,808 ~ +9,223,372,036,854,775,807|

### 5.2 浮点类型

| 后缀   | 类型              | 位宽    | IEEE 754 标准  |
|--------|-------------------|---------|----------------|
| `.F16` | Half-precision    | 16-bit  | IEEE 754-2008  |
| `.F32` | Single-precision  | 32-bit  | IEEE 754-2008  |
| `.F64` | Double-precision  | 64-bit  | IEEE 754-2008  |
| `.F128`| Quad-precision    | 128-bit | IEEE 754-2008  |

### 5.3 向量类型

| 后缀   | 类型                | 元素位宽 | 向量宽度 |
|--------|---------------------|----------|----------|
| `.I8`  | 8-bit integer vec   | 8-bit    | 128-bit  |
| `.I16` | 16-bit integer vec  | 16-bit   | 128-bit  |
| `.I32` | 32-bit integer vec  | 32-bit   | 128-bit  |
| `.F32` | 32-bit float vec    | 32-bit   | 128-bit  |
| `.F64` | 64-bit float vec    | 64-bit   | 128-bit  |

向量寄存器宽度为 128 位，每种类型对应不同数量的 SIMD 通道（Lane）。

---

## 6. 流水线

MISC-2000 采用经典的 **5 级流水线**，但每一级内部均有复杂的子阶段以支持乱序执行。

```
+--------+    +--------+    +----------+    +--------+    +----------+
| Fetch  | -> | Decode | -> | Execute  | -> | Memory | -> | Writeback |
|  (F)   |    |  (D)   |    |   (E)    |    |  (M)   |    |   (W)    |
+--------+    +--------+    +----------+    +--------+    +----------+
```

### F — 取指 (Fetch)

- 从 L1 指令缓存（I-Cache）按程序计数器（PC）取指。
- 分支预测器（TAGE + BTB）在这一阶段提供下一 PC 预测。
- 支持每周期最多 4 条指令的取指带宽。

### D — 译码 (Decode)

- 预译码（Pre-Decode）：识别 CISC 宏指令边界。
- 译码（Decode）：将宏指令拆分为微操作序列。
- 寄存器重命名：消除假数据依赖。
- 微操作分配 ROB 条目并进入保留站 / 发射队列。

### E — 执行 (Execute)

- 包含多个功能单元并行工作：
  - **ALU0 / ALU1**：整数算术逻辑运算
  - **AGU**：地址生成单元（计算访存地址）
  - **FPU**：浮点运算单元（延迟 3–5 周期）
  - **SIMD**：向量处理单元
  - **BRU**：分支解析单元

### M — 访存 (Memory)

- L1 数据缓存（D-Cache）访问。
- 存储缓冲区（Store Buffer）管理。
- 数据 TLB 查找。

### W — 写回 (Writeback)

- 结果写回物理寄存器文件。
- ROB 退役逻辑：按程序顺序提交结果至架构状态。
- 异常处理和中断检测。

---

## 7. 指令分类

### 7.1 指令集分区详表

| 编码范围       | 类别                    | 说明                                         |
|----------------|------------------------|----------------------------------------------|
| `0x100–0x1FF`  | 数据传输 (Data Transfer)| Load, Store, Move, Push, Pop                 |
| `0x200–0x3FF`  | 整数算术 (Integer ALU)  | ADD, SUB, MUL, DIV, MOD, CMP                 |
| `0x400–0x4FF`  | 逻辑运算 (Logic)        | AND, OR, XOR, NOT, SHL, SHR, ROL, ROR        |
| `0x500–0x5FF`  | 浮点标量 (FP Scalar)    | FADD, FSUB, FMUL, FDIV, FSQRT, FCMP          |
| `0x600–0x6FF`  | 程序控制 (Program Ctrl) | JMP, Jcc, CALL, RET, INT, SYSCALL            |
| `0x700–0x7FF`  | SIMD 向量 (SIMD Vector) | VADD, VMUL, VDOT, VLD, VST, VSHUF            |
| `0x800–0x9FF`  | 系统与特权 (System)     | HALT, MTC, MFC, INVTLB, secure context switch |

### 7.2 代表性指令示例

```asm
; 数据传输
LD.Q    R1, [R2 + 0x10]       ; 0x100: Load quadword
ST.D    [R3], R4               ; 0x120: Store doubleword

; 整数算术
ADD.D   R5, R6, R7             ; 0x200: 32-bit add
MUL.Q   R8, R9, R10            ; 0x2A0: 64-bit multiply

; 逻辑运算
AND.D   R11, R12, R13          ; 0x400: bitwise AND
SHL.Q   R14, R15, #4           ; 0x440: shift left logical

; 浮点标量
FADD.F64 R16, R17, R18         ; 0x500: FP64 add
FDIV.F32 R19, R20, R21         ; 0x530: FP32 divide

; 程序控制
JMP     target                 ; 0x600: unconditional jump
JEQ.IMM R22, #0, label         ; 0x610: jump if equal

; SIMD 向量
VADD.F32 VR0, VR1, VR2         ; 0x700: vector float add
VDOT.I32 VR3, VR4, VR5         ; 0x730: vector dot product

; 系统
SYSCALL #0x01                  ; 0x800: system call
MTC     CR0, R23               ; 0x820: move to control register
```

---

## 8. 寄存器文件

### 8.1 通用寄存器 (GPR)

| 寄存器   | 别名 / 用途                | 位宽  |
|----------|----------------------------|-------|
| `x0`     | 零寄存器（硬连线为 0）       | 64-bit|
| `x1`     | 返回地址寄存器 (RA)         | 64-bit|
| `x2`     | 栈指针 (SP)                 | 64-bit|
| `x3`     | 全局指针 (GP)               | 64-bit|
| `x4`     | 线程指针 (TP)               | 64-bit|
| `x5–x7`  | 临时寄存器 (t0–t2)          | 64-bit|
| `x8–x9`  | 保存寄存器 / 参数寄存器 (s0/fp, s1) | 64-bit|
| `x10–x17`| 函数参数 / 返回值 (a0–a7)   | 64-bit|
| `x18–x27`| 被调用者保存 (s2–s11)       | 64-bit|
| `x28–x31`| 临时寄存器 (t3–t6)          | 64-bit|

### 8.2 寄存器文件物理特征

| 特性               | 参数                          |
|--------------------|-------------------------------|
| 逻辑寄存器数量     | 32 路 × 64 位                 |
| 物理寄存器数量     | 64 路 × 64 位（含重命名池）    |
| 读端口数           | 双读（每周期可同时读取 2 个源寄存器）|
| 写端口数           | 单写（每周期最多写入 1 个结果）|

### 8.3 特殊寄存器

| 寄存器   | 描述                                        |
|----------|---------------------------------------------|
| `PC`     | 程序计数器，指向当前指令地址                  |
| `FLAGS`  | 条件标志寄存器（ZF, CF, OF, SF, PF）          |
| `CR0–CR7`| 控制寄存器（包含缓存控制、MMU 配置等）        |
| `VBR`    | 向量基址寄存器，指向异常向量表                 |

---

## 9. 内存模型

### 9.1 寻址空间

| 特性               | 规格                    |
|--------------------|-------------------------|
| 虚拟地址空间       | 48-bit (256 TiB)        |
| 物理地址空间       | 40-bit (1 TiB)          |
| 页大小             | 4 KiB / 2 MiB / 1 GiB   |
| 地址转换           | 硬件页表遍历 (MMU)       |

### 9.2 内存寻址模式实现

```asm
; 直接寻址：有效地址由指令中的立即数给出
LD.DIR  R1, [0xDEADBEEF]        ; EA = 0xDEADBEEF

; 索引寻址：有效地址 = 基址 + 偏移量
LD.IDX  R2, [R3 + 0x100]        ; EA = R3 + 0x100

; 栈寻址：有效地址 = SP + 位移
LD.STK  R4, [SP + 0x10]         ; EA = SP + 0x10
```

### 9.3 内存一致性模型

- 采用 **Total Store Order (TSO)** 的变体。
- 提供 `FENCE` 指令用于显式内存屏障。
- Load 可以被提前执行（Load speculation），但受限于 Store-Load 转发逻辑。
- 原子操作（`ATOM.ADD`, `ATOM.CAS` 等）通过 LL/SC（Load-Linked / Store-Conditional）原语实现。

### 9.4 端序 (Endianness)

- 默认小端 (Little-Endian)。
- 可通过控制寄存器 `CR1.ENDIAN` 位动态切换为大端。

---

## 10. 异常与中断处理

### 10.1 异常分类

| 类型           | 同步/异步 | 来源                   | 示例                              |
|----------------|-----------|------------------------|-----------------------------------|
| 故障 (Fault)   | 同步      | 指令执行前检测         | 缺页异常、非法指令、段错误          |
| 陷阱 (Trap)    | 同步      | 指令执行后报告         | 断点、除零、溢出陷阱               |
| 中止 (Abort)   | 同步      | 不可恢复错误           | 双重故障、机器检查异常              |
| 中断 (Interrupt)| 异步     | 外部设备               | 定时器中断、I/O 中断、IPI          |

### 10.2 异常处理流程

1. 流水线在发生异常的指令处停止后续取指。
2. 处理器将当前上下文（PC, FLAGS, 部分 GPR）压入内核栈。
3. 根据异常向量表（基址 = VBR），跳转到对应的异常处理程序。
4. 异常处理程序保存完整上下文，执行异常处理逻辑。
5. 通过 `ERET`（异常返回）指令恢复上下文，返回被中断的指令流。

### 10.3 异常优先级

当多个异常同时发生时，按以下优先级处理：

| 优先级 | 异常类型          |
|--------|-------------------|
| 1 (最高)| 硬件错误 / 中止   |
| 2      | 外部中断          |
| 3      | 指令故障（缺页等）|
| 4      | 指令陷阱          |
| 5 (最低)| 调试异常          |

---

## 11. 虚拟化支持

### 11.1 虚拟化架构

MISC-2000 通过硬件辅助虚拟化扩展支持高效的虚拟机监控器（VMM / Hypervisor）实现。

### 11.2 特权层级

| 层级   | 名称          | 用途                              |
|--------|---------------|-----------------------------------|
| PL0    | 用户模式      | 普通应用程序                       |
| PL1    | 内核模式      | 操作系统内核                       |
| PL2    | 虚拟机监控器  | Hypervisor / VMM                  |
| PL3    | 安全监控器    | 安全世界（Trusted Execution）       |

### 11.3 虚拟化硬件特性

- **VMCS（Virtual Machine Control Structure）**：存储虚拟机状态和控制字段，支持 VM-Entry 和 VM-Exit 的快速状态切换。
- **第二阶段地址转换（Stage-2 MMU / Nested Paging）**：Guest 物理地址 (GPA) → Host 物理地址 (HPA) 的映射，由硬件页表遍历器自动完成。
- **虚拟中断注入**：Hypervisor 可以直接向 Guest 注入虚拟中断，无需 VM-Exit。
- **I/O 虚拟化**：支持基于 MMIO 和端口映射的设备模拟，以及 SR-IOV 类直通技术。

---

## 12. 安全特性

### 12.1 密码学加速引擎

MISC-2000 集成了硬件密码学加速模块，通过协处理器接口暴露给指令集。

| 算法     | 操作模式                     | 吞吐量           | 延迟       |
|----------|------------------------------|------------------|------------|
| AES      | ECB, CBC, CTR, GCM           | 1 周期 / Byte    | ~5 周期    |
| SHA-256  | 单块 / 流式 / HMAC            | 2 周期 / Byte    | ~8 周期    |
| RSA      | 2048-bit / 4096-bit 模幂      | 取决于密钥长度    | 512–1024 周期 |

### 12.2 安全指令扩展

```asm
; AES 加密轮
AESENC   R1, R2, R3          ; R1 = AES-ENCRYPT-ROUND(R2, R3)

; SHA-256 压缩函数
SHA256   R4, R5, R6          ; R4 = SHA256-COMPRESS(R5, R6)

; RSA 模幂运算
RSA.MODEXP R7, R8, R9, R10  ; R7 = R8^R9 mod R10
```

### 12.3 可信执行环境 (TEE)

- 基于 PL3（安全监控器）特权级实现安全隔离。
- 安全世界和非安全世界的地址空间完全隔离，通过 `SMC`（Secure Monitor Call）进行安全世界切换。
- 支持安全启动（Secure Boot）链：Boot ROM → Bootloader → OS Kernel，每一级均验证签名。

### 12.4 侧信道防护

- 分支预测器支持按特权级分区，防止跨特权级分支预测投毒。
- 数据缓存支持基于特权级的标记（Tagging），防止 Spectre 类缓存侧信道攻击。
- 提供 `CLFLUSH`、`SYNC_BP` 等辅助指令用于软件侧信道缓解。

---

## English Section

---

## 1. Architecture Overview

### Design Philosophy

The MISC-2000 is a processor that adopts a **CISC-outside + RISC-inside** hybrid architecture. Its core design philosophy is:

- **CISC Shell (External Layer)**：Exposes a feature-rich, semantically complex CISC macro-instruction set to upper-layer software and compilers. This macro-instruction set provides compact code density and powerful per-instruction capabilities — such as complex addressing modes, string operations, and hardware-assisted loops. This gives MISC-2000 advantages in code storage efficiency and compatibility with traditional CISC software ecosystems.

- **RISC Core (Execution Layer)**：Internally, complex CISC macro instructions are cracked (decomposed) by the front-end decoder into one or more simple RISC-like micro-operations (μOPs), which are then executed by a high-performance RISC pipeline. The core employs a superscalar, out-of-order execution microarchitecture with all the hallmarks of modern RISC processors — register renaming, speculative execution, etc.

```
+----------------------------------------------------+
|                  CISC Shell                         |
|  +------------------------------------------------+ |
|  |  Macro Instructions (0x100–0x7CF)               | |
|  |  Complex Addressing | Compact Encoding         | |
|  +------------------------------------------------+ |
|                       |                              |
|                       v (Decode / Crack)             |
|  +------------------------------------------------+ |
|  |                RISC Core (MISC-R)               | |
|  |  +------------------------------------------+   | |
|  |  |  Micro-Op Zone (0x000–0x0FF)              |   | |
|  |  |  Dual-Issue | OoO | Reg Rename | ROB       |   | |
|  |  +------------------------------------------+   | |
|  +------------------------------------------------+ |
+----------------------------------------------------+
```

This architecture retains the rich expressiveness and code density of a CISC ISA while achieving the ease of high-performance pipeline implementation, frequency scaling, and power optimization found in RISC processors.

---

## 2. Instruction Set Partition

The MISC-2000 instruction encoding space is strictly divided into three regions:

| Encoding Range  | Count  | Region Name               | Permission Model                                   |
|-----------------|--------|---------------------------|----------------------------------------------------|
| `0x000–0x0FF`   | 256    | Micro-Op Zone (MISC-R)    | Vendor-customizable; freely modifiable             |
| `0x100–0x7CF`   | 1744   | Standard Macro Instructions| **Mandatory open-source; MUST NOT be modified**   |
| `0x7D0–0xFFF`   | 560    | Reserved / System Ext.    | Reserved, unassigned                               |

### Micro-Op Zone (MISC-R) — `0x000–0x0FF`

- This region encodes processor-internal micro-operations (μOPs), generated by the hardware decoder when cracking CISC macro instructions.
- Chip vendors may freely customize micro-ops in this zone to match specific microarchitectural requirements — e.g., adding dedicated bypass-network-optimized μOPs, power-management μOPs, etc.
- These micro-ops are **not exposed to the software layer**. They exist only in the processor's internal implementation and carry no ISA compatibility commitment.

### Standard Macro Instruction Set — `0x100–0x7CF`

- This region defines the public ISA interface of MISC-2000 — the specification that all compilers, assemblers, and operating systems must adhere to.
- **Mandatory Open-Source Principle**：Instruction encodings, operational semantics, and exception behavior must be fully disclosed as an open standard document.
- **Immutability Principle**：Any vendor implementing a MISC-2000–compatible processor **must not** alter the encoding or semantics of any instruction in this region, ensuring binary compatibility across vendors.
- This region is further divided into 7 functional sub-regions (see Section 7).

---

## 3. RISC Core (MISC-R)

MISC-R is the high-performance RISC execution core of MISC-2000, possessing the full feature set of a modern superscalar processor.

### 3.1 Dual-Issue Superscalar

MISC-R can issue **up to 2** micro-operations per clock cycle from the scheduling queue to the execution units. The dual-issue design strikes a good balance between performance and hardware complexity.

### 3.2 Out-of-Order Execution

- Once a micro-op enters the Reservation Station, it can be issued for execution as soon as its source operands are ready — there is no requirement to follow strict program order.
- The scheduling algorithm is based on a variant of Tomasulo's algorithm, combined with an age-aware scheduling policy to ensure fairness and forward-progress guarantees.

### 3.3 Reorder Buffer (ROB)

| Parameter                | Value     |
|--------------------------|-----------|
| ROB entries              | 32        |
| Retire bandwidth         | Up to 2/cycle |
| Maximum in-flight instructions | 32   |

- The ROB is the key structure for maintaining program-order semantics. All μOPs are allocated ROB entries in program order, write results out of order, but **retire/commit strictly in program order**.
- Upon an exception or branch misprediction, the ROB provides a precise exception-point recovery and pipeline flush mechanism.

### 3.4 Register Renaming

- Employs a rename map table (RMT)–based register renaming scheme.
- Physical register file size ≥ logical register count + ROB depth, to support sufficient in-flight state.
- Eliminates false data dependencies caused by WAW (Write-After-Write) and WAR (Write-After-Read) hazards.

### 3.5 Speculative Execution

- The branch predictor uses a **TAGE (TAgged GEometric)** predictor combined with a **BTB (Branch Target Buffer)**.
- After branch direction prediction, the processor speculatively executes along the predicted path. Branch resolution occurs in the EX stage.
- On misprediction, all μOPs after the branch in the ROB are flushed, and the RMT snapshot is restored.

---

## 4. Addressing Modes

The MISC-2000 macro instruction set supports 5 addressing modes, whose format suffixes are part of the instruction mnemonic:

| Suffix | Mode Name            | Format                   | Description                                    |
|--------|----------------------|--------------------------|------------------------------------------------|
| `.IMM` | Immediate            | `OP Rd, #imm`            | Operand is an immediate encoded in the instruction |
| `.REG` | Register             | `OP Rd, Rs`              | Operand resides in a register                    |
| `.DIR` | Direct Memory        | `OP Rd, [addr]`          | Operand at specified memory address              |
| `.IDX` | Indexed              | `OP Rd, [Rb + offset]`   | Effective address = base register + offset       |
| `.STK` | Stack                | `OP Rd, [SP + disp]`     | Effective address = stack pointer + displacement |

**Examples：**

```asm
ADD.IMM   R1, R2, #42        ; R1 = R2 + 42
ADD.REG   R1, R2, R3         ; R1 = R2 + R3
LD.DIR    R1, [0x1000]       ; R1 = MEM[0x1000]
LD.IDX    R1, [R2 + 8]       ; R1 = MEM[R2 + 8]
PUSH.STK  R1                 ; MEM[SP] = R1; SP -= 8
```

---

## 5. Data Types

### 5.1 Integer Types

| Suffix | Type       | Bit Width | Range (Signed)                                         |
|--------|------------|-----------|--------------------------------------------------------|
| `.B`   | Byte       | 8-bit     | -128 ~ +127                                            |
| `.W`   | Word       | 16-bit    | -32,768 ~ +32,767                                      |
| `.D`   | Doubleword | 32-bit    | -2,147,483,648 ~ +2,147,483,647                        |
| `.Q`   | Quadword   | 64-bit    | -9,223,372,036,854,775,808 ~ +9,223,372,036,854,775,807|

### 5.2 Floating-Point Types

| Suffix  | Type               | Bit Width | IEEE 754 Standard |
|---------|--------------------|-----------|--------------------|
| `.F16`  | Half-precision     | 16-bit    | IEEE 754-2008      |
| `.F32`  | Single-precision   | 32-bit    | IEEE 754-2008      |
| `.F64`  | Double-precision   | 64-bit    | IEEE 754-2008      |
| `.F128` | Quad-precision     | 128-bit   | IEEE 754-2008      |

### 5.3 Vector Types

| Suffix  | Type                 | Element Width | Vector Width |
|---------|----------------------|---------------|--------------|
| `.I8`   | 8-bit integer vec    | 8-bit         | 128-bit      |
| `.I16`  | 16-bit integer vec   | 16-bit        | 128-bit      |
| `.I32`  | 32-bit integer vec   | 32-bit        | 128-bit      |
| `.F32`  | 32-bit float vec     | 32-bit        | 128-bit      |
| `.F64`  | 64-bit float vec     | 64-bit        | 128-bit      |

The vector register width is 128 bits; each type corresponds to a different number of SIMD lanes.

---

## 6. Pipeline

MISC-2000 employs a classic **5-stage pipeline**, though each stage contains complex sub-stages to support out-of-order execution.

```
+--------+    +--------+    +----------+    +--------+    +----------+
| Fetch  | -> | Decode | -> | Execute  | -> | Memory | -> | Writeback |
|  (F)   |    |  (D)   |    |   (E)    |    |  (M)   |    |   (W)    |
+--------+    +--------+    +----------+    +--------+    +----------+
```

### F — Fetch

- Fetches instructions from the L1 instruction cache (I-Cache) according to the program counter (PC).
- The branch predictor (TAGE + BTB) provides the next-PC prediction at this stage.
- Supports a fetch bandwidth of up to 4 instructions per cycle.

### D — Decode

- Pre-Decode：Identify CISC macro-instruction boundaries.
- Decode：Crack macro instructions into micro-operation sequences.
- Register Renaming：Eliminate false data dependencies.
- Allocate μOPs to ROB entries and dispatch into reservation stations / issue queues.

### E — Execute

- Contains multiple functional units operating in parallel：
  - **ALU0 / ALU1**：Integer arithmetic and logic
  - **AGU**：Address Generation Unit (computes memory access addresses)
  - **FPU**：Floating-point unit (3–5 cycle latency)
  - **SIMD**：Vector processing unit
  - **BRU**：Branch Resolution Unit

### M — Memory

- L1 Data Cache (D-Cache) access.
- Store Buffer management.
- Data TLB lookup.

### W — Writeback

- Results written back to the physical register file.
- ROB retire logic：Commit results to architectural state in program order.
- Exception handling and interrupt detection.

---

## 7. Instruction Categories

### 7.1 Detailed Instruction Partition Table

| Encoding Range  | Category                | Description                                     |
|-----------------|-------------------------|-------------------------------------------------|
| `0x100–0x1FF`   | Data Transfer           | Load, Store, Move, Push, Pop                    |
| `0x200–0x3FF`   | Integer Arithmetic      | ADD, SUB, MUL, DIV, MOD, CMP                    |
| `0x400–0x4FF`   | Logic Operations        | AND, OR, XOR, NOT, SHL, SHR, ROL, ROR           |
| `0x500–0x5FF`   | Floating-Point Scalar   | FADD, FSUB, FMUL, FDIV, FSQRT, FCMP             |
| `0x600–0x6FF`   | Program Control         | JMP, Jcc, CALL, RET, INT, SYSCALL               |
| `0x700–0x7FF`   | SIMD Vector             | VADD, VMUL, VDOT, VLD, VST, VSHUF               |
| `0x800–0x9FF`   | System & Privileged     | HALT, MTC, MFC, INVTLB, secure context switch   |

### 7.2 Representative Instruction Examples

```asm
; Data Transfer
LD.Q    R1, [R2 + 0x10]       ; 0x100: Load quadword
ST.D    [R3], R4               ; 0x120: Store doubleword

; Integer Arithmetic
ADD.D   R5, R6, R7             ; 0x200: 32-bit add
MUL.Q   R8, R9, R10            ; 0x2A0: 64-bit multiply

; Logic Operations
AND.D   R11, R12, R13          ; 0x400: bitwise AND
SHL.Q   R14, R15, #4           ; 0x440: shift left logical

; Floating-Point Scalar
FADD.F64 R16, R17, R18         ; 0x500: FP64 add
FDIV.F32 R19, R20, R21         ; 0x530: FP32 divide

; Program Control
JMP     target                 ; 0x600: unconditional jump
JEQ.IMM R22, #0, label         ; 0x610: jump if equal

; SIMD Vector
VADD.F32 VR0, VR1, VR2         ; 0x700: vector float add
VDOT.I32 VR3, VR4, VR5         ; 0x730: vector dot product

; System
SYSCALL #0x01                  ; 0x800: system call
MTC     CR0, R23               ; 0x820: move to control register
```

---

## 8. Register File

### 8.1 General-Purpose Registers (GPR)

| Register  | Alias / Purpose                   | Width  |
|-----------|-----------------------------------|--------|
| `x0`      | Zero register (hardwired to 0)     | 64-bit |
| `x1`      | Return Address (RA)               | 64-bit |
| `x2`      | Stack Pointer (SP)                | 64-bit |
| `x3`      | Global Pointer (GP)               | 64-bit |
| `x4`      | Thread Pointer (TP)               | 64-bit |
| `x5–x7`   | Temporary registers (t0–t2)       | 64-bit |
| `x8–x9`   | Saved reg / Frame pointer (s0/fp, s1) | 64-bit |
| `x10–x17` | Function arguments / return value (a0–a7) | 64-bit |
| `x18–x27` | Callee-saved (s2–s11)             | 64-bit |
| `x28–x31` | Temporary registers (t3–t6)       | 64-bit |

### 8.2 Register File Physical Characteristics

| Characteristic          | Specification                                  |
|-------------------------|------------------------------------------------|
| Logical register count  | 32 entries × 64-bit                            |
| Physical register count | 64 entries × 64-bit (including renaming pool)  |
| Read ports              | Dual-read (2 source registers simultaneously)  |
| Write ports             | Single-write (1 result written per cycle)      |

### 8.3 Special Registers

| Register  | Description                                               |
|-----------|-----------------------------------------------------------|
| `PC`      | Program Counter — points to the current instruction       |
| `FLAGS`   | Condition flags register (ZF, CF, OF, SF, PF)             |
| `CR0–CR7` | Control registers (cache control, MMU configuration, etc.)|
| `VBR`     | Vector Base Register — points to the exception vector table|

---

## 9. Memory Model

### 9.1 Address Space

| Characteristic         | Specification              |
|------------------------|----------------------------|
| Virtual address space  | 48-bit (256 TiB)           |
| Physical address space | 40-bit (1 TiB)             |
| Page sizes             | 4 KiB / 2 MiB / 1 GiB      |
| Address translation    | Hardware page-table walker (MMU) |

### 9.2 Memory Addressing Mode Implementation

```asm
; Direct addressing: effective address from immediate in instruction
LD.DIR  R1, [0xDEADBEEF]        ; EA = 0xDEADBEEF

; Indexed addressing: effective address = base + offset
LD.IDX  R2, [R3 + 0x100]        ; EA = R3 + 0x100

; Stack addressing: effective address = SP + displacement
LD.STK  R4, [SP + 0x10]         ; EA = SP + 0x10
```

### 9.3 Memory Consistency Model

- Employs a variant of **Total Store Order (TSO)**.
- Provides a `FENCE` instruction for explicit memory barriers.
- Loads may be executed early (load speculation), subject to Store-Load forwarding logic.
- Atomic operations (`ATOM.ADD`, `ATOM.CAS`, etc.) are implemented via LL/SC (Load-Linked / Store-Conditional) primitives.

### 9.4 Endianness

- Default：Little-Endian.
- Dynamically switchable to Big-Endian via the `CR1.ENDIAN` control register bit.

---

## 10. Exception and Interrupt Handling

### 10.1 Exception Classification

| Type            | Sync/Async | Source                  | Examples                                 |
|-----------------|------------|-------------------------|------------------------------------------|
| Fault           | Synchronous| Detected before instr.  | Page fault, illegal instruction, segfault|
| Trap            | Synchronous| Reported after instr.   | Breakpoint, divide-by-zero, overflow trap|
| Abort           | Synchronous| Unrecoverable error     | Double fault, machine check exception    |
| Interrupt       | Asynchronous| External device        | Timer interrupt, I/O interrupt, IPI      |

### 10.2 Exception Handling Flow

1. The pipeline stops fetching at the faulting instruction.
2. The processor pushes the current context (PC, FLAGS, partial GPRs) onto the kernel stack.
3. Based on the exception vector table (base = VBR), control jumps to the corresponding exception handler.
4. The exception handler saves the full context and executes exception handling logic.
5. Via the `ERET` (Exception Return) instruction, the context is restored and execution returns to the interrupted instruction stream.

### 10.3 Exception Priority

When multiple exceptions occur simultaneously, they are handled in the following priority order：

| Priority  | Exception Type             |
|-----------|----------------------------|
| 1 (highest)| Hardware Error / Abort    |
| 2         | External Interrupt         |
| 3         | Instruction Fault (page fault, etc.) |
| 4         | Instruction Trap           |
| 5 (lowest)| Debug Exception            |

---

## 11. Virtualization Support

### 11.1 Virtualization Architecture

MISC-2000 supports efficient Virtual Machine Monitor (VMM / Hypervisor) implementation through hardware-assisted virtualization extensions.

### 11.2 Privilege Levels

| Level  | Name                  | Purpose                                    |
|--------|-----------------------|--------------------------------------------|
| PL0    | User Mode             | Ordinary applications                      |
| PL1    | Kernel Mode           | Operating system kernel                    |
| PL2    | Hypervisor Mode       | Hypervisor / VMM                           |
| PL3    | Secure Monitor        | Secure world (Trusted Execution)           |

### 11.3 Virtualization Hardware Features

- **VMCS (Virtual Machine Control Structure)**：Stores VM state and control fields, enabling fast VM-Entry and VM-Exit state transitions.
- **Stage-2 Address Translation (Nested Paging)**：Mapping of Guest Physical Address (GPA) → Host Physical Address (HPA), performed automatically by the hardware page table walker.
- **Virtual Interrupt Injection**：The hypervisor can directly inject virtual interrupts into the guest without requiring a VM-Exit.
- **I/O Virtualization**：Supports MMIO-based and port-mapped device emulation, as well as SR-IOV–style passthrough.

---

## 12. Security Features

### 12.1 Cryptographic Acceleration Engine

MISC-2000 integrates a hardware cryptographic acceleration module, exposed to the ISA via coprocessor interfaces.

| Algorithm  | Operating Modes               | Throughput       | Latency     |
|------------|-------------------------------|------------------|-------------|
| AES        | ECB, CBC, CTR, GCM            | 1 cycle / Byte   | ~5 cycles   |
| SHA-256    | Single-block / Streaming / HMAC| 2 cycles / Byte  | ~8 cycles   |
| RSA        | 2048-bit / 4096-bit mod-exp    | Key-size dependent| 512–1024 cycles |

### 12.2 Security Instruction Extensions

```asm
; AES encryption round
AESENC   R1, R2, R3          ; R1 = AES-ENCRYPT-ROUND(R2, R3)

; SHA-256 compression function
SHA256   R4, R5, R6          ; R4 = SHA256-COMPRESS(R5, R6)

; RSA modular exponentiation
RSA.MODEXP R7, R8, R9, R10  ; R7 = R8^R9 mod R10
```

### 12.3 Trusted Execution Environment (TEE)

- Security isolation is achieved based on the PL3 (Secure Monitor) privilege level.
- The secure world and non-secure world address spaces are fully isolated, with world switching performed via the `SMC` (Secure Monitor Call) instruction.
- Support for a Secure Boot chain：Boot ROM → Bootloader → OS Kernel, with signature verification at each stage.

### 12.4 Side-Channel Mitigation

- The branch predictor supports privilege-level partitioning to prevent cross-privilege-level branch prediction poisoning.
- Data caches support privilege-level–based tagging to prevent Spectre-class cache side-channel attacks.
- Auxiliary instructions such as `CLFLUSH` and `SYNC_BP` are provided for software-based side-channel mitigation.

---

*MISC-2000 Architecture Design Document — Version 1.0*