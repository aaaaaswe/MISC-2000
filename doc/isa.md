# MISC-2000 处理器指令集规范 (ISA Specification)

> **语言说明**: 本文档先提供中文版本，后附英文版本。两份内容完全对应。
>
> **Language Note**: This document provides the Chinese version first, followed by the English version. Both sections are fully equivalent.

---

# 第一部分：中文版

---

## 1. 概述

MISC-2000 是一款高性能 CISC 架构处理器，集成了整数运算、浮点运算（标量 & 向量 SIMD）、虚拟化、硬件安全加速等丰富功能。其指令集分为两大层级：

- **标准 CISC 宏指令集（Standard CISC Macro-Instruction Set）** — 位于编码空间 **0x100–0x7CF**，共 **1744 条指令**。此部分为行业强制标准，**任何实现均不得修改**（MANDATORY, CANNOT be modified）。
- **厂商自定义微操作区（Vendor Custom Micro-Op Zone）** — 位于编码空间 **0x000–0x0FF**，共 **256 条指令**。本文档给出 **MISC-R 推荐实现**，但**厂商可自由修改**（vendors can freely modify）。

所有指令均为定长编码。助记符使用 `.` 分隔后缀以指示寻址模式与数据类型。

### 1.1 助记符命名规则

| 后缀类型 | 后缀 | 含义 |
|----------|------|------|
| 寻址模式 | `.IMM` | 立即数寻址 (Immediate) |
| 寻址模式 | `.REG` | 寄存器寻址 (Register) |
| 寻址模式 | `.DIR` | 直接寻址 (Direct) |
| 寻址模式 | `.IDX` | 索引寻址 (Indexed) |
| 寻址模式 | `.STK` | 栈寻址 (Stack) |
| 整数类型 | `.B` | 8 位字节 (Byte) |
| 整数类型 | `.W` | 16 位字 (Word) |
| 整数类型 | `.D` | 32 位双字 (Doubleword) |
| 整数类型 | `.Q` | 64 位四字 (Quadword) |
| 浮点类型 | `.F16` | 16 位半精度浮点 (Half-precision float) |
| 浮点类型 | `.F32` | 32 位单精度浮点 (Single-precision float) |
| 浮点类型 | `.F64` | 64 位双精度浮点 (Double-precision float) |
| 浮点类型 | `.F128` | 128 位四精度浮点 (Quad-precision float) |
| 向量类型 | `.I8` | 8 位整数向量元素 |
| 向量类型 | `.I16` | 16 位整数向量元素 |
| 向量类型 | `.I32` | 32 位整数向量元素 |
| 向量类型 | `.F32` | 32 位浮点向量元素 |
| 向量类型 | `.F64` | 64 位浮点向量元素 |

---

## 2. 标准 CISC 宏指令集 (Standard CISC Macro-Instruction Set)

> **⚠️ 强制标准区域 — 编码范围 0x100–0x7CF — 不可修改**
>
> 以下所有指令编码为 ISA 标准的强制组成部分。任何兼容 MISC-2000 的实现必须以完全相同的方式实现本区域内的所有指令。

### 2.1 数据传送指令 (Data Transfer) — 编码范围 0x100–0x1FF

#### 2.1.1 基本数据传送

| 指令 | IMM | REG | DIR | IDX | STK | 说明 |
|------|-----|-----|-----|-----|-----|------|
| **MOV** | 0x100 | 0x101 | 0x102 | 0x103 | 0x104 | 数据传送 (Move) |
| **LOAD** | 0x105 | 0x106 | 0x107 | 0x108 | 0x109 | 从内存加载 (Load) |
| **STORE** | 0x10A | 0x10B | 0x10C | 0x10D | 0x10E | 存入内存 (Store) |
| **PUSH** | 0x10F | 0x110 | 0x111 | 0x112 | 0x113 | 压栈 (Push) |
| **POP** | 0x114 | 0x115 | 0x116 | 0x117 | 0x118 | 弹栈 (Pop) |
| **XCHG** | 0x119 | 0x11A | 0x11B | 0x11C | 0x11D | 交换 (Exchange) |
| **LEA** | 0x11E | 0x11F | 0x120 | 0x121 | 0x122 | 加载有效地址 (Load Effective Address) |
| **MOVSX** | 0x123 | 0x124 | 0x125 | 0x126 | 0x127 | 符号扩展传送 (Move with Sign-Extend) |
| **MOVZX** | 0x128 | 0x129 | 0x12A | 0x12B | 0x12C | 零扩展传送 (Move with Zero-Extend) |
| **CMOV** | 0x12D | 0x12E | 0x12F | 0x130 | 0x131 | 条件传送 (Conditional Move) |

#### 2.1.2 原子操作与特殊数据传送

| 指令 | IMM | REG | DIR | IDX | STK | 说明 |
|------|-----|-----|-----|-----|-----|------|
| **LDALL** | 0x135 | 0x136 | 0x137 | 0x138 | 0x139 | 全加载 (Load All) |
| **STALL** | 0x13A | 0x13B | 0x13C | 0x13D | 0x13E | 全存储 (Store All) |
| **SWAP** | 0x13F | 0x140 | 0x141 | 0x142 | 0x143 | 原子交换 (Atomic Swap) |
| **CAS** | 0x144 | 0x145 | 0x146 | 0x147 | 0x148 | 比较并交换 (Compare-and-Swap) |
| **LDADD** | 0x149 | 0x14A | 0x14B | 0x14C | 0x14D | 原子加-加载 (Atomic Add then Load) |
| **LDSET** | 0x14E | 0x14F | 0x150 | 0x151 | 0x152 | 原子置位-加载 (Atomic Set-bit then Load) |
| **LDCLR** | 0x153 | 0x154 | 0x155 | 0x156 | 0x157 | 原子清零-加载 (Atomic Clear-bit then Load) |
| **PREFETCH** | 0x158 | 0x159 | 0x15A | 0x15B | 0x15C | 预取 (Prefetch) |

#### 2.1.3 特殊数据传送（固定编码）

| 指令 | 编码 | 说明 |
|------|------|------|
| **MOV.R2M** | 0x132 | 寄存器到内存传送 (Register-to-Memory Move) |
| **MOV.M2R** | 0x133 | 内存到寄存器传送 (Memory-to-Register Move) |
| **MOV.M2M** | 0x134 | 内存到内存传送 (Memory-to-Memory Move) |

#### 2.1.4 内存屏障指令

| 指令 | 编码 | 说明 |
|------|------|------|
| **MEMBAR** | 0x15D | 内存屏障 (Memory Barrier) |
| **FENCE** | 0x15E | 全局栅栏 (Full Fence) |

#### 2.1.5 保留区

| 范围 | 说明 |
|------|------|
| 0x15F–0x1FF | 保留 (Reserved) |

---

### 2.2 整数算术指令 (Integer Arithmetic) — 编码范围 0x200–0x407

> **说明**: 每条基指令占 20 个连续编码（5 种寻址模式 × 4 种整数类型 B/W/D/Q）。
#### 2.2.1 ADD — 加法 (Add)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ADD.B.IMM | 0x200 | ADD.B.REG | 0x201 |
| ADD.B.DIR | 0x202 | ADD.B.IDX | 0x203 |
| ADD.B.STK | 0x204 | ADD.W.IMM | 0x205 |
| ADD.W.REG | 0x206 | ADD.W.DIR | 0x207 |
| ADD.W.IDX | 0x208 | ADD.W.STK | 0x209 |
| ADD.D.IMM | 0x20A | ADD.D.REG | 0x20B |
| ADD.D.DIR | 0x20C | ADD.D.IDX | 0x20D |
| ADD.D.STK | 0x20E | ADD.Q.IMM | 0x20F |
| ADD.Q.REG | 0x210 | ADD.Q.DIR | 0x211 |
| ADD.Q.IDX | 0x212 | ADD.Q.STK | 0x213 |

#### 2.2.2 SUB — 减法 (Subtract)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SUB.B.IMM | 0x214 | SUB.B.REG | 0x215 |
| SUB.B.DIR | 0x216 | SUB.B.IDX | 0x217 |
| SUB.B.STK | 0x218 | SUB.W.IMM | 0x219 |
| SUB.W.REG | 0x21A | SUB.W.DIR | 0x21B |
| SUB.W.IDX | 0x21C | SUB.W.STK | 0x21D |
| SUB.D.IMM | 0x21E | SUB.D.REG | 0x21F |
| SUB.D.DIR | 0x220 | SUB.D.IDX | 0x221 |
| SUB.D.STK | 0x222 | SUB.Q.IMM | 0x223 |
| SUB.Q.REG | 0x224 | SUB.Q.DIR | 0x225 |
| SUB.Q.IDX | 0x226 | SUB.Q.STK | 0x227 |

#### 2.2.3 MUL — 乘法 (Multiply)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MUL.B.IMM | 0x228 | MUL.B.REG | 0x229 |
| MUL.B.DIR | 0x22A | MUL.B.IDX | 0x22B |
| MUL.B.STK | 0x22C | MUL.W.IMM | 0x22D |
| MUL.W.REG | 0x22E | MUL.W.DIR | 0x22F |
| MUL.W.IDX | 0x230 | MUL.W.STK | 0x231 |
| MUL.D.IMM | 0x232 | MUL.D.REG | 0x233 |
| MUL.D.DIR | 0x234 | MUL.D.IDX | 0x235 |
| MUL.D.STK | 0x236 | MUL.Q.IMM | 0x237 |
| MUL.Q.REG | 0x238 | MUL.Q.DIR | 0x239 |
| MUL.Q.IDX | 0x23A | MUL.Q.STK | 0x23B |

#### 2.2.4 DIV — 除法 (Divide)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| DIV.B.IMM | 0x23C | DIV.B.REG | 0x23D |
| DIV.B.DIR | 0x23E | DIV.B.IDX | 0x23F |
| DIV.B.STK | 0x240 | DIV.W.IMM | 0x241 |
| DIV.W.REG | 0x242 | DIV.W.DIR | 0x243 |
| DIV.W.IDX | 0x244 | DIV.W.STK | 0x245 |
| DIV.D.IMM | 0x246 | DIV.D.REG | 0x247 |
| DIV.D.DIR | 0x248 | DIV.D.IDX | 0x249 |
| DIV.D.STK | 0x24A | DIV.Q.IMM | 0x24B |
| DIV.Q.REG | 0x24C | DIV.Q.DIR | 0x24D |
| DIV.Q.IDX | 0x24E | DIV.Q.STK | 0x24F |

#### 2.2.5 MOD — 取模 (Modulo)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MOD.B.IMM | 0x250 | MOD.B.REG | 0x251 |
| MOD.B.DIR | 0x252 | MOD.B.IDX | 0x253 |
| MOD.B.STK | 0x254 | MOD.W.IMM | 0x255 |
| MOD.W.REG | 0x256 | MOD.W.DIR | 0x257 |
| MOD.W.IDX | 0x258 | MOD.W.STK | 0x259 |
| MOD.D.IMM | 0x25A | MOD.D.REG | 0x25B |
| MOD.D.DIR | 0x25C | MOD.D.IDX | 0x25D |
| MOD.D.STK | 0x25E | MOD.Q.IMM | 0x25F |
| MOD.Q.REG | 0x260 | MOD.Q.DIR | 0x261 |
| MOD.Q.IDX | 0x262 | MOD.Q.STK | 0x263 |

#### 2.2.6 INC — 递增 (Increment)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| INC.B.IMM | 0x264 | INC.B.REG | 0x265 |
| INC.B.DIR | 0x266 | INC.B.IDX | 0x267 |
| INC.B.STK | 0x268 | INC.W.IMM | 0x269 |
| INC.W.REG | 0x26A | INC.W.DIR | 0x26B |
| INC.W.IDX | 0x26C | INC.W.STK | 0x26D |
| INC.D.IMM | 0x26E | INC.D.REG | 0x26F |
| INC.D.DIR | 0x270 | INC.D.IDX | 0x271 |
| INC.D.STK | 0x272 | INC.Q.IMM | 0x273 |
| INC.Q.REG | 0x274 | INC.Q.DIR | 0x275 |
| INC.Q.IDX | 0x276 | INC.Q.STK | 0x277 |

#### 2.2.7 DEC — 递减 (Decrement)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| DEC.B.IMM | 0x278 | DEC.B.REG | 0x279 |
| DEC.B.DIR | 0x27A | DEC.B.IDX | 0x27B |
| DEC.B.STK | 0x27C | DEC.W.IMM | 0x27D |
| DEC.W.REG | 0x27E | DEC.W.DIR | 0x27F |
| DEC.W.IDX | 0x280 | DEC.W.STK | 0x281 |
| DEC.D.IMM | 0x282 | DEC.D.REG | 0x283 |
| DEC.D.DIR | 0x284 | DEC.D.IDX | 0x285 |
| DEC.D.STK | 0x286 | DEC.Q.IMM | 0x287 |
| DEC.Q.REG | 0x288 | DEC.Q.DIR | 0x289 |
| DEC.Q.IDX | 0x28A | DEC.Q.STK | 0x28B |

#### 2.2.8 ABS — 绝对值 (Absolute Value)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ABS.B.IMM | 0x28C | ABS.B.REG | 0x28D |
| ABS.B.DIR | 0x28E | ABS.B.IDX | 0x28F |
| ABS.B.STK | 0x290 | ABS.W.IMM | 0x291 |
| ABS.W.REG | 0x292 | ABS.W.DIR | 0x293 |
| ABS.W.IDX | 0x294 | ABS.W.STK | 0x295 |
| ABS.D.IMM | 0x296 | ABS.D.REG | 0x297 |
| ABS.D.DIR | 0x298 | ABS.D.IDX | 0x299 |
| ABS.D.STK | 0x29A | ABS.Q.IMM | 0x29B |
| ABS.Q.REG | 0x29C | ABS.Q.DIR | 0x29D |
| ABS.Q.IDX | 0x29E | ABS.Q.STK | 0x29F |

#### 2.2.9 NEG — 取负 (Negate)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| NEG.B.IMM | 0x2A0 | NEG.B.REG | 0x2A1 |
| NEG.B.DIR | 0x2A2 | NEG.B.IDX | 0x2A3 |
| NEG.B.STK | 0x2A4 | NEG.W.IMM | 0x2A5 |
| NEG.W.REG | 0x2A6 | NEG.W.DIR | 0x2A7 |
| NEG.W.IDX | 0x2A8 | NEG.W.STK | 0x2A9 |
| NEG.D.IMM | 0x2AA | NEG.D.REG | 0x2AB |
| NEG.D.DIR | 0x2AC | NEG.D.IDX | 0x2AD |
| NEG.D.STK | 0x2AE | NEG.Q.IMM | 0x2AF |
| NEG.Q.REG | 0x2B0 | NEG.Q.DIR | 0x2B1 |
| NEG.Q.IDX | 0x2B2 | NEG.Q.STK | 0x2B3 |

#### 2.2.10 MIN — 最小值 (Minimum)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MIN.B.IMM | 0x2B4 | MIN.B.REG | 0x2B5 |
| MIN.B.DIR | 0x2B6 | MIN.B.IDX | 0x2B7 |
| MIN.B.STK | 0x2B8 | MIN.W.IMM | 0x2B9 |
| MIN.W.REG | 0x2BA | MIN.W.DIR | 0x2BB |
| MIN.W.IDX | 0x2BC | MIN.W.STK | 0x2BD |
| MIN.D.IMM | 0x2BE | MIN.D.REG | 0x2BF |
| MIN.D.DIR | 0x2C0 | MIN.D.IDX | 0x2C1 |
| MIN.D.STK | 0x2C2 | MIN.Q.IMM | 0x2C3 |
| MIN.Q.REG | 0x2C4 | MIN.Q.DIR | 0x2C5 |
| MIN.Q.IDX | 0x2C6 | MIN.Q.STK | 0x2C7 |

#### 2.2.11 MAX — 最大值 (Maximum)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MAX.B.IMM | 0x2C8 | MAX.B.REG | 0x2C9 |
| MAX.B.DIR | 0x2CA | MAX.B.IDX | 0x2CB |
| MAX.B.STK | 0x2CC | MAX.W.IMM | 0x2CD |
| MAX.W.REG | 0x2CE | MAX.W.DIR | 0x2CF |
| MAX.W.IDX | 0x2D0 | MAX.W.STK | 0x2D1 |
| MAX.D.IMM | 0x2D2 | MAX.D.REG | 0x2D3 |
| MAX.D.DIR | 0x2D4 | MAX.D.IDX | 0x2D5 |
| MAX.D.STK | 0x2D6 | MAX.Q.IMM | 0x2D7 |
| MAX.Q.REG | 0x2D8 | MAX.Q.DIR | 0x2D9 |
| MAX.Q.IDX | 0x2DA | MAX.Q.STK | 0x2DB |

#### 2.2.12 AVG — 平均值 (Average)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| AVG.B.IMM | 0x2DC | AVG.B.REG | 0x2DD |
| AVG.B.DIR | 0x2DE | AVG.B.IDX | 0x2DF |
| AVG.B.STK | 0x2E0 | AVG.W.IMM | 0x2E1 |
| AVG.W.REG | 0x2E2 | AVG.W.DIR | 0x2E3 |
| AVG.W.IDX | 0x2E4 | AVG.W.STK | 0x2E5 |
| AVG.D.IMM | 0x2E6 | AVG.D.REG | 0x2E7 |
| AVG.D.DIR | 0x2E8 | AVG.D.IDX | 0x2E9 |
| AVG.D.STK | 0x2EA | AVG.Q.IMM | 0x2EB |
| AVG.Q.REG | 0x2EC | AVG.Q.DIR | 0x2ED |
| AVG.Q.IDX | 0x2EE | AVG.Q.STK | 0x2EF |

#### 2.2.13 MULH — 高位乘法 (Multiply High)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MULH.B.IMM | 0x2F0 | MULH.B.REG | 0x2F1 |
| MULH.B.DIR | 0x2F2 | MULH.B.IDX | 0x2F3 |
| MULH.B.STK | 0x2F4 | MULH.W.IMM | 0x2F5 |
| MULH.W.REG | 0x2F6 | MULH.W.DIR | 0x2F7 |
| MULH.W.IDX | 0x2F8 | MULH.W.STK | 0x2F9 |
| MULH.D.IMM | 0x2FA | MULH.D.REG | 0x2FB |
| MULH.D.DIR | 0x2FC | MULH.D.IDX | 0x2FD |
| MULH.D.STK | 0x2FE | MULH.Q.IMM | 0x2FF |
| MULH.Q.REG | 0x300 | MULH.Q.DIR | 0x301 |
| MULH.Q.IDX | 0x302 | MULH.Q.STK | 0x303 |

#### 2.2.14 DIVH — 扩展除法 (Extended Divide)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| DIVH.B.IMM | 0x304 | DIVH.B.REG | 0x305 |
| DIVH.B.DIR | 0x306 | DIVH.B.IDX | 0x307 |
| DIVH.B.STK | 0x308 | DIVH.W.IMM | 0x309 |
| DIVH.W.REG | 0x30A | DIVH.W.DIR | 0x30B |
| DIVH.W.IDX | 0x30C | DIVH.W.STK | 0x30D |
| DIVH.D.IMM | 0x30E | DIVH.D.REG | 0x30F |
| DIVH.D.DIR | 0x310 | DIVH.D.IDX | 0x311 |
| DIVH.D.STK | 0x312 | DIVH.Q.IMM | 0x313 |
| DIVH.Q.REG | 0x314 | DIVH.Q.DIR | 0x315 |
| DIVH.Q.IDX | 0x316 | DIVH.Q.STK | 0x317 |

#### 2.2.15 MADD — 乘加 (Multiply-Add)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MADD.B.IMM | 0x318 | MADD.B.REG | 0x319 |
| MADD.B.DIR | 0x31A | MADD.B.IDX | 0x31B |
| MADD.B.STK | 0x31C | MADD.W.IMM | 0x31D |
| MADD.W.REG | 0x31E | MADD.W.DIR | 0x31F |
| MADD.W.IDX | 0x320 | MADD.W.STK | 0x321 |
| MADD.D.IMM | 0x322 | MADD.D.REG | 0x323 |
| MADD.D.DIR | 0x324 | MADD.D.IDX | 0x325 |
| MADD.D.STK | 0x326 | MADD.Q.IMM | 0x327 |
| MADD.Q.REG | 0x328 | MADD.Q.DIR | 0x329 |
| MADD.Q.IDX | 0x32A | MADD.Q.STK | 0x32B |

#### 2.2.16 MSUB — 乘减 (Multiply-Subtract)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| MSUB.B.IMM | 0x32C | MSUB.B.REG | 0x32D |
| MSUB.B.DIR | 0x32E | MSUB.B.IDX | 0x32F |
| MSUB.B.STK | 0x330 | MSUB.W.IMM | 0x331 |
| MSUB.W.REG | 0x332 | MSUB.W.DIR | 0x333 |
| MSUB.W.IDX | 0x334 | MSUB.W.STK | 0x335 |
| MSUB.D.IMM | 0x336 | MSUB.D.REG | 0x337 |
| MSUB.D.DIR | 0x338 | MSUB.D.IDX | 0x339 |
| MSUB.D.STK | 0x33A | MSUB.Q.IMM | 0x33B |
| MSUB.Q.REG | 0x33C | MSUB.Q.DIR | 0x33D |
| MSUB.Q.IDX | 0x33E | MSUB.Q.STK | 0x33F |

#### 2.2.17 SAD — 绝对差值和 (Sum of Absolute Differences)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SAD.B.IMM | 0x340 | SAD.B.REG | 0x341 |
| SAD.B.DIR | 0x342 | SAD.B.IDX | 0x343 |
| SAD.B.STK | 0x344 | SAD.W.IMM | 0x345 |
| SAD.W.REG | 0x346 | SAD.W.DIR | 0x347 |
| SAD.W.IDX | 0x348 | SAD.W.STK | 0x349 |
| SAD.D.IMM | 0x34A | SAD.D.REG | 0x34B |
| SAD.D.DIR | 0x34C | SAD.D.IDX | 0x34D |
| SAD.D.STK | 0x34E | SAD.Q.IMM | 0x34F |
| SAD.Q.REG | 0x350 | SAD.Q.DIR | 0x351 |
| SAD.Q.IDX | 0x352 | SAD.Q.STK | 0x353 |

#### 2.2.18 CMP — 比较 (Compare)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| CMP.B.IMM | 0x354 | CMP.B.REG | 0x355 |
| CMP.B.DIR | 0x356 | CMP.B.IDX | 0x357 |
| CMP.B.STK | 0x358 | CMP.W.IMM | 0x359 |
| CMP.W.REG | 0x35A | CMP.W.DIR | 0x35B |
| CMP.W.IDX | 0x35C | CMP.W.STK | 0x35D |
| CMP.D.IMM | 0x35E | CMP.D.REG | 0x35F |
| CMP.D.DIR | 0x360 | CMP.D.IDX | 0x361 |
| CMP.D.STK | 0x362 | CMP.Q.IMM | 0x363 |
| CMP.Q.REG | 0x364 | CMP.Q.DIR | 0x365 |
| CMP.Q.IDX | 0x366 | CMP.Q.STK | 0x367 |

#### 2.2.19 TEST — 测试 (Test)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| TEST.B.IMM | 0x368 | TEST.B.REG | 0x369 |
| TEST.B.DIR | 0x36A | TEST.B.IDX | 0x36B |
| TEST.B.STK | 0x36C | TEST.W.IMM | 0x36D |
| TEST.W.REG | 0x36E | TEST.W.DIR | 0x36F |
| TEST.W.IDX | 0x370 | TEST.W.STK | 0x371 |
| TEST.D.IMM | 0x372 | TEST.D.REG | 0x373 |
| TEST.D.DIR | 0x374 | TEST.D.IDX | 0x375 |
| TEST.D.STK | 0x376 | TEST.Q.IMM | 0x377 |
| TEST.Q.REG | 0x378 | TEST.Q.DIR | 0x379 |
| TEST.Q.IDX | 0x37A | TEST.Q.STK | 0x37B |

#### 2.2.20 SEXT — 符号扩展 (Sign Extend)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SEXT.B.IMM | 0x37C | SEXT.B.REG | 0x37D |
| SEXT.B.DIR | 0x37E | SEXT.B.IDX | 0x37F |
| SEXT.B.STK | 0x380 | SEXT.W.IMM | 0x381 |
| SEXT.W.REG | 0x382 | SEXT.W.DIR | 0x383 |
| SEXT.W.IDX | 0x384 | SEXT.W.STK | 0x385 |
| SEXT.D.IMM | 0x386 | SEXT.D.REG | 0x387 |
| SEXT.D.DIR | 0x388 | SEXT.D.IDX | 0x389 |
| SEXT.D.STK | 0x38A | SEXT.Q.IMM | 0x38B |
| SEXT.Q.REG | 0x38C | SEXT.Q.DIR | 0x38D |
| SEXT.Q.IDX | 0x38E | SEXT.Q.STK | 0x38F |

#### 2.2.21 ZEXT — 零扩展 (Zero Extend)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ZEXT.B.IMM | 0x390 | ZEXT.B.REG | 0x391 |
| ZEXT.B.DIR | 0x392 | ZEXT.B.IDX | 0x393 |
| ZEXT.B.STK | 0x394 | ZEXT.W.IMM | 0x395 |
| ZEXT.W.REG | 0x396 | ZEXT.W.DIR | 0x397 |
| ZEXT.W.IDX | 0x398 | ZEXT.W.STK | 0x399 |
| ZEXT.D.IMM | 0x39A | ZEXT.D.REG | 0x39B |
| ZEXT.D.DIR | 0x39C | ZEXT.D.IDX | 0x39D |
| ZEXT.D.STK | 0x39E | ZEXT.Q.IMM | 0x39F |
| ZEXT.Q.REG | 0x3A0 | ZEXT.Q.DIR | 0x3A1 |
| ZEXT.Q.IDX | 0x3A2 | ZEXT.Q.STK | 0x3A3 |

#### 2.2.22 BSWAP — 字节交换 (Byte Swap)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| BSWAP.B.IMM | 0x3A4 | BSWAP.B.REG | 0x3A5 |
| BSWAP.B.DIR | 0x3A6 | BSWAP.B.IDX | 0x3A7 |
| BSWAP.B.STK | 0x3A8 | BSWAP.W.IMM | 0x3A9 |
| BSWAP.W.REG | 0x3AA | BSWAP.W.DIR | 0x3AB |
| BSWAP.W.IDX | 0x3AC | BSWAP.W.STK | 0x3AD |
| BSWAP.D.IMM | 0x3AE | BSWAP.D.REG | 0x3AF |
| BSWAP.D.DIR | 0x3B0 | BSWAP.D.IDX | 0x3B1 |
| BSWAP.D.STK | 0x3B2 | BSWAP.Q.IMM | 0x3B3 |
| BSWAP.Q.REG | 0x3B4 | BSWAP.Q.DIR | 0x3B5 |
| BSWAP.Q.IDX | 0x3B6 | BSWAP.Q.STK | 0x3B7 |

#### 2.2.23 BITREV — 位反转 (Bit Reverse)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| BITREV.B.IMM | 0x3B8 | BITREV.B.REG | 0x3B9 |
| BITREV.B.DIR | 0x3BA | BITREV.B.IDX | 0x3BB |
| BITREV.B.STK | 0x3BC | BITREV.W.IMM | 0x3BD |
| BITREV.W.REG | 0x3BE | BITREV.W.DIR | 0x3BF |
| BITREV.W.IDX | 0x3C0 | BITREV.W.STK | 0x3C1 |
| BITREV.D.IMM | 0x3C2 | BITREV.D.REG | 0x3C3 |
| BITREV.D.DIR | 0x3C4 | BITREV.D.IDX | 0x3C5 |
| BITREV.D.STK | 0x3C6 | BITREV.Q.IMM | 0x3C7 |
| BITREV.Q.REG | 0x3C8 | BITREV.Q.DIR | 0x3C9 |
| BITREV.Q.IDX | 0x3CA | BITREV.Q.STK | 0x3CB |

#### 2.2.24 CLZ — 前导零计数 (Count Leading Zeros)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| CLZ.B.IMM | 0x3CC | CLZ.B.REG | 0x3CD |
| CLZ.B.DIR | 0x3CE | CLZ.B.IDX | 0x3CF |
| CLZ.B.STK | 0x3D0 | CLZ.W.IMM | 0x3D1 |
| CLZ.W.REG | 0x3D2 | CLZ.W.DIR | 0x3D3 |
| CLZ.W.IDX | 0x3D4 | CLZ.W.STK | 0x3D5 |
| CLZ.D.IMM | 0x3D6 | CLZ.D.REG | 0x3D7 |
| CLZ.D.DIR | 0x3D8 | CLZ.D.IDX | 0x3D9 |
| CLZ.D.STK | 0x3DA | CLZ.Q.IMM | 0x3DB |
| CLZ.Q.REG | 0x3DC | CLZ.Q.DIR | 0x3DD |
| CLZ.Q.IDX | 0x3DE | CLZ.Q.STK | 0x3DF |

#### 2.2.25 CTZ — 末尾零计数 (Count Trailing Zeros)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| CTZ.B.IMM | 0x3E0 | CTZ.B.REG | 0x3E1 |
| CTZ.B.DIR | 0x3E2 | CTZ.B.IDX | 0x3E3 |
| CTZ.B.STK | 0x3E4 | CTZ.W.IMM | 0x3E5 |
| CTZ.W.REG | 0x3E6 | CTZ.W.DIR | 0x3E7 |
| CTZ.W.IDX | 0x3E8 | CTZ.W.STK | 0x3E9 |
| CTZ.D.IMM | 0x3EA | CTZ.D.REG | 0x3EB |
| CTZ.D.DIR | 0x3EC | CTZ.D.IDX | 0x3ED |
| CTZ.D.STK | 0x3EE | CTZ.Q.IMM | 0x3EF |
| CTZ.Q.REG | 0x3F0 | CTZ.Q.DIR | 0x3F1 |
| CTZ.Q.IDX | 0x3F2 | CTZ.Q.STK | 0x3F3 |

#### 2.2.26 POPCNT — 置位计数 (Population Count)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| POPCNT.B.IMM | 0x3F4 | POPCNT.B.REG | 0x3F5 |
| POPCNT.B.DIR | 0x3F6 | POPCNT.B.IDX | 0x3F7 |
| POPCNT.B.STK | 0x3F8 | POPCNT.W.IMM | 0x3F9 |
| POPCNT.W.REG | 0x3FA | POPCNT.W.DIR | 0x3FB |
| POPCNT.W.IDX | 0x3FC | POPCNT.W.STK | 0x3FD |
| POPCNT.D.IMM | 0x3FE | POPCNT.D.REG | 0x3FF |
| POPCNT.D.DIR | 0x400 | POPCNT.D.IDX | 0x401 |
| POPCNT.D.STK | 0x402 | POPCNT.Q.IMM | 0x403 |
| POPCNT.Q.REG | 0x404 | POPCNT.Q.DIR | 0x405 |
| POPCNT.Q.IDX | 0x406 | POPCNT.Q.STK | 0x407 |

---

### 2.3 逻辑运算指令 (Logic Operations) — 编码范围 0x408–0x4F7

> **说明**: 每条基指令占 20 个连续编码（5 种寻址模式 × 4 种整数类型 B/W/D/Q）。编码从 0x408 开始，紧接 POPCNT 之后连续排列。
#### 2.3.1 AND — 按位与 (Bitwise AND)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| AND.B.IMM | 0x408 | AND.B.REG | 0x409 |
| AND.B.DIR | 0x40A | AND.B.IDX | 0x40B |
| AND.B.STK | 0x40C | AND.W.IMM | 0x40D |
| AND.W.REG | 0x40E | AND.W.DIR | 0x40F |
| AND.W.IDX | 0x410 | AND.W.STK | 0x411 |
| AND.D.IMM | 0x412 | AND.D.REG | 0x413 |
| AND.D.DIR | 0x414 | AND.D.IDX | 0x415 |
| AND.D.STK | 0x416 | AND.Q.IMM | 0x417 |
| AND.Q.REG | 0x418 | AND.Q.DIR | 0x419 |
| AND.Q.IDX | 0x41A | AND.Q.STK | 0x41B |

#### 2.3.2 OR — 按位或 (Bitwise OR)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| OR.B.IMM | 0x41C | OR.B.REG | 0x41D |
| OR.B.DIR | 0x41E | OR.B.IDX | 0x41F |
| OR.B.STK | 0x420 | OR.W.IMM | 0x421 |
| OR.W.REG | 0x422 | OR.W.DIR | 0x423 |
| OR.W.IDX | 0x424 | OR.W.STK | 0x425 |
| OR.D.IMM | 0x426 | OR.D.REG | 0x427 |
| OR.D.DIR | 0x428 | OR.D.IDX | 0x429 |
| OR.D.STK | 0x42A | OR.Q.IMM | 0x42B |
| OR.Q.REG | 0x42C | OR.Q.DIR | 0x42D |
| OR.Q.IDX | 0x42E | OR.Q.STK | 0x42F |

#### 2.3.3 XOR — 按位异或 (Bitwise XOR)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| XOR.B.IMM | 0x430 | XOR.B.REG | 0x431 |
| XOR.B.DIR | 0x432 | XOR.B.IDX | 0x433 |
| XOR.B.STK | 0x434 | XOR.W.IMM | 0x435 |
| XOR.W.REG | 0x436 | XOR.W.DIR | 0x437 |
| XOR.W.IDX | 0x438 | XOR.W.STK | 0x439 |
| XOR.D.IMM | 0x43A | XOR.D.REG | 0x43B |
| XOR.D.DIR | 0x43C | XOR.D.IDX | 0x43D |
| XOR.D.STK | 0x43E | XOR.Q.IMM | 0x43F |
| XOR.Q.REG | 0x440 | XOR.Q.DIR | 0x441 |
| XOR.Q.IDX | 0x442 | XOR.Q.STK | 0x443 |

#### 2.3.4 NOT — 按位取反 (Bitwise NOT)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| NOT.B.IMM | 0x444 | NOT.B.REG | 0x445 |
| NOT.B.DIR | 0x446 | NOT.B.IDX | 0x447 |
| NOT.B.STK | 0x448 | NOT.W.IMM | 0x449 |
| NOT.W.REG | 0x44A | NOT.W.DIR | 0x44B |
| NOT.W.IDX | 0x44C | NOT.W.STK | 0x44D |
| NOT.D.IMM | 0x44E | NOT.D.REG | 0x44F |
| NOT.D.DIR | 0x450 | NOT.D.IDX | 0x451 |
| NOT.D.STK | 0x452 | NOT.Q.IMM | 0x453 |
| NOT.Q.REG | 0x454 | NOT.Q.DIR | 0x455 |
| NOT.Q.IDX | 0x456 | NOT.Q.STK | 0x457 |

#### 2.3.5 SHL — 左移 (Shift Left)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SHL.B.IMM | 0x458 | SHL.B.REG | 0x459 |
| SHL.B.DIR | 0x45A | SHL.B.IDX | 0x45B |
| SHL.B.STK | 0x45C | SHL.W.IMM | 0x45D |
| SHL.W.REG | 0x45E | SHL.W.DIR | 0x45F |
| SHL.W.IDX | 0x460 | SHL.W.STK | 0x461 |
| SHL.D.IMM | 0x462 | SHL.D.REG | 0x463 |
| SHL.D.DIR | 0x464 | SHL.D.IDX | 0x465 |
| SHL.D.STK | 0x466 | SHL.Q.IMM | 0x467 |
| SHL.Q.REG | 0x468 | SHL.Q.DIR | 0x469 |
| SHL.Q.IDX | 0x46A | SHL.Q.STK | 0x46B |

#### 2.3.6 SHR — 逻辑右移 (Shift Right Logical)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SHR.B.IMM | 0x46C | SHR.B.REG | 0x46D |
| SHR.B.DIR | 0x46E | SHR.B.IDX | 0x46F |
| SHR.B.STK | 0x470 | SHR.W.IMM | 0x471 |
| SHR.W.REG | 0x472 | SHR.W.DIR | 0x473 |
| SHR.W.IDX | 0x474 | SHR.W.STK | 0x475 |
| SHR.D.IMM | 0x476 | SHR.D.REG | 0x477 |
| SHR.D.DIR | 0x478 | SHR.D.IDX | 0x479 |
| SHR.D.STK | 0x47A | SHR.Q.IMM | 0x47B |
| SHR.Q.REG | 0x47C | SHR.Q.DIR | 0x47D |
| SHR.Q.IDX | 0x47E | SHR.Q.STK | 0x47F |

#### 2.3.7 ROL — 循环左移 (Rotate Left)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ROL.B.IMM | 0x480 | ROL.B.REG | 0x481 |
| ROL.B.DIR | 0x482 | ROL.B.IDX | 0x483 |
| ROL.B.STK | 0x484 | ROL.W.IMM | 0x485 |
| ROL.W.REG | 0x486 | ROL.W.DIR | 0x487 |
| ROL.W.IDX | 0x488 | ROL.W.STK | 0x489 |
| ROL.D.IMM | 0x48A | ROL.D.REG | 0x48B |
| ROL.D.DIR | 0x48C | ROL.D.IDX | 0x48D |
| ROL.D.STK | 0x48E | ROL.Q.IMM | 0x48F |
| ROL.Q.REG | 0x490 | ROL.Q.DIR | 0x491 |
| ROL.Q.IDX | 0x492 | ROL.Q.STK | 0x493 |

#### 2.3.8 ROR — 循环右移 (Rotate Right)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ROR.B.IMM | 0x494 | ROR.B.REG | 0x495 |
| ROR.B.DIR | 0x496 | ROR.B.IDX | 0x497 |
| ROR.B.STK | 0x498 | ROR.W.IMM | 0x499 |
| ROR.W.REG | 0x49A | ROR.W.DIR | 0x49B |
| ROR.W.IDX | 0x49C | ROR.W.STK | 0x49D |
| ROR.D.IMM | 0x49E | ROR.D.REG | 0x49F |
| ROR.D.DIR | 0x4A0 | ROR.D.IDX | 0x4A1 |
| ROR.D.STK | 0x4A2 | ROR.Q.IMM | 0x4A3 |
| ROR.Q.REG | 0x4A4 | ROR.Q.DIR | 0x4A5 |
| ROR.Q.IDX | 0x4A6 | ROR.Q.STK | 0x4A7 |

#### 2.3.9 SHLD — 双精度左移 (Shift Left Double)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SHLD.B.IMM | 0x4A8 | SHLD.B.REG | 0x4A9 |
| SHLD.B.DIR | 0x4AA | SHLD.B.IDX | 0x4AB |
| SHLD.B.STK | 0x4AC | SHLD.W.IMM | 0x4AD |
| SHLD.W.REG | 0x4AE | SHLD.W.DIR | 0x4AF |
| SHLD.W.IDX | 0x4B0 | SHLD.W.STK | 0x4B1 |
| SHLD.D.IMM | 0x4B2 | SHLD.D.REG | 0x4B3 |
| SHLD.D.DIR | 0x4B4 | SHLD.D.IDX | 0x4B5 |
| SHLD.D.STK | 0x4B6 | SHLD.Q.IMM | 0x4B7 |
| SHLD.Q.REG | 0x4B8 | SHLD.Q.DIR | 0x4B9 |
| SHLD.Q.IDX | 0x4BA | SHLD.Q.STK | 0x4BB |

#### 2.3.10 SHRD — 双精度右移 (Shift Right Double)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| SHRD.B.IMM | 0x4BC | SHRD.B.REG | 0x4BD |
| SHRD.B.DIR | 0x4BE | SHRD.B.IDX | 0x4BF |
| SHRD.B.STK | 0x4C0 | SHRD.W.IMM | 0x4C1 |
| SHRD.W.REG | 0x4C2 | SHRD.W.DIR | 0x4C3 |
| SHRD.W.IDX | 0x4C4 | SHRD.W.STK | 0x4C5 |
| SHRD.D.IMM | 0x4C6 | SHRD.D.REG | 0x4C7 |
| SHRD.D.DIR | 0x4C8 | SHRD.D.IDX | 0x4C9 |
| SHRD.D.STK | 0x4CA | SHRD.Q.IMM | 0x4CB |
| SHRD.Q.REG | 0x4CC | SHRD.Q.DIR | 0x4CD |
| SHRD.Q.IDX | 0x4CE | SHRD.Q.STK | 0x4CF |

#### 2.3.11 BITEX — 位提取 (Bit Extract)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| BITEX.B.IMM | 0x4D0 | BITEX.B.REG | 0x4D1 |
| BITEX.B.DIR | 0x4D2 | BITEX.B.IDX | 0x4D3 |
| BITEX.B.STK | 0x4D4 | BITEX.W.IMM | 0x4D5 |
| BITEX.W.REG | 0x4D6 | BITEX.W.DIR | 0x4D7 |
| BITEX.W.IDX | 0x4D8 | BITEX.W.STK | 0x4D9 |
| BITEX.D.IMM | 0x4DA | BITEX.D.REG | 0x4DB |
| BITEX.D.DIR | 0x4DC | BITEX.D.IDX | 0x4DD |
| BITEX.D.STK | 0x4DE | BITEX.Q.IMM | 0x4DF |
| BITEX.Q.REG | 0x4E0 | BITEX.Q.DIR | 0x4E1 |
| BITEX.Q.IDX | 0x4E2 | BITEX.Q.STK | 0x4E3 |

#### 2.3.12 BITIN — 位插入 (Bit Insert)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| BITIN.B.IMM | 0x4E4 | BITIN.B.REG | 0x4E5 |
| BITIN.B.DIR | 0x4E6 | BITIN.B.IDX | 0x4E7 |
| BITIN.B.STK | 0x4E8 | BITIN.W.IMM | 0x4E9 |
| BITIN.W.REG | 0x4EA | BITIN.W.DIR | 0x4EB |
| BITIN.W.IDX | 0x4EC | BITIN.W.STK | 0x4ED |
| BITIN.D.IMM | 0x4EE | BITIN.D.REG | 0x4EF |
| BITIN.D.DIR | 0x4F0 | BITIN.D.IDX | 0x4F1 |
| BITIN.D.STK | 0x4F2 | BITIN.Q.IMM | 0x4F3 |
| BITIN.Q.REG | 0x4F4 | BITIN.Q.DIR | 0x4F5 |
| BITIN.Q.IDX | 0x4F6 | BITIN.Q.STK | 0x4F7 |

#### 2.3.13 逻辑运算区保留

| 范围 | 说明 |
|------|------|
| 0x4F8–0x4FF | 保留 (Reserved) |

---

### 2.4 标量浮点指令 (Floating-Point Scalar) — 编码范围 0x500–0x62B

> **说明**: 每条基指令占 20 个连续编码（5 种寻址模式 × 4 种浮点类型 F16/F32/F64/F128）。
#### 2.4.1 FADD — 浮点加法 (Floating-Point Add)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FADD.F16.IMM | 0x500 | FADD.F16.REG | 0x501 |
| FADD.F16.DIR | 0x502 | FADD.F16.IDX | 0x503 |
| FADD.F16.STK | 0x504 | FADD.F32.IMM | 0x505 |
| FADD.F32.REG | 0x506 | FADD.F32.DIR | 0x507 |
| FADD.F32.IDX | 0x508 | FADD.F32.STK | 0x509 |
| FADD.F64.IMM | 0x50A | FADD.F64.REG | 0x50B |
| FADD.F64.DIR | 0x50C | FADD.F64.IDX | 0x50D |
| FADD.F64.STK | 0x50E | FADD.F128.IMM | 0x50F |
| FADD.F128.REG | 0x510 | FADD.F128.DIR | 0x511 |
| FADD.F128.IDX | 0x512 | FADD.F128.STK | 0x513 |

#### 2.4.2 FSUB — 浮点减法 (Floating-Point Subtract)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FSUB.F16.IMM | 0x514 | FSUB.F16.REG | 0x515 |
| FSUB.F16.DIR | 0x516 | FSUB.F16.IDX | 0x517 |
| FSUB.F16.STK | 0x518 | FSUB.F32.IMM | 0x519 |
| FSUB.F32.REG | 0x51A | FSUB.F32.DIR | 0x51B |
| FSUB.F32.IDX | 0x51C | FSUB.F32.STK | 0x51D |
| FSUB.F64.IMM | 0x51E | FSUB.F64.REG | 0x51F |
| FSUB.F64.DIR | 0x520 | FSUB.F64.IDX | 0x521 |
| FSUB.F64.STK | 0x522 | FSUB.F128.IMM | 0x523 |
| FSUB.F128.REG | 0x524 | FSUB.F128.DIR | 0x525 |
| FSUB.F128.IDX | 0x526 | FSUB.F128.STK | 0x527 |

#### 2.4.3 FMUL — 浮点乘法 (Floating-Point Multiply)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FMUL.F16.IMM | 0x528 | FMUL.F16.REG | 0x529 |
| FMUL.F16.DIR | 0x52A | FMUL.F16.IDX | 0x52B |
| FMUL.F16.STK | 0x52C | FMUL.F32.IMM | 0x52D |
| FMUL.F32.REG | 0x52E | FMUL.F32.DIR | 0x52F |
| FMUL.F32.IDX | 0x530 | FMUL.F32.STK | 0x531 |
| FMUL.F64.IMM | 0x532 | FMUL.F64.REG | 0x533 |
| FMUL.F64.DIR | 0x534 | FMUL.F64.IDX | 0x535 |
| FMUL.F64.STK | 0x536 | FMUL.F128.IMM | 0x537 |
| FMUL.F128.REG | 0x538 | FMUL.F128.DIR | 0x539 |
| FMUL.F128.IDX | 0x53A | FMUL.F128.STK | 0x53B |

#### 2.4.4 FDIV — 浮点除法 (Floating-Point Divide)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FDIV.F16.IMM | 0x53C | FDIV.F16.REG | 0x53D |
| FDIV.F16.DIR | 0x53E | FDIV.F16.IDX | 0x53F |
| FDIV.F16.STK | 0x540 | FDIV.F32.IMM | 0x541 |
| FDIV.F32.REG | 0x542 | FDIV.F32.DIR | 0x543 |
| FDIV.F32.IDX | 0x544 | FDIV.F32.STK | 0x545 |
| FDIV.F64.IMM | 0x546 | FDIV.F64.REG | 0x547 |
| FDIV.F64.DIR | 0x548 | FDIV.F64.IDX | 0x549 |
| FDIV.F64.STK | 0x54A | FDIV.F128.IMM | 0x54B |
| FDIV.F128.REG | 0x54C | FDIV.F128.DIR | 0x54D |
| FDIV.F128.IDX | 0x54E | FDIV.F128.STK | 0x54F |

#### 2.4.5 FABS — 浮点绝对值 (Floating-Point Absolute)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FABS.F16.IMM | 0x550 | FABS.F16.REG | 0x551 |
| FABS.F16.DIR | 0x552 | FABS.F16.IDX | 0x553 |
| FABS.F16.STK | 0x554 | FABS.F32.IMM | 0x555 |
| FABS.F32.REG | 0x556 | FABS.F32.DIR | 0x557 |
| FABS.F32.IDX | 0x558 | FABS.F32.STK | 0x559 |
| FABS.F64.IMM | 0x55A | FABS.F64.REG | 0x55B |
| FABS.F64.DIR | 0x55C | FABS.F64.IDX | 0x55D |
| FABS.F64.STK | 0x55E | FABS.F128.IMM | 0x55F |
| FABS.F128.REG | 0x560 | FABS.F128.DIR | 0x561 |
| FABS.F128.IDX | 0x562 | FABS.F128.STK | 0x563 |

#### 2.4.6 FNEG — 浮点取负 (Floating-Point Negate)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FNEG.F16.IMM | 0x564 | FNEG.F16.REG | 0x565 |
| FNEG.F16.DIR | 0x566 | FNEG.F16.IDX | 0x567 |
| FNEG.F16.STK | 0x568 | FNEG.F32.IMM | 0x569 |
| FNEG.F32.REG | 0x56A | FNEG.F32.DIR | 0x56B |
| FNEG.F32.IDX | 0x56C | FNEG.F32.STK | 0x56D |
| FNEG.F64.IMM | 0x56E | FNEG.F64.REG | 0x56F |
| FNEG.F64.DIR | 0x570 | FNEG.F64.IDX | 0x571 |
| FNEG.F64.STK | 0x572 | FNEG.F128.IMM | 0x573 |
| FNEG.F128.REG | 0x574 | FNEG.F128.DIR | 0x575 |
| FNEG.F128.IDX | 0x576 | FNEG.F128.STK | 0x577 |

#### 2.4.7 FSQRT — 浮点平方根 (Floating-Point Square Root)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FSQRT.F16.IMM | 0x578 | FSQRT.F16.REG | 0x579 |
| FSQRT.F16.DIR | 0x57A | FSQRT.F16.IDX | 0x57B |
| FSQRT.F16.STK | 0x57C | FSQRT.F32.IMM | 0x57D |
| FSQRT.F32.REG | 0x57E | FSQRT.F32.DIR | 0x57F |
| FSQRT.F32.IDX | 0x580 | FSQRT.F32.STK | 0x581 |
| FSQRT.F64.IMM | 0x582 | FSQRT.F64.REG | 0x583 |
| FSQRT.F64.DIR | 0x584 | FSQRT.F64.IDX | 0x585 |
| FSQRT.F64.STK | 0x586 | FSQRT.F128.IMM | 0x587 |
| FSQRT.F128.REG | 0x588 | FSQRT.F128.DIR | 0x589 |
| FSQRT.F128.IDX | 0x58A | FSQRT.F128.STK | 0x58B |

#### 2.4.8 FMIN — 浮点最小值 (Floating-Point Minimum)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FMIN.F16.IMM | 0x58C | FMIN.F16.REG | 0x58D |
| FMIN.F16.DIR | 0x58E | FMIN.F16.IDX | 0x58F |
| FMIN.F16.STK | 0x590 | FMIN.F32.IMM | 0x591 |
| FMIN.F32.REG | 0x592 | FMIN.F32.DIR | 0x593 |
| FMIN.F32.IDX | 0x594 | FMIN.F32.STK | 0x595 |
| FMIN.F64.IMM | 0x596 | FMIN.F64.REG | 0x597 |
| FMIN.F64.DIR | 0x598 | FMIN.F64.IDX | 0x599 |
| FMIN.F64.STK | 0x59A | FMIN.F128.IMM | 0x59B |
| FMIN.F128.REG | 0x59C | FMIN.F128.DIR | 0x59D |
| FMIN.F128.IDX | 0x59E | FMIN.F128.STK | 0x59F |

#### 2.4.9 FMAX — 浮点最大值 (Floating-Point Maximum)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FMAX.F16.IMM | 0x5A0 | FMAX.F16.REG | 0x5A1 |
| FMAX.F16.DIR | 0x5A2 | FMAX.F16.IDX | 0x5A3 |
| FMAX.F16.STK | 0x5A4 | FMAX.F32.IMM | 0x5A5 |
| FMAX.F32.REG | 0x5A6 | FMAX.F32.DIR | 0x5A7 |
| FMAX.F32.IDX | 0x5A8 | FMAX.F32.STK | 0x5A9 |
| FMAX.F64.IMM | 0x5AA | FMAX.F64.REG | 0x5AB |
| FMAX.F64.DIR | 0x5AC | FMAX.F64.IDX | 0x5AD |
| FMAX.F64.STK | 0x5AE | FMAX.F128.IMM | 0x5AF |
| FMAX.F128.REG | 0x5B0 | FMAX.F128.DIR | 0x5B1 |
| FMAX.F128.IDX | 0x5B2 | FMAX.F128.STK | 0x5B3 |

#### 2.4.10 FCVT — 浮点类型转换 (Floating-Point Convert)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FCVT.F16.IMM | 0x5B4 | FCVT.F16.REG | 0x5B5 |
| FCVT.F16.DIR | 0x5B6 | FCVT.F16.IDX | 0x5B7 |
| FCVT.F16.STK | 0x5B8 | FCVT.F32.IMM | 0x5B9 |
| FCVT.F32.REG | 0x5BA | FCVT.F32.DIR | 0x5BB |
| FCVT.F32.IDX | 0x5BC | FCVT.F32.STK | 0x5BD |
| FCVT.F64.IMM | 0x5BE | FCVT.F64.REG | 0x5BF |
| FCVT.F64.DIR | 0x5C0 | FCVT.F64.IDX | 0x5C1 |
| FCVT.F64.STK | 0x5C2 | FCVT.F128.IMM | 0x5C3 |
| FCVT.F128.REG | 0x5C4 | FCVT.F128.DIR | 0x5C5 |
| FCVT.F128.IDX | 0x5C6 | FCVT.F128.STK | 0x5C7 |

#### 2.4.11 FLOOR — 浮点向下取整 (Floor)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FLOOR.F16.IMM | 0x5C8 | FLOOR.F16.REG | 0x5C9 |
| FLOOR.F16.DIR | 0x5CA | FLOOR.F16.IDX | 0x5CB |
| FLOOR.F16.STK | 0x5CC | FLOOR.F32.IMM | 0x5CD |
| FLOOR.F32.REG | 0x5CE | FLOOR.F32.DIR | 0x5CF |
| FLOOR.F32.IDX | 0x5D0 | FLOOR.F32.STK | 0x5D1 |
| FLOOR.F64.IMM | 0x5D2 | FLOOR.F64.REG | 0x5D3 |
| FLOOR.F64.DIR | 0x5D4 | FLOOR.F64.IDX | 0x5D5 |
| FLOOR.F64.STK | 0x5D6 | FLOOR.F128.IMM | 0x5D7 |
| FLOOR.F128.REG | 0x5D8 | FLOOR.F128.DIR | 0x5D9 |
| FLOOR.F128.IDX | 0x5DA | FLOOR.F128.STK | 0x5DB |

#### 2.4.12 CEIL — 浮点向上取整 (Ceil)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| CEIL.F16.IMM | 0x5DC | CEIL.F16.REG | 0x5DD |
| CEIL.F16.DIR | 0x5DE | CEIL.F16.IDX | 0x5DF |
| CEIL.F16.STK | 0x5E0 | CEIL.F32.IMM | 0x5E1 |
| CEIL.F32.REG | 0x5E2 | CEIL.F32.DIR | 0x5E3 |
| CEIL.F32.IDX | 0x5E4 | CEIL.F32.STK | 0x5E5 |
| CEIL.F64.IMM | 0x5E6 | CEIL.F64.REG | 0x5E7 |
| CEIL.F64.DIR | 0x5E8 | CEIL.F64.IDX | 0x5E9 |
| CEIL.F64.STK | 0x5EA | CEIL.F128.IMM | 0x5EB |
| CEIL.F128.REG | 0x5EC | CEIL.F128.DIR | 0x5ED |
| CEIL.F128.IDX | 0x5EE | CEIL.F128.STK | 0x5EF |

#### 2.4.13 ROUND — 浮点四舍五入 (Round)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| ROUND.F16.IMM | 0x5F0 | ROUND.F16.REG | 0x5F1 |
| ROUND.F16.DIR | 0x5F2 | ROUND.F16.IDX | 0x5F3 |
| ROUND.F16.STK | 0x5F4 | ROUND.F32.IMM | 0x5F5 |
| ROUND.F32.REG | 0x5F6 | ROUND.F32.DIR | 0x5F7 |
| ROUND.F32.IDX | 0x5F8 | ROUND.F32.STK | 0x5F9 |
| ROUND.F64.IMM | 0x5FA | ROUND.F64.REG | 0x5FB |
| ROUND.F64.DIR | 0x5FC | ROUND.F64.IDX | 0x5FD |
| ROUND.F64.STK | 0x5FE | ROUND.F128.IMM | 0x5FF |
| ROUND.F128.REG | 0x600 | ROUND.F128.DIR | 0x601 |
| ROUND.F128.IDX | 0x602 | ROUND.F128.STK | 0x603 |

#### 2.4.14 FMADD — 浮点乘加 (Fused Multiply-Add)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FMADD.F16.IMM | 0x604 | FMADD.F16.REG | 0x605 |
| FMADD.F16.DIR | 0x606 | FMADD.F16.IDX | 0x607 |
| FMADD.F16.STK | 0x608 | FMADD.F32.IMM | 0x609 |
| FMADD.F32.REG | 0x60A | FMADD.F32.DIR | 0x60B |
| FMADD.F32.IDX | 0x60C | FMADD.F32.STK | 0x60D |
| FMADD.F64.IMM | 0x60E | FMADD.F64.REG | 0x60F |
| FMADD.F64.DIR | 0x610 | FMADD.F64.IDX | 0x611 |
| FMADD.F64.STK | 0x612 | FMADD.F128.IMM | 0x613 |
| FMADD.F128.REG | 0x614 | FMADD.F128.DIR | 0x615 |
| FMADD.F128.IDX | 0x616 | FMADD.F128.STK | 0x617 |

#### 2.4.15 FMSUB — 浮点乘减 (Fused Multiply-Subtract)

| 助记符 | 编码 | 助记符 | 编码 |
|--------|------|--------|------|
| FMSUB.F16.IMM | 0x618 | FMSUB.F16.REG | 0x619 |
| FMSUB.F16.DIR | 0x61A | FMSUB.F16.IDX | 0x61B |
| FMSUB.F16.STK | 0x61C | FMSUB.F32.IMM | 0x61D |
| FMSUB.F32.REG | 0x61E | FMSUB.F32.DIR | 0x61F |
| FMSUB.F32.IDX | 0x620 | FMSUB.F32.STK | 0x621 |
| FMSUB.F64.IMM | 0x622 | FMSUB.F64.REG | 0x623 |
| FMSUB.F64.DIR | 0x624 | FMSUB.F64.IDX | 0x625 |
| FMSUB.F64.STK | 0x626 | FMSUB.F128.IMM | 0x627 |
| FMSUB.F128.REG | 0x628 | FMSUB.F128.DIR | 0x629 |
| FMSUB.F128.IDX | 0x62A | FMSUB.F128.STK | 0x62B |

---

### 2.5 程序控制指令 (Program Control) — 编码范围 0x62C–0x6FF

> **说明**: 程序控制指令沿用 5 种寻址模式，紧接 FMSUB 之后从 0x62C 开始连续编码。
#### 2.5.1 多寻址模式程序控制指令

| 指令 | IMM | REG | DIR | IDX | STK | 说明 |
|------|-----|-----|-----|-----|-----|------|
| **JMP** | 0x62C | 0x62D | 0x62E | 0x62F | 0x630 | 无条件跳转 (Jump) |
| **CALL** | 0x631 | 0x632 | 0x633 | 0x634 | 0x635 | 函数调用 (Call) |
| **RET** | 0x636 | 0x637 | 0x638 | 0x639 | 0x63A | 函数返回 (Return) |
| **INT** | 0x63B | 0x63C | 0x63D | 0x63E | 0x63F | 软件中断 (Software Interrupt) |
| **IRET** | 0x640 | 0x641 | 0x642 | 0x643 | 0x644 | 中断返回 (Interrupt Return) |
| **JE** | 0x645 | 0x646 | 0x647 | 0x648 | 0x649 | 等于跳转 (Jump if Equal) |
| **JNE** | 0x64A | 0x64B | 0x64C | 0x64D | 0x64E | 不等跳转 (Jump if Not Equal) |
| **JG** | 0x64F | 0x650 | 0x651 | 0x652 | 0x653 | 大于跳转 (Jump if Greater) |
| **JL** | 0x654 | 0x655 | 0x656 | 0x657 | 0x658 | 小于跳转 (Jump if Less) |
| **JGE** | 0x659 | 0x65A | 0x65B | 0x65C | 0x65D | 大于等于跳转 (Jump if Greater or Equal) |
| **JLE** | 0x65E | 0x65F | 0x660 | 0x661 | 0x662 | 小于等于跳转 (Jump if Less or Equal) |
| **JA** | 0x663 | 0x664 | 0x665 | 0x666 | 0x667 | 无符号大于跳转 (Jump if Above) |
| **JB** | 0x668 | 0x669 | 0x66A | 0x66B | 0x66C | 无符号小于跳转 (Jump if Below) |
| **JAE** | 0x66D | 0x66E | 0x66F | 0x670 | 0x671 | 无符号大于等于 (Jump if Above or Equal) |
| **JBE** | 0x672 | 0x673 | 0x674 | 0x675 | 0x676 | 无符号小于等于 (Jump if Below or Equal) |
| **NOP** | 0x677 | 0x678 | 0x679 | 0x67A | 0x67B | 空操作 (No Operation) |
| **HLT** | 0x67C | 0x67D | 0x67E | 0x67F | 0x680 | 停机 (Halt) |
| **CPUID** | 0x681 | 0x682 | 0x683 | 0x684 | 0x685 | CPU 标识 (CPU Identification) |
| **SYSCALL** | 0x686 | 0x687 | 0x688 | 0x689 | 0x68A | 系统调用 (System Call) |
| **TRAP** | 0x68B | 0x68C | 0x68D | 0x68E | 0x68F | 陷阱 (Trap) |
| **ERET** | 0x690 | 0x691 | 0x692 | 0x693 | 0x694 | 异常返回 (Exception Return) |
| **WAIT** | 0x698 | 0x699 | 0x69A | 0x69B | 0x69C | 等待事件 (Wait for Event) |
| **YIELD** | 0x69D | 0x69E | 0x69F | 0x6A0 | 0x6A1 | 让出执行 (Yield) |
#### 2.5.2 调试与系统控制指令（固定编码）

| 指令 | 编码 | 说明 |
|------|------|------|
| **BKPT** | 0x695 | 断点 (Breakpoint) |
| **TRACE** | 0x696 | 追踪使能 (Trace Enable) |
| **WATCHDOG** | 0x697 | 看门狗触发 (Watchdog Trigger) |

#### 2.5.3 程序控制区保留

| 范围 | 说明 |
|------|------|
| 0x6A2–0x6FF | 保留 (Reserved) |

---

### 2.6 SIMD 向量指令 (SIMD Vector) — 编码范围 0x700–0x7FF

> **说明**: 向量指令的数据类型后缀为 .I8、.I16、.I32、.F32、.F64，每种子类型占 1 个编码。

#### 2.6.1 向量算术指令

| 指令 | 编码范围 | 向量元素类型 | 说明 |
|------|----------|-------------|------|
| **VADD** | 0x700–0x704 | I8 / I16 / I32 / F32 / F64 | 向量加法 (Vector Add) |
| **VSUB** | 0x705–0x709 | I8 / I16 / I32 / F32 / F64 | 向量减法 (Vector Subtract) |
| **VMUL** | 0x70A–0x70E | I8 / I16 / I32 / F32 / F64 | 向量乘法 (Vector Multiply) |
| **VDIV** | 0x70F–0x710 | F32 / F64 | 向量除法 (Vector Divide) — 仅浮点 |
| **VABS** | 0x711–0x715 | I8 / I16 / I32 / F32 / F64 | 向量绝对值 (Vector Absolute) |
| **VNEG** | 0x716–0x71A | I8 / I16 / I32 / F32 / F64 | 向量取负 (Vector Negate) |

#### 2.6.2 向量逻辑与移位指令

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VAND** | 0x71B–0x71D | 向量按位与 (Vector Bitwise AND) |
| **VOR** | 0x71E–0x720 | 向量按位或 (Vector Bitwise OR) |
| **VXOR** | 0x721–0x723 | 向量按位异或 (Vector Bitwise XOR) |
| **VSHL** | 0x724–0x728 | 向量左移 (Vector Shift Left) |
| **VSHR** | 0x729–0x72E | 向量右移 (Vector Shift Right) |

#### 2.6.3 向量内存操作

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VLOAD** | 0x72F–0x738 | 向量加载 (Vector Load) — 含连续/跨步/索引变体 |
| **VSTORE** | 0x739–0x73D | 向量存储 (Vector Store) |

#### 2.6.4 向量排列与重组

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VPERM** | 0x73E–0x741 | 向量置换 (Vector Permute) |
| **VEXTRACT** | 0x742–0x744 | 向量提取 (Vector Extract) |
| **VINSERT** | 0x745–0x747 | 向量插入 (Vector Insert) |
| **VSHUFFLE** | 0x748–0x74B | 向量乱序 (Vector Shuffle) |
| **VBROADCAST** | 0x74C–0x74E | 向量广播 (Vector Broadcast) |
| **VGATHER** | 0x74F–0x750 | 向量收集 (Vector Gather) |
| **VSCATTER** | 0x751–0x752 | 向量散布 (Vector Scatter) |

#### 2.6.5 向量比较与选择

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VCMPEQ** | 0x753–0x757 | 向量比较相等 (Vector Compare Equal) |
| **VCMPGT** | 0x758–0x75E | 向量比较大于 (Vector Compare Greater Than) |
| **VCMPLT** | 0x75F–0x764 | 向量比较小于 (Vector Compare Less Than) |
| **VMIN** | 0x765–0x769 | 向量最小值 (Vector Minimum) |
| **VMAX** | 0x76A–0x76F | 向量最大值 (Vector Maximum) |

#### 2.6.6 向量融合乘加/乘减

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VFMADD** | 0x770–0x77E | 向量浮点乘加 (Vector Fused Multiply-Add) |
| **VFMSUB** | 0x77F–0x78E | 向量浮点乘减 (Vector Fused Multiply-Subtract) |

#### 2.6.7 向量近似倒数与平方根

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **VRSQRT** | 0x78F–0x793 | 向量倒数平方根近似 (Vector Reciprocal Sqrt Approx.) |
| **VRCP** | 0x794–0x798 | 向量倒数近似 (Vector Reciprocal Approx.) |
| **VSQRT** | 0x799–0x79D | 向量平方根 (Vector Square Root) |

#### 2.6.8 SIMD 向量区保留

| 范围 | 说明 |
|------|------|
| 0x79E–0x7BF | 保留 (Reserved) |

---

### 2.7 系统与特权指令 (System & Privileged) — 编码范围 0x7C0–0x9FF

#### 2.7.1 终端系统控制指令（编码 0x7C0–0x7CF）

| 指令 | 编码 | 说明 |
|------|------|------|
| **SYS_EOI** | 0x7C0–0x7C4 | 中断结束 (End of Interrupt) |
| **SYS_HALT** | 0x7C5–0x7C9 | 系统停机 (System Halt) |
| **SYS_RESET** | 0x7CA–0x7CE | 系统复位 (System Reset) |
| **SYS_SHUTDOWN.STK** | 0x7CF | 系统关断 (System Shutdown) — **最后一条标准指令** |

#### 2.7.2 系统寄存器访问

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **SYS_CR_RD** | 0x800–0x80F | 读控制寄存器 (Control Register Read) |
| **SYS_CR_WR** | 0x810–0x81F | 写控制寄存器 (Control Register Write) |
| **SYS_MSR_RD** | 0x820–0x82F | 读模型特定寄存器 (MSR Read) |
| **SYS_MSR_WR** | 0x830–0x83E | 写模型特定寄存器 (MSR Write) |

#### 2.7.3 加密加速指令

| 指令 | 编码 | 说明 |
|------|------|------|
| **AESENC** | 0x83F | AES 加密轮 (AES Encrypt Round) |
| **AESDEC** | 0x840 | AES 解密轮 (AES Decrypt Round) |
| **AESKEYGEN** | 0x841 | AES 密钥生成 (AES Key Generation) |
| **SHA256H** | 0x842 | SHA-256 哈希压缩 (SHA-256 Hash Compression) |
| **SHA256S** | 0x843 | SHA-256 调度 (SHA-256 Schedule) |
| **RSAEXP** | 0x844 | RSA 模幂 (RSA Modular Exponentiation) |
| **RSAMOD** | 0x845 | RSA 模乘 (RSA Modular Multiplication) |
| **CRC32** | 0x846 | CRC32 校验 (CRC32 Checksum) |
| **RDRAND** | 0x847 | 硬件随机数 (Hardware Random Number) |
| **RDTSC** | 0x848 | 读时间戳计数器 (Read Timestamp Counter) |

#### 2.7.4 虚拟化指令

| 指令 | 编码 | 说明 |
|------|------|------|
| **VMRUN** | 0x849 | 虚拟机运行 (VM Run) |
| **VMEXIT** | 0x84A | 虚拟机退出 (VM Exit) |
| **VMLAUNCH** | 0x84B | 虚拟机启动 (VM Launch) |
| **VMRESUME** | 0x84C | 虚拟机恢复 (VM Resume) |
| **VMREAD** | 0x84D–0x856 | 读取 VMCS 字段 (VM Read) |
| **VMWRITE** | 0x857–0x85F | 写入 VMCS 字段 (VM Write) |

#### 2.7.5 HYP 调用

| 指令 | 编码范围 | 说明 |
|------|----------|------|
| **SYS_HYP_CALL** | 0x860–0x86F | 管理程序调用 (Hypervisor Call) |

#### 2.7.6 调试与追踪

| 指令 | 编码 | 说明 |
|------|------|------|
| **SYS_DEBUG_LOCK** | 0x870 | 调试锁定 (Debug Lock) |
| **SYS_DEBUG_UNLOCK** | 0x871 | 调试解锁 (Debug Unlock) |
| **SYS_TRACE_EN** | 0x872–0x876 | 追踪使能 (Trace Enable) |
| **SYS_TRACE_DIS** | 0x877–0x87B | 追踪禁用 (Trace Disable) |

#### 2.7.7 看门狗与性能监控

| 指令 | 编码 | 说明 |
|------|------|------|
| **SYS_WDT_EN** | 0x87C | 看门狗使能 (Watchdog Enable) |
| **SYS_WDT_KICK** | 0x87D | 看门狗喂狗 (Watchdog Kick) |
| **SYS_PERF_RD** | 0x87E–0x887 | 读性能计数器 (Performance Counter Read) |
| **SYS_PERF_RST** | 0x888–0x88F | 复位性能计数器 (Performance Counter Reset) |

#### 2.7.8 电源、时钟与中断管理

| 模块 | 编码范围 | 说明 |
|------|----------|------|
| **电源管理 (Power Management)** | 0x890–0x89F | 休眠、变频、电源域控制等 |
| **时钟管理 (Clock Management)** | 0x8A0–0x8BF | PLL 配置、时钟门控等 |
| **中断管理 (Interrupt Management)** | 0x8C0–0x8FF | 中断控制器配置、优先级、掩码等 |

#### 2.7.9 缓存 / TLB / 调试 / 安全

| 模块 | 编码范围 | 说明 |
|------|----------|------|
| **缓存操作 (Cache Operations)** | 0x900–0x93F | 缓存无效化、清洗、刷新、预取等 |
| **TLB 操作 (TLB Operations)** | 0x940–0x97F | TLB 无效化、同步、ASID 管理等 |
| **调试 (Debug)** | 0x980–0x9BF | 硬件断点、观察点、JTAG 控制等 |
| **安全 (Security)** | 0x9C0–0x9FF | 安全监视器调用、可信执行环境控制等 |

---

## 3. 厂商自定义微操作区 (Vendor Custom Micro-Op Zone)

> **⚠️ 厂商可自定义区域 — 编码范围 0x000–0x0FF — 可自由修改**
>
> 以下为 **MISC-R 推荐实现**。各厂商可根据自身微架构需求自由调整本区域内的指令定义、编码和语义。本区域指令通常为原子微操作，由宏指令译码后分解执行。

### 3.1 ALU 微操作 (ALU Micro-Ops) — 编码范围 0x00–0x1F

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uNOP** | 0x00 | 空操作 (No Operation) |
| **uADD** | 0x01 | 加法 (Add) |
| **uSUB** | 0x02 | 减法 (Subtract) |
| **uMUL** | 0x03 | 乘法 (Multiply) |
| **uDIV** | 0x04 | 除法 (Divide) |
| **uREM** | 0x05 | 取余 (Remainder) |
| **uAND** | 0x06 | 按位与 (Bitwise AND) |
| **uOR** | 0x07 | 按位或 (Bitwise OR) |
| **uXOR** | 0x08 | 按位异或 (Bitwise XOR) |
| **uNOT** | 0x09 | 按位取反 (Bitwise NOT) |
| **uSHL** | 0x0A | 逻辑左移 (Shift Left) |
| **uSHR** | 0x0B | 逻辑右移 (Shift Right Logical) |
| **uSAR** | 0x0C | 算术右移 (Shift Right Arithmetic) |
| **uROL** | 0x0D | 循环左移 (Rotate Left) |
| **uROR** | 0x0E | 循环右移 (Rotate Right) |
| **uCMP** | 0x0F | 比较 (Compare) |
| **uMIN** | 0x10 | 有符号最小值 (Signed Minimum) |
| **uMAX** | 0x11 | 有符号最大值 (Signed Maximum) |
| **uMINU** | 0x12 | 无符号最小值 (Unsigned Minimum) |
| **uMAXU** | 0x13 | 无符号最大值 (Unsigned Maximum) |
| **uABS** | 0x14 | 绝对值 (Absolute Value) |
| **uNEG** | 0x15 | 取负 (Negate) |
| **uSEXT.B** | 0x16 | 字节符号扩展 (Sign Extend Byte) |
| **uSEXT.W** | 0x17 | 字符号扩展 (Sign Extend Word) |
| **uZEXT.B** | 0x18 | 字节零扩展 (Zero Extend Byte) |
| **uZEXT.W** | 0x19 | 字零扩展 (Zero Extend Word) |
| **uREV** | 0x1A | 位反转 (Bit Reverse) |
| **uCLZ** | 0x1B | 前导零计数 (Count Leading Zeros) |
| **uCTZ** | 0x1C | 末尾零计数 (Count Trailing Zeros) |
| **uPOPCNT** | 0x1D | 置位计数 (Population Count) |
| — | 0x1E–0x1F | 保留 (Reserved) |

### 3.2 内存微操作 (Memory Micro-Ops) — 编码范围 0x20–0x2F

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uLDB** | 0x20 | 加载字节 — 符号扩展 (Load Byte, sign-extend) |
| **uLDBU** | 0x21 | 加载无符号字节 (Load Byte Unsigned) |
| **uLDH** | 0x22 | 加载半字 — 符号扩展 (Load Halfword, sign-extend) |
| **uLDHU** | 0x23 | 加载无符号半字 (Load Halfword Unsigned) |
| **uLDW** | 0x24 | 加载字 (Load Word) |
| **uLDD** | 0x25 | 加载双字 (Load Doubleword) |
| **uSTB** | 0x26 | 存储字节 (Store Byte) |
| **uSTH** | 0x27 | 存储半字 (Store Halfword) |
| **uSTW** | 0x28 | 存储字 (Store Word) |
| **uSTD** | 0x29 | 存储双字 (Store Doubleword) |
| **uLDEX** | 0x2A | 独占加载 (Load Exclusive) |
| **uSTEX** | 0x2B | 独占存储 (Store Exclusive) |
| **uFENCE** | 0x2C | 内存栅栏 (Memory Fence) |
| **uFLUSH** | 0x2D | 缓存行刷新 (Cache Line Flush) |
| — | 0x2E–0x2F | 保留 (Reserved) |

### 3.3 控制流微操作 (Control Micro-Ops) — 编码范围 0x30–0x3F

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uJMP** | 0x30 | 寄存器间接跳转 (Register Indirect Jump) |
| **uJMPI** | 0x31 | 立即数跳转 (Immediate Jump) |
| **uBEQ** | 0x32 | 相等则分支 (Branch if Equal) |
| **uBNE** | 0x33 | 不等则分支 (Branch if Not Equal) |
| **uBLT** | 0x34 | 有符号小于则分支 (Branch if Less Than, signed) |
| **uBGE** | 0x35 | 有符号大于等于则分支 (Branch if Greater or Equal, signed) |
| **uBLTU** | 0x36 | 无符号小于则分支 (Branch if Less Than, unsigned) |
| **uBGEU** | 0x37 | 无符号大于等于则分支 (Branch if Greater or Equal, unsigned) |
| **uCALL** | 0x38 | 函数调用 (Call) |
| **uCALLI** | 0x39 | 立即数函数调用 (Call Immediate) |
| **uRET** | 0x3A | 函数返回 (Return) |
| **uSYSCALL** | 0x3B | 系统调用 (System Call) |
| **uERET** | 0x3C | 异常返回 (Exception Return) |
| **uBREAK** | 0x3D | 断点 (Breakpoint) |
| — | 0x3E–0x3F | 保留 (Reserved) |

### 3.4 ALU 立即数变体 (ALU Immediate Variants) — 编码范围 0x40–0x5F

| 范围 | 说明 |
|------|------|
| 0x40–0x5F | ALU 微操作的立即数寻址模式变体（uADDI、uSUBI、uANDI、uORI、uXORI 等），具体映射由厂商自定义 |

### 3.5 硬件加速器微操作 (Accelerator Micro-Ops) — 编码范围 0x60–0x7F

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uAESENC** | 0x60 | AES 加密轮 (AES Encrypt Round) |
| **uAESDEC** | 0x61 | AES 解密轮 (AES Decrypt Round) |
| **uAESKEYGEN** | 0x62 | AES 密钥生成 (AES Key Generation) |
| **uSHA256R** | 0x63 | SHA-256 压缩轮 (SHA-256 Compression Round) |
| **uSHA256S** | 0x64 | SHA-256 调度 (SHA-256 Schedule) |
| **uRSAEXP** | 0x65 | RSA 模幂 (RSA Modular Exponentiation) |
| **uRSAMOD** | 0x66 | RSA 模乘 (RSA Modular Multiplication) |
| **uCRC32** | 0x67 | CRC32 校验 (CRC32 Checksum) |
| **uRDRAND** | 0x68 | 硬件随机数生成 (Hardware Random Number) |
| **uRDTSC** | 0x69 | 读时间戳计数器 (Read Timestamp Counter) |
| **uFMADD** | 0x6A | 浮点乘加 (FP Fused Multiply-Add) |
| **uFMSUB** | 0x6B | 浮点乘减 (FP Fused Multiply-Subtract) |
| **uDSPMAC** | 0x6C | DSP 乘累加 (DSP Multiply-Accumulate) |
| **uDSPMUL** | 0x6D | DSP 乘法 (DSP Multiply) |
| **uDSPADD** | 0x6E | DSP 加法 (DSP Add) |
| **uDSPSUB** | 0x6F | DSP 减法 (DSP Subtract) |
| — | 0x70–0x7F | 保留 (Reserved) |

### 3.6 向量微操作 (Vector Micro-Ops) — 编码范围 0x80–0xBF

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uVADD** | 0x80 | 向量加法 (Vector Add) |
| **uVSUB** | 0x81 | 向量减法 (Vector Subtract) |
| **uVMUL** | 0x82 | 向量乘法 (Vector Multiply) |
| **uVDIV** | 0x83 | 向量除法 (Vector Divide) |
| **uVAND** | 0x84 | 向量按位与 (Vector Bitwise AND) |
| **uVOR** | 0x85 | 向量按位或 (Vector Bitwise OR) |
| **uVXOR** | 0x86 | 向量按位异或 (Vector Bitwise XOR) |
| **uVSHL** | 0x87 | 向量左移 (Vector Shift Left) |
| **uVSHR** | 0x88 | 向量右移 (Vector Shift Right) |
| **uVLD** | 0x89 | 向量加载 (Vector Load) |
| **uVST** | 0x8A | 向量存储 (Vector Store) |
| **uVPERM** | 0x8B | 向量置换 (Vector Permute) |
| **uVEXTRACT** | 0x8C | 向量元素提取 (Vector Extract) |
| **uVINSERT** | 0x8D | 向量元素插入 (Vector Insert) |
| **uVSHUFFLE** | 0x8E | 向量乱序 (Vector Shuffle) |
| **uVBROADCAST** | 0x8F | 向量广播 (Vector Broadcast) |
| **uVGATHER** | 0x90 | 向量收集 (Vector Gather) |
| **uVSCATTER** | 0x91 | 向量散布 (Vector Scatter) |
| **uVCMPEQ** | 0x92 | 向量比较相等 (Vector Compare Equal) |
| **uVCMPGT** | 0x93 | 向量比较大于 (Vector Compare Greater Than) |
| **uVCMPLT** | 0x94 | 向量比较小于 (Vector Compare Less Than) |
| **uVMIN** | 0x95 | 向量最小值 (Vector Minimum) |
| **uVMAX** | 0x96 | 向量最大值 (Vector Maximum) |
| **uVFMADD** | 0x97 | 向量浮点乘加 (Vector Fused Multiply-Add) |
| **uVFMSUB** | 0x98 | 向量浮点乘减 (Vector Fused Multiply-Subtract) |
| **uVRSQRT** | 0x99 | 向量倒数平方根近似 (Vector Reciprocal Sqrt Approx.) |
| **uVRCP** | 0x9A | 向量倒数近似 (Vector Reciprocal Approx.) |
| **uVSQRT** | 0x9B | 向量平方根 (Vector Square Root) |
| — | 0x9C–0xBF | 保留 (Reserved) |

### 3.7 系统微操作 (System Micro-Ops) — 编码范围 0xC0–0xDF

| 助记符 | 编码 | 说明 |
|--------|------|------|
| **uFENCE.I** | 0xC0 | 指令栅栏 (Instruction Fence / I-cache sync) |
| **uDSB** | 0xC1 | 数据同步屏障 (Data Synchronization Barrier) |
| **uDMB** | 0xC2 | 数据内存屏障 (Data Memory Barrier) |
| **uISB** | 0xC3 | 指令同步屏障 (Instruction Synchronization Barrier) |
| **uWFI** | 0xC4 | 等待中断 (Wait For Interrupt) |
| **uWFE** | 0xC5 | 等待事件 (Wait For Event) |
| **uSEV** | 0xC6 | 发送事件 (Send Event) |
| **uSEVL** | 0xC7 | 发送本地事件 (Send Event Local) |
| **uYIELD** | 0xC8 | 让出 (Yield) |
| **uPREFETCH** | 0xC9 | 预取 (Prefetch) |
| **uCACHE.INV** | 0xCA | 缓存无效化 (Cache Invalidate) |
| **uCACHE.CLEAN** | 0xCB | 缓存清洗 (Cache Clean) |
| **uCACHE.FLUSH** | 0xCC | 缓存刷新 (Cache Flush) |
| **uTLBI** | 0xCD | TLB 无效化 (TLB Invalidate) |
| **uTLBSYNC** | 0xCE | TLB 同步 (TLB Sync) |
| **uSLEEP** | 0xCF | 休眠 (Sleep) |
| — | 0xD0–0xDF | 保留 (Reserved) |

### 3.8 厂商全自定义区 (Fully Custom) — 编码范围 0xE0–0xFF

| 范围 | 说明 |
|------|------|
| 0xE0–0xFF | 完全由厂商自定义。可用于自定义加速器、扩展指令、调试/诊断微操作等。MISC-R 规范不对此区域做任何限制。 |

---

**（中文版结束 / End of Chinese Version）**

---

# Part 2: English Version

---

## 1. Overview

The MISC-2000 is a high-performance CISC architecture processor integrating integer arithmetic, floating-point (scalar & vector SIMD), virtualization, hardware security acceleration, and other rich capabilities. Its instruction set is organized into two primary tiers:

- **Standard CISC Macro-Instruction Set** — occupies encoding space **0x100–0x7CF**, comprising **1744 instructions**. This portion is an **industry mandatory standard** and **MUST NOT be modified** by any implementation (MANDATORY, CANNOT be modified).
- **Vendor Custom Micro-Op Zone** — occupies encoding space **0x000–0x0FF**, comprising **256 instructions**. This document provides the **MISC-R recommended implementation**, but **vendors can freely modify** it.

All instructions use fixed-length encoding. Mnemonics use `.` delimited suffixes to indicate addressing mode and data type.

### 1.1 Mnemonic Naming Rules

| Suffix Type | Suffix | Meaning |
|-------------|--------|---------|
| Addressing Mode | `.IMM` | Immediate addressing |
| Addressing Mode | `.REG` | Register addressing |
| Addressing Mode | `.DIR` | Direct addressing |
| Addressing Mode | `.IDX` | Indexed addressing |
| Addressing Mode | `.STK` | Stack addressing |
| Integer Type | `.B` | 8-bit Byte |
| Integer Type | `.W` | 16-bit Word |
| Integer Type | `.D` | 32-bit Doubleword |
| Integer Type | `.Q` | 64-bit Quadword |
| Float Type | `.F16` | 16-bit Half-precision (IEEE 754 binary16) |
| Float Type | `.F32` | 32-bit Single-precision (IEEE 754 binary32) |
| Float Type | `.F64` | 64-bit Double-precision (IEEE 754 binary64) |
| Float Type | `.F128` | 128-bit Quad-precision (IEEE 754 binary128) |
| Vector Type | `.I8` | 8-bit integer vector element |
| Vector Type | `.I16` | 16-bit integer vector element |
| Vector Type | `.I32` | 32-bit integer vector element |
| Vector Type | `.F32` | 32-bit float vector element |
| Vector Type | `.F64` | 64-bit float vector element |

---

## 2. Standard CISC Macro-Instruction Set

> **⚠️ MANDATORY STANDARD REGION — Encoding Range 0x100–0x7CF — CANNOT BE MODIFIED**
>
> All instruction encodings below are mandatory components of the ISA standard. Any MISC-2000-compatible implementation MUST implement all instructions in this region identically.

### 2.1 Data Transfer Instructions — Encoding Range 0x100–0x1FF

#### 2.1.1 Basic Data Transfer

| Instruction | IMM | REG | DIR | IDX | STK | Description |
|-------------|-----|-----|-----|-----|-----|-------------|
| **MOV** | 0x100 | 0x101 | 0x102 | 0x103 | 0x104 | Move data |
| **LOAD** | 0x105 | 0x106 | 0x107 | 0x108 | 0x109 | Load from memory |
| **STORE** | 0x10A | 0x10B | 0x10C | 0x10D | 0x10E | Store to memory |
| **PUSH** | 0x10F | 0x110 | 0x111 | 0x112 | 0x113 | Push onto stack |
| **POP** | 0x114 | 0x115 | 0x116 | 0x117 | 0x118 | Pop from stack |
| **XCHG** | 0x119 | 0x11A | 0x11B | 0x11C | 0x11D | Exchange |
| **LEA** | 0x11E | 0x11F | 0x120 | 0x121 | 0x122 | Load Effective Address |
| **MOVSX** | 0x123 | 0x124 | 0x125 | 0x126 | 0x127 | Move with Sign-Extend |
| **MOVZX** | 0x128 | 0x129 | 0x12A | 0x12B | 0x12C | Move with Zero-Extend |
| **CMOV** | 0x12D | 0x12E | 0x12F | 0x130 | 0x131 | Conditional Move |

#### 2.1.2 Atomic Operations & Special Data Transfer

| Instruction | IMM | REG | DIR | IDX | STK | Description |
|-------------|-----|-----|-----|-----|-----|-------------|
| **LDALL** | 0x135 | 0x136 | 0x137 | 0x138 | 0x139 | Load All |
| **STALL** | 0x13A | 0x13B | 0x13C | 0x13D | 0x13E | Store All |
| **SWAP** | 0x13F | 0x140 | 0x141 | 0x142 | 0x143 | Atomic Swap |
| **CAS** | 0x144 | 0x145 | 0x146 | 0x147 | 0x148 | Compare-and-Swap |
| **LDADD** | 0x149 | 0x14A | 0x14B | 0x14C | 0x14D | Atomic Add then Load |
| **LDSET** | 0x14E | 0x14F | 0x150 | 0x151 | 0x152 | Atomic Set-bit then Load |
| **LDCLR** | 0x153 | 0x154 | 0x155 | 0x156 | 0x157 | Atomic Clear-bit then Load |
| **PREFETCH** | 0x158 | 0x159 | 0x15A | 0x15B | 0x15C | Prefetch |

#### 2.1.3 Special Data Transfer (Fixed Encoding)

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **MOV.R2M** | 0x132 | Register-to-Memory Move |
| **MOV.M2R** | 0x133 | Memory-to-Register Move |
| **MOV.M2M** | 0x134 | Memory-to-Memory Move |

#### 2.1.4 Memory Barrier Instructions

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **MEMBAR** | 0x15D | Memory Barrier |
| **FENCE** | 0x15E | Full Fence |

#### 2.1.5 Reserved

| Range | Description |
|-------|-------------|
| 0x15F–0x1FF | Reserved |

---

### 2.2 Integer Arithmetic Instructions — Encoding Range 0x200–0x407

> **Note**: Each base instruction occupies 20 consecutive encodings (5 addressing modes × 4 integer types B/W/D/Q).
#### 2.2.1 ADD — Add

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ADD.B.IMM | 0x200 | ADD.B.REG | 0x201 |
| ADD.B.DIR | 0x202 | ADD.B.IDX | 0x203 |
| ADD.B.STK | 0x204 | ADD.W.IMM | 0x205 |
| ADD.W.REG | 0x206 | ADD.W.DIR | 0x207 |
| ADD.W.IDX | 0x208 | ADD.W.STK | 0x209 |
| ADD.D.IMM | 0x20A | ADD.D.REG | 0x20B |
| ADD.D.DIR | 0x20C | ADD.D.IDX | 0x20D |
| ADD.D.STK | 0x20E | ADD.Q.IMM | 0x20F |
| ADD.Q.REG | 0x210 | ADD.Q.DIR | 0x211 |
| ADD.Q.IDX | 0x212 | ADD.Q.STK | 0x213 |

#### 2.2.2 SUB — Subtract

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SUB.B.IMM | 0x214 | SUB.B.REG | 0x215 |
| SUB.B.DIR | 0x216 | SUB.B.IDX | 0x217 |
| SUB.B.STK | 0x218 | SUB.W.IMM | 0x219 |
| SUB.W.REG | 0x21A | SUB.W.DIR | 0x21B |
| SUB.W.IDX | 0x21C | SUB.W.STK | 0x21D |
| SUB.D.IMM | 0x21E | SUB.D.REG | 0x21F |
| SUB.D.DIR | 0x220 | SUB.D.IDX | 0x221 |
| SUB.D.STK | 0x222 | SUB.Q.IMM | 0x223 |
| SUB.Q.REG | 0x224 | SUB.Q.DIR | 0x225 |
| SUB.Q.IDX | 0x226 | SUB.Q.STK | 0x227 |

#### 2.2.3 MUL — Multiply

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MUL.B.IMM | 0x228 | MUL.B.REG | 0x229 |
| MUL.B.DIR | 0x22A | MUL.B.IDX | 0x22B |
| MUL.B.STK | 0x22C | MUL.W.IMM | 0x22D |
| MUL.W.REG | 0x22E | MUL.W.DIR | 0x22F |
| MUL.W.IDX | 0x230 | MUL.W.STK | 0x231 |
| MUL.D.IMM | 0x232 | MUL.D.REG | 0x233 |
| MUL.D.DIR | 0x234 | MUL.D.IDX | 0x235 |
| MUL.D.STK | 0x236 | MUL.Q.IMM | 0x237 |
| MUL.Q.REG | 0x238 | MUL.Q.DIR | 0x239 |
| MUL.Q.IDX | 0x23A | MUL.Q.STK | 0x23B |

#### 2.2.4 DIV — Divide

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| DIV.B.IMM | 0x23C | DIV.B.REG | 0x23D |
| DIV.B.DIR | 0x23E | DIV.B.IDX | 0x23F |
| DIV.B.STK | 0x240 | DIV.W.IMM | 0x241 |
| DIV.W.REG | 0x242 | DIV.W.DIR | 0x243 |
| DIV.W.IDX | 0x244 | DIV.W.STK | 0x245 |
| DIV.D.IMM | 0x246 | DIV.D.REG | 0x247 |
| DIV.D.DIR | 0x248 | DIV.D.IDX | 0x249 |
| DIV.D.STK | 0x24A | DIV.Q.IMM | 0x24B |
| DIV.Q.REG | 0x24C | DIV.Q.DIR | 0x24D |
| DIV.Q.IDX | 0x24E | DIV.Q.STK | 0x24F |

#### 2.2.5 MOD — Modulo

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MOD.B.IMM | 0x250 | MOD.B.REG | 0x251 |
| MOD.B.DIR | 0x252 | MOD.B.IDX | 0x253 |
| MOD.B.STK | 0x254 | MOD.W.IMM | 0x255 |
| MOD.W.REG | 0x256 | MOD.W.DIR | 0x257 |
| MOD.W.IDX | 0x258 | MOD.W.STK | 0x259 |
| MOD.D.IMM | 0x25A | MOD.D.REG | 0x25B |
| MOD.D.DIR | 0x25C | MOD.D.IDX | 0x25D |
| MOD.D.STK | 0x25E | MOD.Q.IMM | 0x25F |
| MOD.Q.REG | 0x260 | MOD.Q.DIR | 0x261 |
| MOD.Q.IDX | 0x262 | MOD.Q.STK | 0x263 |

#### 2.2.6 INC — Increment

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| INC.B.IMM | 0x264 | INC.B.REG | 0x265 |
| INC.B.DIR | 0x266 | INC.B.IDX | 0x267 |
| INC.B.STK | 0x268 | INC.W.IMM | 0x269 |
| INC.W.REG | 0x26A | INC.W.DIR | 0x26B |
| INC.W.IDX | 0x26C | INC.W.STK | 0x26D |
| INC.D.IMM | 0x26E | INC.D.REG | 0x26F |
| INC.D.DIR | 0x270 | INC.D.IDX | 0x271 |
| INC.D.STK | 0x272 | INC.Q.IMM | 0x273 |
| INC.Q.REG | 0x274 | INC.Q.DIR | 0x275 |
| INC.Q.IDX | 0x276 | INC.Q.STK | 0x277 |

#### 2.2.7 DEC — Decrement

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| DEC.B.IMM | 0x278 | DEC.B.REG | 0x279 |
| DEC.B.DIR | 0x27A | DEC.B.IDX | 0x27B |
| DEC.B.STK | 0x27C | DEC.W.IMM | 0x27D |
| DEC.W.REG | 0x27E | DEC.W.DIR | 0x27F |
| DEC.W.IDX | 0x280 | DEC.W.STK | 0x281 |
| DEC.D.IMM | 0x282 | DEC.D.REG | 0x283 |
| DEC.D.DIR | 0x284 | DEC.D.IDX | 0x285 |
| DEC.D.STK | 0x286 | DEC.Q.IMM | 0x287 |
| DEC.Q.REG | 0x288 | DEC.Q.DIR | 0x289 |
| DEC.Q.IDX | 0x28A | DEC.Q.STK | 0x28B |

#### 2.2.8 ABS — Absolute Value

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ABS.B.IMM | 0x28C | ABS.B.REG | 0x28D |
| ABS.B.DIR | 0x28E | ABS.B.IDX | 0x28F |
| ABS.B.STK | 0x290 | ABS.W.IMM | 0x291 |
| ABS.W.REG | 0x292 | ABS.W.DIR | 0x293 |
| ABS.W.IDX | 0x294 | ABS.W.STK | 0x295 |
| ABS.D.IMM | 0x296 | ABS.D.REG | 0x297 |
| ABS.D.DIR | 0x298 | ABS.D.IDX | 0x299 |
| ABS.D.STK | 0x29A | ABS.Q.IMM | 0x29B |
| ABS.Q.REG | 0x29C | ABS.Q.DIR | 0x29D |
| ABS.Q.IDX | 0x29E | ABS.Q.STK | 0x29F |

#### 2.2.9 NEG — Negate

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| NEG.B.IMM | 0x2A0 | NEG.B.REG | 0x2A1 |
| NEG.B.DIR | 0x2A2 | NEG.B.IDX | 0x2A3 |
| NEG.B.STK | 0x2A4 | NEG.W.IMM | 0x2A5 |
| NEG.W.REG | 0x2A6 | NEG.W.DIR | 0x2A7 |
| NEG.W.IDX | 0x2A8 | NEG.W.STK | 0x2A9 |
| NEG.D.IMM | 0x2AA | NEG.D.REG | 0x2AB |
| NEG.D.DIR | 0x2AC | NEG.D.IDX | 0x2AD |
| NEG.D.STK | 0x2AE | NEG.Q.IMM | 0x2AF |
| NEG.Q.REG | 0x2B0 | NEG.Q.DIR | 0x2B1 |
| NEG.Q.IDX | 0x2B2 | NEG.Q.STK | 0x2B3 |

#### 2.2.10 MIN — Minimum

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MIN.B.IMM | 0x2B4 | MIN.B.REG | 0x2B5 |
| MIN.B.DIR | 0x2B6 | MIN.B.IDX | 0x2B7 |
| MIN.B.STK | 0x2B8 | MIN.W.IMM | 0x2B9 |
| MIN.W.REG | 0x2BA | MIN.W.DIR | 0x2BB |
| MIN.W.IDX | 0x2BC | MIN.W.STK | 0x2BD |
| MIN.D.IMM | 0x2BE | MIN.D.REG | 0x2BF |
| MIN.D.DIR | 0x2C0 | MIN.D.IDX | 0x2C1 |
| MIN.D.STK | 0x2C2 | MIN.Q.IMM | 0x2C3 |
| MIN.Q.REG | 0x2C4 | MIN.Q.DIR | 0x2C5 |
| MIN.Q.IDX | 0x2C6 | MIN.Q.STK | 0x2C7 |

#### 2.2.11 MAX — Maximum

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MAX.B.IMM | 0x2C8 | MAX.B.REG | 0x2C9 |
| MAX.B.DIR | 0x2CA | MAX.B.IDX | 0x2CB |
| MAX.B.STK | 0x2CC | MAX.W.IMM | 0x2CD |
| MAX.W.REG | 0x2CE | MAX.W.DIR | 0x2CF |
| MAX.W.IDX | 0x2D0 | MAX.W.STK | 0x2D1 |
| MAX.D.IMM | 0x2D2 | MAX.D.REG | 0x2D3 |
| MAX.D.DIR | 0x2D4 | MAX.D.IDX | 0x2D5 |
| MAX.D.STK | 0x2D6 | MAX.Q.IMM | 0x2D7 |
| MAX.Q.REG | 0x2D8 | MAX.Q.DIR | 0x2D9 |
| MAX.Q.IDX | 0x2DA | MAX.Q.STK | 0x2DB |

#### 2.2.12 AVG — Average

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| AVG.B.IMM | 0x2DC | AVG.B.REG | 0x2DD |
| AVG.B.DIR | 0x2DE | AVG.B.IDX | 0x2DF |
| AVG.B.STK | 0x2E0 | AVG.W.IMM | 0x2E1 |
| AVG.W.REG | 0x2E2 | AVG.W.DIR | 0x2E3 |
| AVG.W.IDX | 0x2E4 | AVG.W.STK | 0x2E5 |
| AVG.D.IMM | 0x2E6 | AVG.D.REG | 0x2E7 |
| AVG.D.DIR | 0x2E8 | AVG.D.IDX | 0x2E9 |
| AVG.D.STK | 0x2EA | AVG.Q.IMM | 0x2EB |
| AVG.Q.REG | 0x2EC | AVG.Q.DIR | 0x2ED |
| AVG.Q.IDX | 0x2EE | AVG.Q.STK | 0x2EF |

#### 2.2.13 MULH — Multiply High

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MULH.B.IMM | 0x2F0 | MULH.B.REG | 0x2F1 |
| MULH.B.DIR | 0x2F2 | MULH.B.IDX | 0x2F3 |
| MULH.B.STK | 0x2F4 | MULH.W.IMM | 0x2F5 |
| MULH.W.REG | 0x2F6 | MULH.W.DIR | 0x2F7 |
| MULH.W.IDX | 0x2F8 | MULH.W.STK | 0x2F9 |
| MULH.D.IMM | 0x2FA | MULH.D.REG | 0x2FB |
| MULH.D.DIR | 0x2FC | MULH.D.IDX | 0x2FD |
| MULH.D.STK | 0x2FE | MULH.Q.IMM | 0x2FF |
| MULH.Q.REG | 0x300 | MULH.Q.DIR | 0x301 |
| MULH.Q.IDX | 0x302 | MULH.Q.STK | 0x303 |

#### 2.2.14 DIVH — Divide High / Extended Divide

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| DIVH.B.IMM | 0x304 | DIVH.B.REG | 0x305 |
| DIVH.B.DIR | 0x306 | DIVH.B.IDX | 0x307 |
| DIVH.B.STK | 0x308 | DIVH.W.IMM | 0x309 |
| DIVH.W.REG | 0x30A | DIVH.W.DIR | 0x30B |
| DIVH.W.IDX | 0x30C | DIVH.W.STK | 0x30D |
| DIVH.D.IMM | 0x30E | DIVH.D.REG | 0x30F |
| DIVH.D.DIR | 0x310 | DIVH.D.IDX | 0x311 |
| DIVH.D.STK | 0x312 | DIVH.Q.IMM | 0x313 |
| DIVH.Q.REG | 0x314 | DIVH.Q.DIR | 0x315 |
| DIVH.Q.IDX | 0x316 | DIVH.Q.STK | 0x317 |

#### 2.2.15 MADD — Multiply-Add

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MADD.B.IMM | 0x318 | MADD.B.REG | 0x319 |
| MADD.B.DIR | 0x31A | MADD.B.IDX | 0x31B |
| MADD.B.STK | 0x31C | MADD.W.IMM | 0x31D |
| MADD.W.REG | 0x31E | MADD.W.DIR | 0x31F |
| MADD.W.IDX | 0x320 | MADD.W.STK | 0x321 |
| MADD.D.IMM | 0x322 | MADD.D.REG | 0x323 |
| MADD.D.DIR | 0x324 | MADD.D.IDX | 0x325 |
| MADD.D.STK | 0x326 | MADD.Q.IMM | 0x327 |
| MADD.Q.REG | 0x328 | MADD.Q.DIR | 0x329 |
| MADD.Q.IDX | 0x32A | MADD.Q.STK | 0x32B |

#### 2.2.16 MSUB — Multiply-Subtract

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| MSUB.B.IMM | 0x32C | MSUB.B.REG | 0x32D |
| MSUB.B.DIR | 0x32E | MSUB.B.IDX | 0x32F |
| MSUB.B.STK | 0x330 | MSUB.W.IMM | 0x331 |
| MSUB.W.REG | 0x332 | MSUB.W.DIR | 0x333 |
| MSUB.W.IDX | 0x334 | MSUB.W.STK | 0x335 |
| MSUB.D.IMM | 0x336 | MSUB.D.REG | 0x337 |
| MSUB.D.DIR | 0x338 | MSUB.D.IDX | 0x339 |
| MSUB.D.STK | 0x33A | MSUB.Q.IMM | 0x33B |
| MSUB.Q.REG | 0x33C | MSUB.Q.DIR | 0x33D |
| MSUB.Q.IDX | 0x33E | MSUB.Q.STK | 0x33F |

#### 2.2.17 SAD — Sum of Absolute Differences

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SAD.B.IMM | 0x340 | SAD.B.REG | 0x341 |
| SAD.B.DIR | 0x342 | SAD.B.IDX | 0x343 |
| SAD.B.STK | 0x344 | SAD.W.IMM | 0x345 |
| SAD.W.REG | 0x346 | SAD.W.DIR | 0x347 |
| SAD.W.IDX | 0x348 | SAD.W.STK | 0x349 |
| SAD.D.IMM | 0x34A | SAD.D.REG | 0x34B |
| SAD.D.DIR | 0x34C | SAD.D.IDX | 0x34D |
| SAD.D.STK | 0x34E | SAD.Q.IMM | 0x34F |
| SAD.Q.REG | 0x350 | SAD.Q.DIR | 0x351 |
| SAD.Q.IDX | 0x352 | SAD.Q.STK | 0x353 |

#### 2.2.18 CMP — Compare

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| CMP.B.IMM | 0x354 | CMP.B.REG | 0x355 |
| CMP.B.DIR | 0x356 | CMP.B.IDX | 0x357 |
| CMP.B.STK | 0x358 | CMP.W.IMM | 0x359 |
| CMP.W.REG | 0x35A | CMP.W.DIR | 0x35B |
| CMP.W.IDX | 0x35C | CMP.W.STK | 0x35D |
| CMP.D.IMM | 0x35E | CMP.D.REG | 0x35F |
| CMP.D.DIR | 0x360 | CMP.D.IDX | 0x361 |
| CMP.D.STK | 0x362 | CMP.Q.IMM | 0x363 |
| CMP.Q.REG | 0x364 | CMP.Q.DIR | 0x365 |
| CMP.Q.IDX | 0x366 | CMP.Q.STK | 0x367 |

#### 2.2.19 TEST — Test / Bitwise AND without write-back

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| TEST.B.IMM | 0x368 | TEST.B.REG | 0x369 |
| TEST.B.DIR | 0x36A | TEST.B.IDX | 0x36B |
| TEST.B.STK | 0x36C | TEST.W.IMM | 0x36D |
| TEST.W.REG | 0x36E | TEST.W.DIR | 0x36F |
| TEST.W.IDX | 0x370 | TEST.W.STK | 0x371 |
| TEST.D.IMM | 0x372 | TEST.D.REG | 0x373 |
| TEST.D.DIR | 0x374 | TEST.D.IDX | 0x375 |
| TEST.D.STK | 0x376 | TEST.Q.IMM | 0x377 |
| TEST.Q.REG | 0x378 | TEST.Q.DIR | 0x379 |
| TEST.Q.IDX | 0x37A | TEST.Q.STK | 0x37B |

#### 2.2.20 SEXT — Sign Extend

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SEXT.B.IMM | 0x37C | SEXT.B.REG | 0x37D |
| SEXT.B.DIR | 0x37E | SEXT.B.IDX | 0x37F |
| SEXT.B.STK | 0x380 | SEXT.W.IMM | 0x381 |
| SEXT.W.REG | 0x382 | SEXT.W.DIR | 0x383 |
| SEXT.W.IDX | 0x384 | SEXT.W.STK | 0x385 |
| SEXT.D.IMM | 0x386 | SEXT.D.REG | 0x387 |
| SEXT.D.DIR | 0x388 | SEXT.D.IDX | 0x389 |
| SEXT.D.STK | 0x38A | SEXT.Q.IMM | 0x38B |
| SEXT.Q.REG | 0x38C | SEXT.Q.DIR | 0x38D |
| SEXT.Q.IDX | 0x38E | SEXT.Q.STK | 0x38F |

#### 2.2.21 ZEXT — Zero Extend

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ZEXT.B.IMM | 0x390 | ZEXT.B.REG | 0x391 |
| ZEXT.B.DIR | 0x392 | ZEXT.B.IDX | 0x393 |
| ZEXT.B.STK | 0x394 | ZEXT.W.IMM | 0x395 |
| ZEXT.W.REG | 0x396 | ZEXT.W.DIR | 0x397 |
| ZEXT.W.IDX | 0x398 | ZEXT.W.STK | 0x399 |
| ZEXT.D.IMM | 0x39A | ZEXT.D.REG | 0x39B |
| ZEXT.D.DIR | 0x39C | ZEXT.D.IDX | 0x39D |
| ZEXT.D.STK | 0x39E | ZEXT.Q.IMM | 0x39F |
| ZEXT.Q.REG | 0x3A0 | ZEXT.Q.DIR | 0x3A1 |
| ZEXT.Q.IDX | 0x3A2 | ZEXT.Q.STK | 0x3A3 |

#### 2.2.22 BSWAP — Byte Swap / Endian Conversion

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| BSWAP.B.IMM | 0x3A4 | BSWAP.B.REG | 0x3A5 |
| BSWAP.B.DIR | 0x3A6 | BSWAP.B.IDX | 0x3A7 |
| BSWAP.B.STK | 0x3A8 | BSWAP.W.IMM | 0x3A9 |
| BSWAP.W.REG | 0x3AA | BSWAP.W.DIR | 0x3AB |
| BSWAP.W.IDX | 0x3AC | BSWAP.W.STK | 0x3AD |
| BSWAP.D.IMM | 0x3AE | BSWAP.D.REG | 0x3AF |
| BSWAP.D.DIR | 0x3B0 | BSWAP.D.IDX | 0x3B1 |
| BSWAP.D.STK | 0x3B2 | BSWAP.Q.IMM | 0x3B3 |
| BSWAP.Q.REG | 0x3B4 | BSWAP.Q.DIR | 0x3B5 |
| BSWAP.Q.IDX | 0x3B6 | BSWAP.Q.STK | 0x3B7 |

#### 2.2.23 BITREV — Bit Reverse

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| BITREV.B.IMM | 0x3B8 | BITREV.B.REG | 0x3B9 |
| BITREV.B.DIR | 0x3BA | BITREV.B.IDX | 0x3BB |
| BITREV.B.STK | 0x3BC | BITREV.W.IMM | 0x3BD |
| BITREV.W.REG | 0x3BE | BITREV.W.DIR | 0x3BF |
| BITREV.W.IDX | 0x3C0 | BITREV.W.STK | 0x3C1 |
| BITREV.D.IMM | 0x3C2 | BITREV.D.REG | 0x3C3 |
| BITREV.D.DIR | 0x3C4 | BITREV.D.IDX | 0x3C5 |
| BITREV.D.STK | 0x3C6 | BITREV.Q.IMM | 0x3C7 |
| BITREV.Q.REG | 0x3C8 | BITREV.Q.DIR | 0x3C9 |
| BITREV.Q.IDX | 0x3CA | BITREV.Q.STK | 0x3CB |

#### 2.2.24 CLZ — Count Leading Zeros

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| CLZ.B.IMM | 0x3CC | CLZ.B.REG | 0x3CD |
| CLZ.B.DIR | 0x3CE | CLZ.B.IDX | 0x3CF |
| CLZ.B.STK | 0x3D0 | CLZ.W.IMM | 0x3D1 |
| CLZ.W.REG | 0x3D2 | CLZ.W.DIR | 0x3D3 |
| CLZ.W.IDX | 0x3D4 | CLZ.W.STK | 0x3D5 |
| CLZ.D.IMM | 0x3D6 | CLZ.D.REG | 0x3D7 |
| CLZ.D.DIR | 0x3D8 | CLZ.D.IDX | 0x3D9 |
| CLZ.D.STK | 0x3DA | CLZ.Q.IMM | 0x3DB |
| CLZ.Q.REG | 0x3DC | CLZ.Q.DIR | 0x3DD |
| CLZ.Q.IDX | 0x3DE | CLZ.Q.STK | 0x3DF |

#### 2.2.25 CTZ — Count Trailing Zeros

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| CTZ.B.IMM | 0x3E0 | CTZ.B.REG | 0x3E1 |
| CTZ.B.DIR | 0x3E2 | CTZ.B.IDX | 0x3E3 |
| CTZ.B.STK | 0x3E4 | CTZ.W.IMM | 0x3E5 |
| CTZ.W.REG | 0x3E6 | CTZ.W.DIR | 0x3E7 |
| CTZ.W.IDX | 0x3E8 | CTZ.W.STK | 0x3E9 |
| CTZ.D.IMM | 0x3EA | CTZ.D.REG | 0x3EB |
| CTZ.D.DIR | 0x3EC | CTZ.D.IDX | 0x3ED |
| CTZ.D.STK | 0x3EE | CTZ.Q.IMM | 0x3EF |
| CTZ.Q.REG | 0x3F0 | CTZ.Q.DIR | 0x3F1 |
| CTZ.Q.IDX | 0x3F2 | CTZ.Q.STK | 0x3F3 |

#### 2.2.26 POPCNT — Population Count

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| POPCNT.B.IMM | 0x3F4 | POPCNT.B.REG | 0x3F5 |
| POPCNT.B.DIR | 0x3F6 | POPCNT.B.IDX | 0x3F7 |
| POPCNT.B.STK | 0x3F8 | POPCNT.W.IMM | 0x3F9 |
| POPCNT.W.REG | 0x3FA | POPCNT.W.DIR | 0x3FB |
| POPCNT.W.IDX | 0x3FC | POPCNT.W.STK | 0x3FD |
| POPCNT.D.IMM | 0x3FE | POPCNT.D.REG | 0x3FF |
| POPCNT.D.DIR | 0x400 | POPCNT.D.IDX | 0x401 |
| POPCNT.D.STK | 0x402 | POPCNT.Q.IMM | 0x403 |
| POPCNT.Q.REG | 0x404 | POPCNT.Q.DIR | 0x405 |
| POPCNT.Q.IDX | 0x406 | POPCNT.Q.STK | 0x407 |

---

### 2.3 Logic Operation Instructions — Encoding Range 0x408–0x4F7

> **Note**: Each base instruction occupies 20 consecutive encodings (5 addressing modes × 4 integer types B/W/D/Q).
#### 2.3.1 AND — Bitwise AND

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| AND.B.IMM | 0x408 | AND.B.REG | 0x409 |
| AND.B.DIR | 0x40A | AND.B.IDX | 0x40B |
| AND.B.STK | 0x40C | AND.W.IMM | 0x40D |
| AND.W.REG | 0x40E | AND.W.DIR | 0x40F |
| AND.W.IDX | 0x410 | AND.W.STK | 0x411 |
| AND.D.IMM | 0x412 | AND.D.REG | 0x413 |
| AND.D.DIR | 0x414 | AND.D.IDX | 0x415 |
| AND.D.STK | 0x416 | AND.Q.IMM | 0x417 |
| AND.Q.REG | 0x418 | AND.Q.DIR | 0x419 |
| AND.Q.IDX | 0x41A | AND.Q.STK | 0x41B |

#### 2.3.2 OR — Bitwise OR

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| OR.B.IMM | 0x41C | OR.B.REG | 0x41D |
| OR.B.DIR | 0x41E | OR.B.IDX | 0x41F |
| OR.B.STK | 0x420 | OR.W.IMM | 0x421 |
| OR.W.REG | 0x422 | OR.W.DIR | 0x423 |
| OR.W.IDX | 0x424 | OR.W.STK | 0x425 |
| OR.D.IMM | 0x426 | OR.D.REG | 0x427 |
| OR.D.DIR | 0x428 | OR.D.IDX | 0x429 |
| OR.D.STK | 0x42A | OR.Q.IMM | 0x42B |
| OR.Q.REG | 0x42C | OR.Q.DIR | 0x42D |
| OR.Q.IDX | 0x42E | OR.Q.STK | 0x42F |

#### 2.3.3 XOR — Bitwise XOR

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| XOR.B.IMM | 0x430 | XOR.B.REG | 0x431 |
| XOR.B.DIR | 0x432 | XOR.B.IDX | 0x433 |
| XOR.B.STK | 0x434 | XOR.W.IMM | 0x435 |
| XOR.W.REG | 0x436 | XOR.W.DIR | 0x437 |
| XOR.W.IDX | 0x438 | XOR.W.STK | 0x439 |
| XOR.D.IMM | 0x43A | XOR.D.REG | 0x43B |
| XOR.D.DIR | 0x43C | XOR.D.IDX | 0x43D |
| XOR.D.STK | 0x43E | XOR.Q.IMM | 0x43F |
| XOR.Q.REG | 0x440 | XOR.Q.DIR | 0x441 |
| XOR.Q.IDX | 0x442 | XOR.Q.STK | 0x443 |

#### 2.3.4 NOT — Bitwise NOT

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| NOT.B.IMM | 0x444 | NOT.B.REG | 0x445 |
| NOT.B.DIR | 0x446 | NOT.B.IDX | 0x447 |
| NOT.B.STK | 0x448 | NOT.W.IMM | 0x449 |
| NOT.W.REG | 0x44A | NOT.W.DIR | 0x44B |
| NOT.W.IDX | 0x44C | NOT.W.STK | 0x44D |
| NOT.D.IMM | 0x44E | NOT.D.REG | 0x44F |
| NOT.D.DIR | 0x450 | NOT.D.IDX | 0x451 |
| NOT.D.STK | 0x452 | NOT.Q.IMM | 0x453 |
| NOT.Q.REG | 0x454 | NOT.Q.DIR | 0x455 |
| NOT.Q.IDX | 0x456 | NOT.Q.STK | 0x457 |

#### 2.3.5 SHL — Shift Left

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SHL.B.IMM | 0x458 | SHL.B.REG | 0x459 |
| SHL.B.DIR | 0x45A | SHL.B.IDX | 0x45B |
| SHL.B.STK | 0x45C | SHL.W.IMM | 0x45D |
| SHL.W.REG | 0x45E | SHL.W.DIR | 0x45F |
| SHL.W.IDX | 0x460 | SHL.W.STK | 0x461 |
| SHL.D.IMM | 0x462 | SHL.D.REG | 0x463 |
| SHL.D.DIR | 0x464 | SHL.D.IDX | 0x465 |
| SHL.D.STK | 0x466 | SHL.Q.IMM | 0x467 |
| SHL.Q.REG | 0x468 | SHL.Q.DIR | 0x469 |
| SHL.Q.IDX | 0x46A | SHL.Q.STK | 0x46B |

#### 2.3.6 SHR — Shift Right Logical

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SHR.B.IMM | 0x46C | SHR.B.REG | 0x46D |
| SHR.B.DIR | 0x46E | SHR.B.IDX | 0x46F |
| SHR.B.STK | 0x470 | SHR.W.IMM | 0x471 |
| SHR.W.REG | 0x472 | SHR.W.DIR | 0x473 |
| SHR.W.IDX | 0x474 | SHR.W.STK | 0x475 |
| SHR.D.IMM | 0x476 | SHR.D.REG | 0x477 |
| SHR.D.DIR | 0x478 | SHR.D.IDX | 0x479 |
| SHR.D.STK | 0x47A | SHR.Q.IMM | 0x47B |
| SHR.Q.REG | 0x47C | SHR.Q.DIR | 0x47D |
| SHR.Q.IDX | 0x47E | SHR.Q.STK | 0x47F |

#### 2.3.7 ROL — Rotate Left

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ROL.B.IMM | 0x480 | ROL.B.REG | 0x481 |
| ROL.B.DIR | 0x482 | ROL.B.IDX | 0x483 |
| ROL.B.STK | 0x484 | ROL.W.IMM | 0x485 |
| ROL.W.REG | 0x486 | ROL.W.DIR | 0x487 |
| ROL.W.IDX | 0x488 | ROL.W.STK | 0x489 |
| ROL.D.IMM | 0x48A | ROL.D.REG | 0x48B |
| ROL.D.DIR | 0x48C | ROL.D.IDX | 0x48D |
| ROL.D.STK | 0x48E | ROL.Q.IMM | 0x48F |
| ROL.Q.REG | 0x490 | ROL.Q.DIR | 0x491 |
| ROL.Q.IDX | 0x492 | ROL.Q.STK | 0x493 |

#### 2.3.8 ROR — Rotate Right

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ROR.B.IMM | 0x494 | ROR.B.REG | 0x495 |
| ROR.B.DIR | 0x496 | ROR.B.IDX | 0x497 |
| ROR.B.STK | 0x498 | ROR.W.IMM | 0x499 |
| ROR.W.REG | 0x49A | ROR.W.DIR | 0x49B |
| ROR.W.IDX | 0x49C | ROR.W.STK | 0x49D |
| ROR.D.IMM | 0x49E | ROR.D.REG | 0x49F |
| ROR.D.DIR | 0x4A0 | ROR.D.IDX | 0x4A1 |
| ROR.D.STK | 0x4A2 | ROR.Q.IMM | 0x4A3 |
| ROR.Q.REG | 0x4A4 | ROR.Q.DIR | 0x4A5 |
| ROR.Q.IDX | 0x4A6 | ROR.Q.STK | 0x4A7 |

#### 2.3.9 SHLD — Shift Left Double

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SHLD.B.IMM | 0x4A8 | SHLD.B.REG | 0x4A9 |
| SHLD.B.DIR | 0x4AA | SHLD.B.IDX | 0x4AB |
| SHLD.B.STK | 0x4AC | SHLD.W.IMM | 0x4AD |
| SHLD.W.REG | 0x4AE | SHLD.W.DIR | 0x4AF |
| SHLD.W.IDX | 0x4B0 | SHLD.W.STK | 0x4B1 |
| SHLD.D.IMM | 0x4B2 | SHLD.D.REG | 0x4B3 |
| SHLD.D.DIR | 0x4B4 | SHLD.D.IDX | 0x4B5 |
| SHLD.D.STK | 0x4B6 | SHLD.Q.IMM | 0x4B7 |
| SHLD.Q.REG | 0x4B8 | SHLD.Q.DIR | 0x4B9 |
| SHLD.Q.IDX | 0x4BA | SHLD.Q.STK | 0x4BB |

#### 2.3.10 SHRD — Shift Right Double

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| SHRD.B.IMM | 0x4BC | SHRD.B.REG | 0x4BD |
| SHRD.B.DIR | 0x4BE | SHRD.B.IDX | 0x4BF |
| SHRD.B.STK | 0x4C0 | SHRD.W.IMM | 0x4C1 |
| SHRD.W.REG | 0x4C2 | SHRD.W.DIR | 0x4C3 |
| SHRD.W.IDX | 0x4C4 | SHRD.W.STK | 0x4C5 |
| SHRD.D.IMM | 0x4C6 | SHRD.D.REG | 0x4C7 |
| SHRD.D.DIR | 0x4C8 | SHRD.D.IDX | 0x4C9 |
| SHRD.D.STK | 0x4CA | SHRD.Q.IMM | 0x4CB |
| SHRD.Q.REG | 0x4CC | SHRD.Q.DIR | 0x4CD |
| SHRD.Q.IDX | 0x4CE | SHRD.Q.STK | 0x4CF |

#### 2.3.11 BITEX — Bit Extract

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| BITEX.B.IMM | 0x4D0 | BITEX.B.REG | 0x4D1 |
| BITEX.B.DIR | 0x4D2 | BITEX.B.IDX | 0x4D3 |
| BITEX.B.STK | 0x4D4 | BITEX.W.IMM | 0x4D5 |
| BITEX.W.REG | 0x4D6 | BITEX.W.DIR | 0x4D7 |
| BITEX.W.IDX | 0x4D8 | BITEX.W.STK | 0x4D9 |
| BITEX.D.IMM | 0x4DA | BITEX.D.REG | 0x4DB |
| BITEX.D.DIR | 0x4DC | BITEX.D.IDX | 0x4DD |
| BITEX.D.STK | 0x4DE | BITEX.Q.IMM | 0x4DF |
| BITEX.Q.REG | 0x4E0 | BITEX.Q.DIR | 0x4E1 |
| BITEX.Q.IDX | 0x4E2 | BITEX.Q.STK | 0x4E3 |

#### 2.3.12 BITIN — Bit Insert

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| BITIN.B.IMM | 0x4E4 | BITIN.B.REG | 0x4E5 |
| BITIN.B.DIR | 0x4E6 | BITIN.B.IDX | 0x4E7 |
| BITIN.B.STK | 0x4E8 | BITIN.W.IMM | 0x4E9 |
| BITIN.W.REG | 0x4EA | BITIN.W.DIR | 0x4EB |
| BITIN.W.IDX | 0x4EC | BITIN.W.STK | 0x4ED |
| BITIN.D.IMM | 0x4EE | BITIN.D.REG | 0x4EF |
| BITIN.D.DIR | 0x4F0 | BITIN.D.IDX | 0x4F1 |
| BITIN.D.STK | 0x4F2 | BITIN.Q.IMM | 0x4F3 |
| BITIN.Q.REG | 0x4F4 | BITIN.Q.DIR | 0x4F5 |
| BITIN.Q.IDX | 0x4F6 | BITIN.Q.STK | 0x4F7 |

#### 2.3.13 Logic Operations Reserved

| Range | Description |
|-------|-------------|
| 0x4F8–0x4FF | Reserved |

---

### 2.4 Floating-Point Scalar Instructions — Encoding Range 0x500–0x62B

> **Note**: Each base instruction occupies 20 consecutive encodings (5 addressing modes × 4 float types F16/F32/F64/F128).
#### 2.4.1 FADD — Floating-Point Add

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FADD.F16.IMM | 0x500 | FADD.F16.REG | 0x501 |
| FADD.F16.DIR | 0x502 | FADD.F16.IDX | 0x503 |
| FADD.F16.STK | 0x504 | FADD.F32.IMM | 0x505 |
| FADD.F32.REG | 0x506 | FADD.F32.DIR | 0x507 |
| FADD.F32.IDX | 0x508 | FADD.F32.STK | 0x509 |
| FADD.F64.IMM | 0x50A | FADD.F64.REG | 0x50B |
| FADD.F64.DIR | 0x50C | FADD.F64.IDX | 0x50D |
| FADD.F64.STK | 0x50E | FADD.F128.IMM | 0x50F |
| FADD.F128.REG | 0x510 | FADD.F128.DIR | 0x511 |
| FADD.F128.IDX | 0x512 | FADD.F128.STK | 0x513 |

#### 2.4.2 FSUB — Floating-Point Subtract

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FSUB.F16.IMM | 0x514 | FSUB.F16.REG | 0x515 |
| FSUB.F16.DIR | 0x516 | FSUB.F16.IDX | 0x517 |
| FSUB.F16.STK | 0x518 | FSUB.F32.IMM | 0x519 |
| FSUB.F32.REG | 0x51A | FSUB.F32.DIR | 0x51B |
| FSUB.F32.IDX | 0x51C | FSUB.F32.STK | 0x51D |
| FSUB.F64.IMM | 0x51E | FSUB.F64.REG | 0x51F |
| FSUB.F64.DIR | 0x520 | FSUB.F64.IDX | 0x521 |
| FSUB.F64.STK | 0x522 | FSUB.F128.IMM | 0x523 |
| FSUB.F128.REG | 0x524 | FSUB.F128.DIR | 0x525 |
| FSUB.F128.IDX | 0x526 | FSUB.F128.STK | 0x527 |

#### 2.4.3 FMUL — Floating-Point Multiply

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FMUL.F16.IMM | 0x528 | FMUL.F16.REG | 0x529 |
| FMUL.F16.DIR | 0x52A | FMUL.F16.IDX | 0x52B |
| FMUL.F16.STK | 0x52C | FMUL.F32.IMM | 0x52D |
| FMUL.F32.REG | 0x52E | FMUL.F32.DIR | 0x52F |
| FMUL.F32.IDX | 0x530 | FMUL.F32.STK | 0x531 |
| FMUL.F64.IMM | 0x532 | FMUL.F64.REG | 0x533 |
| FMUL.F64.DIR | 0x534 | FMUL.F64.IDX | 0x535 |
| FMUL.F64.STK | 0x536 | FMUL.F128.IMM | 0x537 |
| FMUL.F128.REG | 0x538 | FMUL.F128.DIR | 0x539 |
| FMUL.F128.IDX | 0x53A | FMUL.F128.STK | 0x53B |

#### 2.4.4 FDIV — Floating-Point Divide

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FDIV.F16.IMM | 0x53C | FDIV.F16.REG | 0x53D |
| FDIV.F16.DIR | 0x53E | FDIV.F16.IDX | 0x53F |
| FDIV.F16.STK | 0x540 | FDIV.F32.IMM | 0x541 |
| FDIV.F32.REG | 0x542 | FDIV.F32.DIR | 0x543 |
| FDIV.F32.IDX | 0x544 | FDIV.F32.STK | 0x545 |
| FDIV.F64.IMM | 0x546 | FDIV.F64.REG | 0x547 |
| FDIV.F64.DIR | 0x548 | FDIV.F64.IDX | 0x549 |
| FDIV.F64.STK | 0x54A | FDIV.F128.IMM | 0x54B |
| FDIV.F128.REG | 0x54C | FDIV.F128.DIR | 0x54D |
| FDIV.F128.IDX | 0x54E | FDIV.F128.STK | 0x54F |

#### 2.4.5 FABS — Floating-Point Absolute Value

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FABS.F16.IMM | 0x550 | FABS.F16.REG | 0x551 |
| FABS.F16.DIR | 0x552 | FABS.F16.IDX | 0x553 |
| FABS.F16.STK | 0x554 | FABS.F32.IMM | 0x555 |
| FABS.F32.REG | 0x556 | FABS.F32.DIR | 0x557 |
| FABS.F32.IDX | 0x558 | FABS.F32.STK | 0x559 |
| FABS.F64.IMM | 0x55A | FABS.F64.REG | 0x55B |
| FABS.F64.DIR | 0x55C | FABS.F64.IDX | 0x55D |
| FABS.F64.STK | 0x55E | FABS.F128.IMM | 0x55F |
| FABS.F128.REG | 0x560 | FABS.F128.DIR | 0x561 |
| FABS.F128.IDX | 0x562 | FABS.F128.STK | 0x563 |

#### 2.4.6 FNEG — Floating-Point Negate

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FNEG.F16.IMM | 0x564 | FNEG.F16.REG | 0x565 |
| FNEG.F16.DIR | 0x566 | FNEG.F16.IDX | 0x567 |
| FNEG.F16.STK | 0x568 | FNEG.F32.IMM | 0x569 |
| FNEG.F32.REG | 0x56A | FNEG.F32.DIR | 0x56B |
| FNEG.F32.IDX | 0x56C | FNEG.F32.STK | 0x56D |
| FNEG.F64.IMM | 0x56E | FNEG.F64.REG | 0x56F |
| FNEG.F64.DIR | 0x570 | FNEG.F64.IDX | 0x571 |
| FNEG.F64.STK | 0x572 | FNEG.F128.IMM | 0x573 |
| FNEG.F128.REG | 0x574 | FNEG.F128.DIR | 0x575 |
| FNEG.F128.IDX | 0x576 | FNEG.F128.STK | 0x577 |

#### 2.4.7 FSQRT — Floating-Point Square Root

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FSQRT.F16.IMM | 0x578 | FSQRT.F16.REG | 0x579 |
| FSQRT.F16.DIR | 0x57A | FSQRT.F16.IDX | 0x57B |
| FSQRT.F16.STK | 0x57C | FSQRT.F32.IMM | 0x57D |
| FSQRT.F32.REG | 0x57E | FSQRT.F32.DIR | 0x57F |
| FSQRT.F32.IDX | 0x580 | FSQRT.F32.STK | 0x581 |
| FSQRT.F64.IMM | 0x582 | FSQRT.F64.REG | 0x583 |
| FSQRT.F64.DIR | 0x584 | FSQRT.F64.IDX | 0x585 |
| FSQRT.F64.STK | 0x586 | FSQRT.F128.IMM | 0x587 |
| FSQRT.F128.REG | 0x588 | FSQRT.F128.DIR | 0x589 |
| FSQRT.F128.IDX | 0x58A | FSQRT.F128.STK | 0x58B |

#### 2.4.8 FMIN — Floating-Point Minimum

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FMIN.F16.IMM | 0x58C | FMIN.F16.REG | 0x58D |
| FMIN.F16.DIR | 0x58E | FMIN.F16.IDX | 0x58F |
| FMIN.F16.STK | 0x590 | FMIN.F32.IMM | 0x591 |
| FMIN.F32.REG | 0x592 | FMIN.F32.DIR | 0x593 |
| FMIN.F32.IDX | 0x594 | FMIN.F32.STK | 0x595 |
| FMIN.F64.IMM | 0x596 | FMIN.F64.REG | 0x597 |
| FMIN.F64.DIR | 0x598 | FMIN.F64.IDX | 0x599 |
| FMIN.F64.STK | 0x59A | FMIN.F128.IMM | 0x59B |
| FMIN.F128.REG | 0x59C | FMIN.F128.DIR | 0x59D |
| FMIN.F128.IDX | 0x59E | FMIN.F128.STK | 0x59F |

#### 2.4.9 FMAX — Floating-Point Maximum

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FMAX.F16.IMM | 0x5A0 | FMAX.F16.REG | 0x5A1 |
| FMAX.F16.DIR | 0x5A2 | FMAX.F16.IDX | 0x5A3 |
| FMAX.F16.STK | 0x5A4 | FMAX.F32.IMM | 0x5A5 |
| FMAX.F32.REG | 0x5A6 | FMAX.F32.DIR | 0x5A7 |
| FMAX.F32.IDX | 0x5A8 | FMAX.F32.STK | 0x5A9 |
| FMAX.F64.IMM | 0x5AA | FMAX.F64.REG | 0x5AB |
| FMAX.F64.DIR | 0x5AC | FMAX.F64.IDX | 0x5AD |
| FMAX.F64.STK | 0x5AE | FMAX.F128.IMM | 0x5AF |
| FMAX.F128.REG | 0x5B0 | FMAX.F128.DIR | 0x5B1 |
| FMAX.F128.IDX | 0x5B2 | FMAX.F128.STK | 0x5B3 |

#### 2.4.10 FCVT — Floating-Point Convert

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FCVT.F16.IMM | 0x5B4 | FCVT.F16.REG | 0x5B5 |
| FCVT.F16.DIR | 0x5B6 | FCVT.F16.IDX | 0x5B7 |
| FCVT.F16.STK | 0x5B8 | FCVT.F32.IMM | 0x5B9 |
| FCVT.F32.REG | 0x5BA | FCVT.F32.DIR | 0x5BB |
| FCVT.F32.IDX | 0x5BC | FCVT.F32.STK | 0x5BD |
| FCVT.F64.IMM | 0x5BE | FCVT.F64.REG | 0x5BF |
| FCVT.F64.DIR | 0x5C0 | FCVT.F64.IDX | 0x5C1 |
| FCVT.F64.STK | 0x5C2 | FCVT.F128.IMM | 0x5C3 |
| FCVT.F128.REG | 0x5C4 | FCVT.F128.DIR | 0x5C5 |
| FCVT.F128.IDX | 0x5C6 | FCVT.F128.STK | 0x5C7 |

#### 2.4.11 FLOOR — Floating-Point Floor

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FLOOR.F16.IMM | 0x5C8 | FLOOR.F16.REG | 0x5C9 |
| FLOOR.F16.DIR | 0x5CA | FLOOR.F16.IDX | 0x5CB |
| FLOOR.F16.STK | 0x5CC | FLOOR.F32.IMM | 0x5CD |
| FLOOR.F32.REG | 0x5CE | FLOOR.F32.DIR | 0x5CF |
| FLOOR.F32.IDX | 0x5D0 | FLOOR.F32.STK | 0x5D1 |
| FLOOR.F64.IMM | 0x5D2 | FLOOR.F64.REG | 0x5D3 |
| FLOOR.F64.DIR | 0x5D4 | FLOOR.F64.IDX | 0x5D5 |
| FLOOR.F64.STK | 0x5D6 | FLOOR.F128.IMM | 0x5D7 |
| FLOOR.F128.REG | 0x5D8 | FLOOR.F128.DIR | 0x5D9 |
| FLOOR.F128.IDX | 0x5DA | FLOOR.F128.STK | 0x5DB |

#### 2.4.12 CEIL — Floating-Point Ceil

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| CEIL.F16.IMM | 0x5DC | CEIL.F16.REG | 0x5DD |
| CEIL.F16.DIR | 0x5DE | CEIL.F16.IDX | 0x5DF |
| CEIL.F16.STK | 0x5E0 | CEIL.F32.IMM | 0x5E1 |
| CEIL.F32.REG | 0x5E2 | CEIL.F32.DIR | 0x5E3 |
| CEIL.F32.IDX | 0x5E4 | CEIL.F32.STK | 0x5E5 |
| CEIL.F64.IMM | 0x5E6 | CEIL.F64.REG | 0x5E7 |
| CEIL.F64.DIR | 0x5E8 | CEIL.F64.IDX | 0x5E9 |
| CEIL.F64.STK | 0x5EA | CEIL.F128.IMM | 0x5EB |
| CEIL.F128.REG | 0x5EC | CEIL.F128.DIR | 0x5ED |
| CEIL.F128.IDX | 0x5EE | CEIL.F128.STK | 0x5EF |

#### 2.4.13 ROUND — Floating-Point Round

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| ROUND.F16.IMM | 0x5F0 | ROUND.F16.REG | 0x5F1 |
| ROUND.F16.DIR | 0x5F2 | ROUND.F16.IDX | 0x5F3 |
| ROUND.F16.STK | 0x5F4 | ROUND.F32.IMM | 0x5F5 |
| ROUND.F32.REG | 0x5F6 | ROUND.F32.DIR | 0x5F7 |
| ROUND.F32.IDX | 0x5F8 | ROUND.F32.STK | 0x5F9 |
| ROUND.F64.IMM | 0x5FA | ROUND.F64.REG | 0x5FB |
| ROUND.F64.DIR | 0x5FC | ROUND.F64.IDX | 0x5FD |
| ROUND.F64.STK | 0x5FE | ROUND.F128.IMM | 0x5FF |
| ROUND.F128.REG | 0x600 | ROUND.F128.DIR | 0x601 |
| ROUND.F128.IDX | 0x602 | ROUND.F128.STK | 0x603 |

#### 2.4.14 FMADD — Floating-Point Fused Multiply-Add

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FMADD.F16.IMM | 0x604 | FMADD.F16.REG | 0x605 |
| FMADD.F16.DIR | 0x606 | FMADD.F16.IDX | 0x607 |
| FMADD.F16.STK | 0x608 | FMADD.F32.IMM | 0x609 |
| FMADD.F32.REG | 0x60A | FMADD.F32.DIR | 0x60B |
| FMADD.F32.IDX | 0x60C | FMADD.F32.STK | 0x60D |
| FMADD.F64.IMM | 0x60E | FMADD.F64.REG | 0x60F |
| FMADD.F64.DIR | 0x610 | FMADD.F64.IDX | 0x611 |
| FMADD.F64.STK | 0x612 | FMADD.F128.IMM | 0x613 |
| FMADD.F128.REG | 0x614 | FMADD.F128.DIR | 0x615 |
| FMADD.F128.IDX | 0x616 | FMADD.F128.STK | 0x617 |

#### 2.4.15 FMSUB — Floating-Point Fused Multiply-Subtract

| Mnemonic | Encoding | Mnemonic | Encoding |
|----------|----------|----------|----------|
| FMSUB.F16.IMM | 0x618 | FMSUB.F16.REG | 0x619 |
| FMSUB.F16.DIR | 0x61A | FMSUB.F16.IDX | 0x61B |
| FMSUB.F16.STK | 0x61C | FMSUB.F32.IMM | 0x61D |
| FMSUB.F32.REG | 0x61E | FMSUB.F32.DIR | 0x61F |
| FMSUB.F32.IDX | 0x620 | FMSUB.F32.STK | 0x621 |
| FMSUB.F64.IMM | 0x622 | FMSUB.F64.REG | 0x623 |
| FMSUB.F64.DIR | 0x624 | FMSUB.F64.IDX | 0x625 |
| FMSUB.F64.STK | 0x626 | FMSUB.F128.IMM | 0x627 |
| FMSUB.F128.REG | 0x628 | FMSUB.F128.DIR | 0x629 |
| FMSUB.F128.IDX | 0x62A | FMSUB.F128.STK | 0x62B |

---

### 2.5 Program Control Instructions — Encoding Range 0x62C–0x6FF

> **Note**: Program control instructions use 5 addressing modes, continuing from 0x62C immediately after FMSUB.
#### 2.5.1 Multi-Addressing-Mode Program Control Instructions

| Instruction | IMM | REG | DIR | IDX | STK | Description |
|-------------|-----|-----|-----|-----|-----|-------------|
| **JMP** | 0x62C | 0x62D | 0x62E | 0x62F | 0x630 | Unconditional Jump |
| **CALL** | 0x631 | 0x632 | 0x633 | 0x634 | 0x635 | Call |
| **RET** | 0x636 | 0x637 | 0x638 | 0x639 | 0x63A | Return |
| **INT** | 0x63B | 0x63C | 0x63D | 0x63E | 0x63F | Software Interrupt |
| **IRET** | 0x640 | 0x641 | 0x642 | 0x643 | 0x644 | Interrupt Return |
| **JE** | 0x645 | 0x646 | 0x647 | 0x648 | 0x649 | Jump if Equal |
| **JNE** | 0x64A | 0x64B | 0x64C | 0x64D | 0x64E | Jump if Not Equal |
| **JG** | 0x64F | 0x650 | 0x651 | 0x652 | 0x653 | Jump if Greater (signed) |
| **JL** | 0x654 | 0x655 | 0x656 | 0x657 | 0x658 | Jump if Less (signed) |
| **JGE** | 0x659 | 0x65A | 0x65B | 0x65C | 0x65D | Jump if Greater or Equal (signed) |
| **JLE** | 0x65E | 0x65F | 0x660 | 0x661 | 0x662 | Jump if Less or Equal (signed) |
| **JA** | 0x663 | 0x664 | 0x665 | 0x666 | 0x667 | Jump if Above (unsigned) |
| **JB** | 0x668 | 0x669 | 0x66A | 0x66B | 0x66C | Jump if Below (unsigned) |
| **JAE** | 0x66D | 0x66E | 0x66F | 0x670 | 0x671 | Jump if Above or Equal (unsigned) |
| **JBE** | 0x672 | 0x673 | 0x674 | 0x675 | 0x676 | Jump if Below or Equal (unsigned) |
| **NOP** | 0x677 | 0x678 | 0x679 | 0x67A | 0x67B | No Operation |
| **HLT** | 0x67C | 0x67D | 0x67E | 0x67F | 0x680 | Halt |
| **CPUID** | 0x681 | 0x682 | 0x683 | 0x684 | 0x685 | CPU Identification |
| **SYSCALL** | 0x686 | 0x687 | 0x688 | 0x689 | 0x68A | System Call |
| **TRAP** | 0x68B | 0x68C | 0x68D | 0x68E | 0x68F | Trap |
| **ERET** | 0x690 | 0x691 | 0x692 | 0x693 | 0x694 | Exception Return |
| **WAIT** | 0x698 | 0x699 | 0x69A | 0x69B | 0x69C | Wait for Event |
| **YIELD** | 0x69D | 0x69E | 0x69F | 0x6A0 | 0x6A1 | Yield |
#### 2.5.2 Debug & System Control (Fixed Encoding)

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **BKPT** | 0x695 | Breakpoint |
| **TRACE** | 0x696 | Trace Enable |
| **WATCHDOG** | 0x697 | Watchdog Trigger |

#### 2.5.3 Program Control Reserved

| Range | Description |
|-------|-------------|
| 0x6A2–0x6FF | Reserved |

---

### 2.6 SIMD Vector Instructions — Encoding Range 0x700–0x7FF

> **Note**: Vector instruction data type suffixes are .I8, .I16, .I32, .F32, .F64, each occupying 1 encoding.

#### 2.6.1 Vector Arithmetic Instructions

| Instruction | Encoding Range | Element Types | Description |
|-------------|---------------|---------------|-------------|
| **VADD** | 0x700–0x704 | I8 / I16 / I32 / F32 / F64 | Vector Add |
| **VSUB** | 0x705–0x709 | I8 / I16 / I32 / F32 / F64 | Vector Subtract |
| **VMUL** | 0x70A–0x70E | I8 / I16 / I32 / F32 / F64 | Vector Multiply |
| **VDIV** | 0x70F–0x710 | F32 / F64 | Vector Divide (float only) |
| **VABS** | 0x711–0x715 | I8 / I16 / I32 / F32 / F64 | Vector Absolute |
| **VNEG** | 0x716–0x71A | I8 / I16 / I32 / F32 / F64 | Vector Negate |

#### 2.6.2 Vector Logic & Shift Instructions

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VAND** | 0x71B–0x71D | Vector Bitwise AND |
| **VOR** | 0x71E–0x720 | Vector Bitwise OR |
| **VXOR** | 0x721–0x723 | Vector Bitwise XOR |
| **VSHL** | 0x724–0x728 | Vector Shift Left |
| **VSHR** | 0x729–0x72E | Vector Shift Right |

#### 2.6.3 Vector Memory Operations

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VLOAD** | 0x72F–0x738 | Vector Load (contiguous/strided/indexed variants) |
| **VSTORE** | 0x739–0x73D | Vector Store |

#### 2.6.4 Vector Permutation & Reorganization

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VPERM** | 0x73E–0x741 | Vector Permute |
| **VEXTRACT** | 0x742–0x744 | Vector Extract |
| **VINSERT** | 0x745–0x747 | Vector Insert |
| **VSHUFFLE** | 0x748–0x74B | Vector Shuffle |
| **VBROADCAST** | 0x74C–0x74E | Vector Broadcast |
| **VGATHER** | 0x74F–0x750 | Vector Gather |
| **VSCATTER** | 0x751–0x752 | Vector Scatter |

#### 2.6.5 Vector Compare & Select

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VCMPEQ** | 0x753–0x757 | Vector Compare Equal |
| **VCMPGT** | 0x758–0x75E | Vector Compare Greater Than |
| **VCMPLT** | 0x75F–0x764 | Vector Compare Less Than |
| **VMIN** | 0x765–0x769 | Vector Minimum |
| **VMAX** | 0x76A–0x76F | Vector Maximum |

#### 2.6.6 Vector Fused Multiply-Add / Multiply-Subtract

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VFMADD** | 0x770–0x77E | Vector Fused Multiply-Add |
| **VFMSUB** | 0x77F–0x78E | Vector Fused Multiply-Subtract |

#### 2.6.7 Vector Approximate Reciprocal & Square Root

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **VRSQRT** | 0x78F–0x793 | Vector Reciprocal Square Root Approximation |
| **VRCP** | 0x794–0x798 | Vector Reciprocal Approximation |
| **VSQRT** | 0x799–0x79D | Vector Square Root |

#### 2.6.8 SIMD Vector Reserved

| Range | Description |
|-------|-------------|
| 0x79E–0x7BF | Reserved |

---

### 2.7 System & Privileged Instructions — Encoding Range 0x7C0–0x9FF

#### 2.7.1 Terminal System Control Instructions (0x7C0–0x7CF)

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **SYS_EOI** | 0x7C0–0x7C4 | End of Interrupt |
| **SYS_HALT** | 0x7C5–0x7C9 | System Halt |
| **SYS_RESET** | 0x7CA–0x7CE | System Reset |
| **SYS_SHUTDOWN.STK** | 0x7CF | System Shutdown — **LAST standard instruction** |

#### 2.7.2 System Register Access

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **SYS_CR_RD** | 0x800–0x80F | Control Register Read |
| **SYS_CR_WR** | 0x810–0x81F | Control Register Write |
| **SYS_MSR_RD** | 0x820–0x82F | Model-Specific Register Read |
| **SYS_MSR_WR** | 0x830–0x83E | Model-Specific Register Write |

#### 2.7.3 Cryptographic Acceleration Instructions

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **AESENC** | 0x83F | AES Encrypt Round |
| **AESDEC** | 0x840 | AES Decrypt Round |
| **AESKEYGEN** | 0x841 | AES Key Generation |
| **SHA256H** | 0x842 | SHA-256 Hash Compression |
| **SHA256S** | 0x843 | SHA-256 Schedule |
| **RSAEXP** | 0x844 | RSA Modular Exponentiation |
| **RSAMOD** | 0x845 | RSA Modular Multiplication |
| **CRC32** | 0x846 | CRC32 Checksum |
| **RDRAND** | 0x847 | Hardware Random Number |
| **RDTSC** | 0x848 | Read Timestamp Counter |

#### 2.7.4 Virtualization Instructions

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **VMRUN** | 0x849 | VM Run |
| **VMEXIT** | 0x84A | VM Exit |
| **VMLAUNCH** | 0x84B | VM Launch |
| **VMRESUME** | 0x84C | VM Resume |
| **VMREAD** | 0x84D–0x856 | Read VMCS Field |
| **VMWRITE** | 0x857–0x85F | Write VMCS Field |

#### 2.7.5 Hypervisor Call

| Instruction | Encoding Range | Description |
|-------------|---------------|-------------|
| **SYS_HYP_CALL** | 0x860–0x86F | Hypervisor Call |

#### 2.7.6 Debug & Tracing

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **SYS_DEBUG_LOCK** | 0x870 | Debug Lock |
| **SYS_DEBUG_UNLOCK** | 0x871 | Debug Unlock |
| **SYS_TRACE_EN** | 0x872–0x876 | Trace Enable |
| **SYS_TRACE_DIS** | 0x877–0x87B | Trace Disable |

#### 2.7.7 Watchdog & Performance Monitoring

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| **SYS_WDT_EN** | 0x87C | Watchdog Enable |
| **SYS_WDT_KICK** | 0x87D | Watchdog Kick |
| **SYS_PERF_RD** | 0x87E–0x887 | Performance Counter Read |
| **SYS_PERF_RST** | 0x888–0x88F | Performance Counter Reset |

#### 2.7.8 Power, Clock & Interrupt Management

| Module | Encoding Range | Description |
|--------|---------------|-------------|
| **Power Management** | 0x890–0x89F | Sleep states, DVFS, power domain control |
| **Clock Management** | 0x8A0–0x8BF | PLL configuration, clock gating |
| **Interrupt Management** | 0x8C0–0x8FF | Interrupt controller config, priority, masking |

#### 2.7.9 Cache / TLB / Debug / Security

| Module | Encoding Range | Description |
|--------|---------------|-------------|
| **Cache Operations** | 0x900–0x93F | Cache invalidate, clean, flush, prefetch |
| **TLB Operations** | 0x940–0x97F | TLB invalidate, sync, ASID management |
| **Debug** | 0x980–0x9BF | Hardware breakpoints, watchpoints, JTAG control |
| **Security** | 0x9C0–0x9FF | Secure monitor call, TEE control |

---

## 3. Vendor Custom Micro-Op Zone

> **⚠️ VENDOR-CUSTOMIZABLE REGION — Encoding Range 0x000–0x0FF — May Be Freely Modified**
>
> The following is the **MISC-R recommended implementation**. Each vendor may freely adjust the instruction definitions, encodings, and semantics within this region according to their microarchitectural needs. Instructions in this region are typically atomic micro-ops, decomposed from macro-instruction decoding.

### 3.1 ALU Micro-Ops — Encoding Range 0x00–0x1F

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uNOP** | 0x00 | No Operation |
| **uADD** | 0x01 | Add |
| **uSUB** | 0x02 | Subtract |
| **uMUL** | 0x03 | Multiply |
| **uDIV** | 0x04 | Divide |
| **uREM** | 0x05 | Remainder |
| **uAND** | 0x06 | Bitwise AND |
| **uOR** | 0x07 | Bitwise OR |
| **uXOR** | 0x08 | Bitwise XOR |
| **uNOT** | 0x09 | Bitwise NOT |
| **uSHL** | 0x0A | Shift Left |
| **uSHR** | 0x0B | Shift Right Logical |
| **uSAR** | 0x0C | Shift Right Arithmetic |
| **uROL** | 0x0D | Rotate Left |
| **uROR** | 0x0E | Rotate Right |
| **uCMP** | 0x0F | Compare |
| **uMIN** | 0x10 | Signed Minimum |
| **uMAX** | 0x11 | Signed Maximum |
| **uMINU** | 0x12 | Unsigned Minimum |
| **uMAXU** | 0x13 | Unsigned Maximum |
| **uABS** | 0x14 | Absolute Value |
| **uNEG** | 0x15 | Negate |
| **uSEXT.B** | 0x16 | Sign Extend Byte |
| **uSEXT.W** | 0x17 | Sign Extend Word |
| **uZEXT.B** | 0x18 | Zero Extend Byte |
| **uZEXT.W** | 0x19 | Zero Extend Word |
| **uREV** | 0x1A | Bit Reverse |
| **uCLZ** | 0x1B | Count Leading Zeros |
| **uCTZ** | 0x1C | Count Trailing Zeros |
| **uPOPCNT** | 0x1D | Population Count |
| — | 0x1E–0x1F | Reserved |

### 3.2 Memory Micro-Ops — Encoding Range 0x20–0x2F

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uLDB** | 0x20 | Load Byte (sign-extend) |
| **uLDBU** | 0x21 | Load Byte Unsigned |
| **uLDH** | 0x22 | Load Halfword (sign-extend) |
| **uLDHU** | 0x23 | Load Halfword Unsigned |
| **uLDW** | 0x24 | Load Word |
| **uLDD** | 0x25 | Load Doubleword |
| **uSTB** | 0x26 | Store Byte |
| **uSTH** | 0x27 | Store Halfword |
| **uSTW** | 0x28 | Store Word |
| **uSTD** | 0x29 | Store Doubleword |
| **uLDEX** | 0x2A | Load Exclusive |
| **uSTEX** | 0x2B | Store Exclusive |
| **uFENCE** | 0x2C | Memory Fence |
| **uFLUSH** | 0x2D | Cache Line Flush |
| — | 0x2E–0x2F | Reserved |

### 3.3 Control Flow Micro-Ops — Encoding Range 0x30–0x3F

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uJMP** | 0x30 | Register Indirect Jump |
| **uJMPI** | 0x31 | Immediate Jump |
| **uBEQ** | 0x32 | Branch if Equal |
| **uBNE** | 0x33 | Branch if Not Equal |
| **uBLT** | 0x34 | Branch if Less Than (signed) |
| **uBGE** | 0x35 | Branch if Greater or Equal (signed) |
| **uBLTU** | 0x36 | Branch if Less Than (unsigned) |
| **uBGEU** | 0x37 | Branch if Greater or Equal (unsigned) |
| **uCALL** | 0x38 | Call |
| **uCALLI** | 0x39 | Call Immediate |
| **uRET** | 0x3A | Return |
| **uSYSCALL** | 0x3B | System Call |
| **uERET** | 0x3C | Exception Return |
| **uBREAK** | 0x3D | Breakpoint |
| — | 0x3E–0x3F | Reserved |

### 3.4 ALU Immediate Variants — Encoding Range 0x40–0x5F

| Range | Description |
|-------|-------------|
| 0x40–0x5F | Immediate-mode variants of ALU micro-ops (uADDI, uSUBI, uANDI, uORI, uXORI, etc.) — vendor-defined mapping |

### 3.5 Hardware Accelerator Micro-Ops — Encoding Range 0x60–0x7F

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uAESENC** | 0x60 | AES Encrypt Round |
| **uAESDEC** | 0x61 | AES Decrypt Round |
| **uAESKEYGEN** | 0x62 | AES Key Generation |
| **uSHA256R** | 0x63 | SHA-256 Compression Round |
| **uSHA256S** | 0x64 | SHA-256 Schedule |
| **uRSAEXP** | 0x65 | RSA Modular Exponentiation |
| **uRSAMOD** | 0x66 | RSA Modular Multiplication |
| **uCRC32** | 0x67 | CRC32 Checksum |
| **uRDRAND** | 0x68 | Hardware Random Number Generation |
| **uRDTSC** | 0x69 | Read Timestamp Counter |
| **uFMADD** | 0x6A | FP Fused Multiply-Add |
| **uFMSUB** | 0x6B | FP Fused Multiply-Subtract |
| **uDSPMAC** | 0x6C | DSP Multiply-Accumulate |
| **uDSPMUL** | 0x6D | DSP Multiply |
| **uDSPADD** | 0x6E | DSP Add |
| **uDSPSUB** | 0x6F | DSP Subtract |
| — | 0x70–0x7F | Reserved |

### 3.6 Vector Micro-Ops — Encoding Range 0x80–0xBF

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uVADD** | 0x80 | Vector Add |
| **uVSUB** | 0x81 | Vector Subtract |
| **uVMUL** | 0x82 | Vector Multiply |
| **uVDIV** | 0x83 | Vector Divide |
| **uVAND** | 0x84 | Vector Bitwise AND |
| **uVOR** | 0x85 | Vector Bitwise OR |
| **uVXOR** | 0x86 | Vector Bitwise XOR |
| **uVSHL** | 0x87 | Vector Shift Left |
| **uVSHR** | 0x88 | Vector Shift Right |
| **uVLD** | 0x89 | Vector Load |
| **uVST** | 0x8A | Vector Store |
| **uVPERM** | 0x8B | Vector Permute |
| **uVEXTRACT** | 0x8C | Vector Extract |
| **uVINSERT** | 0x8D | Vector Insert |
| **uVSHUFFLE** | 0x8E | Vector Shuffle |
| **uVBROADCAST** | 0x8F | Vector Broadcast |
| **uVGATHER** | 0x90 | Vector Gather |
| **uVSCATTER** | 0x91 | Vector Scatter |
| **uVCMPEQ** | 0x92 | Vector Compare Equal |
| **uVCMPGT** | 0x93 | Vector Compare Greater Than |
| **uVCMPLT** | 0x94 | Vector Compare Less Than |
| **uVMIN** | 0x95 | Vector Minimum |
| **uVMAX** | 0x96 | Vector Maximum |
| **uVFMADD** | 0x97 | Vector Fused Multiply-Add |
| **uVFMSUB** | 0x98 | Vector Fused Multiply-Subtract |
| **uVRSQRT** | 0x99 | Vector Reciprocal Square Root Approx. |
| **uVRCP** | 0x9A | Vector Reciprocal Approx. |
| **uVSQRT** | 0x9B | Vector Square Root |
| — | 0x9C–0xBF | Reserved |

### 3.7 System Micro-Ops — Encoding Range 0xC0–0xDF

| Mnemonic | Encoding | Description |
|----------|----------|-------------|
| **uFENCE.I** | 0xC0 | Instruction Fence / I-cache sync |
| **uDSB** | 0xC1 | Data Synchronization Barrier |
| **uDMB** | 0xC2 | Data Memory Barrier |
| **uISB** | 0xC3 | Instruction Synchronization Barrier |
| **uWFI** | 0xC4 | Wait For Interrupt |
| **uWFE** | 0xC5 | Wait For Event |
| **uSEV** | 0xC6 | Send Event |
| **uSEVL** | 0xC7 | Send Event Local |
| **uYIELD** | 0xC8 | Yield |
| **uPREFETCH** | 0xC9 | Prefetch |
| **uCACHE.INV** | 0xCA | Cache Invalidate |
| **uCACHE.CLEAN** | 0xCB | Cache Clean |
| **uCACHE.FLUSH** | 0xCC | Cache Flush |
| **uTLBI** | 0xCD | TLB Invalidate |
| **uTLBSYNC** | 0xCE | TLB Sync |
| **uSLEEP** | 0xCF | Sleep |
| — | 0xD0–0xDF | Reserved |

### 3.8 Vendor Fully Custom — Encoding Range 0xE0–0xFF

| Range | Description |
|-------|-------------|
| 0xE0–0xFF | Fully vendor-customizable. May be used for custom accelerators, extension instructions, debug/diagnostic micro-ops, etc. The MISC-R specification imposes no restrictions on this region. |

---

**（英文版结束 / End of English Version）**

---

> **文档版本**: MISC-2000 ISA v1.0
> **最后更新**: 2026-06-13
> **标准指令总数**: 1744 (0x100–0x7CF)
> **厂商自定义指令数**: 256 (0x000–0x0FF)
