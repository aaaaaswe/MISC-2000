# MISC-2000 · 微指令集复杂计算机架构

> **CISC 为表，RISC 为里 · CISC Outside, RISC Inside**

---
注意本项目已停更

<p align="center">
  <strong>中文</strong> &nbsp;|&nbsp; <a href="#english">English</a>
</p>

---

## 目录 / Table of Contents

- [1. 项目简介 / Project Overview](#1-项目简介--project-overview)
- [2. 架构概览 / Architecture Overview](#2-架构概览--architecture-overview)
- [3. 核心特性 / Key Features](#3-核心特性--key-features)
- [4. 快速开始 / Quick Start](#4-快速开始--quick-start)
- [5. 目录结构 / Directory Structure](#5-目录结构--directory-structure)
- [6. 许可证 / License](#6-许可证--license)
- [7. 贡献指南 / Contributing Guidelines](#7-贡献指南--contributing-guidelines)

---

## 1. 项目简介 / Project Overview

### 中文

**MISC-2000** 是一款采用「CISC 外壳 + RISC 内核」混合架构的开源处理器项目，共支持 **2000 条指令**。项目以 Apache 2.0 协议开放，旨在为学术界与工业界提供一个可自由研究、扩展与定制的高性能处理器参考实现。

- **项目名称**：MISC-2000（Micro Instruction Set Computer — 2000）
- **标签**：CISC 为表，RISC 为里 —— 兼具复杂指令的密度优势与精简指令的执行效率
- **许可协议**：Apache 2.0

### English

**MISC-2000** is an open-source processor project built on a **"CISC outside, RISC inside"** hybrid architecture, supporting a total of **2,000 instructions**. Released under the Apache 2.0 license, it aims to provide a high-performance processor reference implementation freely available for academic research, industrial customization, and architectural exploration.

- **Project Name**: MISC-2000 (Micro Instruction Set Computer — 2000)
- **Tagline**: CISC Outside, RISC Inside — combining the density of complex instructions with the execution efficiency of reduced instructions
- **License**: Apache 2.0

---

## 2. 架构概览 / Architecture Overview

### 中文

MISC-2000 在指令层面采用**双层架构**设计：

**CISC 宏指令层（对外）**  
对外呈现一套功能丰富的 CISC 宏指令集，单条宏指令可编码复杂的操作语义，有效降低程序代码体积，提升指令缓存利用率。

**RISC 微操作层（对内）**  
宏指令在前端被译码为一条或多条 RISC 风格的微操作（μOP），由后端**双发射乱序执行引擎**处理。核心包含一个 32 项的 Reorder Buffer（ROB），支持寄存器重命名、推测执行与精确异常。

```
                        ┌──────────────────────────┐
    程序 / Program  ──▶ │   CISC 宏指令前端           │
                        │   (Macro-Instruction Fetch) │
                        └────────────┬─────────────┘
                                     │ 译码 / Decode
                                     ▼
                        ┌──────────────────────────┐
                        │   RISC 微操作后端           │
                        │   · Dual-Issue OoO        │
                        │   · 32-Entry ROB          │
                        │   · Register Renaming     │
                        └──────────────────────────┘
```

**指令空间分配**

| 地址范围 / Range   | 数量 / Count | 类别 / Category                                    | 可修改 / Modifiable |
|--------------------|--------------|----------------------------------------------------|---------------------|
| `0x000` – `0x0FF`  | 256          | 厂商可定制微操作区 (MISC-R) / Vendor Micro-Op Zone | ✅ 是 / Yes         |
| `0x100` – `0x7CF`  | 1,744        | 标准 CISC 宏指令集 / Standard Macro-Instructions   | ❌ 否 / No          |

- **MISC-R 区 (`0x000–0x0FF`)**：共 256 个操作码位，厂商可自由修改、扩展或替换其中的微操作实现，用于领域加速、自定义指令融合等场景。
- **标准指令区 (`0x100–0x7CF`)**：共 1,744 条 CISC 宏指令，强制开源且不可修改，构成 MISC-2000 的公共基础指令集。

### English

MISC-2000 adopts a **two-layer instruction architecture**:

**CISC Macro-Instruction Layer (external)**  
Exposes a feature-rich CISC macro-instruction set to software. A single macro-instruction can encode complex operation semantics, effectively reducing code footprint and improving instruction cache utilization.

**RISC Micro-Op Layer (internal)**  
Macro-instructions are decoded at the front-end into one or more RISC-style micro-operations (μOPs), executed by a **dual-issue out-of-order execution engine**. The core features a 32-entry Reorder Buffer (ROB), supporting register renaming, speculative execution, and precise exceptions.

```
                        ┌──────────────────────────┐
     Program ────────▶  │   CISC Macro-Inst Front-End │
                        │   (Macro-Instruction Fetch) │
                        └────────────┬─────────────┘
                                     │ Decode
                                     ▼
                        ┌──────────────────────────┐
                        │   RISC Micro-Op Back-End   │
                        │   · Dual-Issue OoO        │
                        │   · 32-Entry ROB          │
                        │   · Register Renaming     │
                        └──────────────────────────┘
```

**Instruction Space Layout**

| Address Range      | Count  | Category                                            | Modifiable  |
|--------------------|--------|------------------------------------------------------|-------------|
| `0x000` – `0x0FF`  | 256    | Vendor-Customizable Micro-Op Zone (MISC-R)           | ✅ Yes      |
| `0x100` – `0x7CF`  | 1,744  | Standard CISC Macro-Instruction Set (mandatory open) | ❌ No       |

- **MISC-R Zone (`0x000–0x0FF`)**：256 opcode slots freely available for vendor customization — domain-specific acceleration, custom instruction fusion, etc.
- **Standard Zone (`0x100–0x7CF`)**：1,744 mandatory open-source CISC macro-instructions forming the public baseline instruction set of MISC-2000.

---

## 3. 核心特性 / Key Features

### 中文

| 类别 / Category       | 特性 / Feature                                              |
|-----------------------|-------------------------------------------------------------|
| **指令集规模**        | 共 2000 条指令，操作码范围 `0x000–0x7CF`                   |
| **混合架构**          | CISC 宏指令外壳 + RISC 微操作内核                           |
| **乱序执行**          | 双发射、32 项 ROB、寄存器重命名                             |
| **MISC-R 扩展区**     | 256 个可定制微操作位 (`0x000–0x0FF`)，厂商自由修改         |
| **标准指令集**        | 1,744 条强制开源的 CISC 宏指令 (`0x100–0x7CF`)             |
| **寻址模式**          | 5 种：`.IMM`（立即数）、`.REG`（寄存器）、`.DIR`（直接内存）、`.IDX`（索引）、`.STK`（堆栈） |
| **整数数据类型**      | B (8-bit)、W (16-bit)、D (32-bit)、Q (64-bit)              |
| **浮点数据类型**      | F16、F32、F64、F128（IEEE 754 兼容）                       |
| **向量数据类型**      | I8、I16、I32、F32、F64 向量操作                            |
| **开源协议**          | Apache 2.0，适合学术研究与商业定制                          |

### English

| Category              | Feature                                                      |
|-----------------------|--------------------------------------------------------------|
| **ISA Size**          | 2,000 instructions total, opcode range `0x000–0x7CF`        |
| **Hybrid Architecture**| CISC macro-instruction shell + RISC micro-op core           |
| **OoO Execution**     | Dual-issue, 32-entry ROB, register renaming                  |
| **MISC-R Extension**  | 256 customizable micro-op slots (`0x000–0x0FF`)              |
| **Standard ISA**      | 1,744 mandatory open-source CISC macro-instructions (`0x100–0x7CF`) |
| **Addressing Modes**  | 5 modes: `.IMM` (immediate), `.REG` (register), `.DIR` (direct memory), `.IDX` (indexed), `.STK` (stack) |
| **Integer Types**     | B (8-bit), W (16-bit), D (32-bit), Q (64-bit)               |
| **Floating-Point**    | F16, F32, F64, F128 (IEEE 754 compliant)                    |
| **Vector Types**      | I8, I16, I32, F32, F64 vector operations                    |
| **License**           | Apache 2.0, suitable for academic and commercial use         |

---

## 4. 快速开始 / Quick Start

### 中文

#### 环境要求

- **操作系统**：Linux (Ubuntu 20.04+ / CentOS 8+) 或 macOS 12+
- **工具链**：GCC 11+ / Clang 14+
- **仿真器**：Verilator 5.0+ 或 ModelSim / Questa
- **构建工具**：CMake 3.20+, Make, Python 3.9+

#### 克隆仓库

```bash
git clone https://github.com/your-org/misc-2000.git
cd misc-2000
```

#### 构建与仿真

```bash
# 配置构建
cmake -B build -DCMAKE_BUILD_TYPE=Release

# 编译 RTL 仿真
cmake --build build --target sim

# 运行冒烟测试
cmake --build build --target test

# 运行 SPEC 基准测试（可选）
./scripts/run_benchmarks.sh
```

#### 自定义 MISC-R 指令

MISC-R 扩展区允许厂商自由修改。在 `src/misc-r/` 目录下编辑对应的微操作定义文件，重新编译即可：

```bash
# 编辑自定义微操作
vim src/misc-r/custom_uops.v

# 重新构建
cmake --build build --target sim
```

### English

#### Prerequisites

- **OS**: Linux (Ubuntu 20.04+ / CentOS 8+) or macOS 12+
- **Toolchain**: GCC 11+ / Clang 14+
- **Simulator**: Verilator 5.0+ or ModelSim / Questa
- **Build Tools**: CMake 3.20+, Make, Python 3.9+

#### Clone the Repository

```bash
git clone https://github.com/your-org/misc-2000.git
cd misc-2000
```

#### Build & Simulate

```bash
# Configure build
cmake -B build -DCMAKE_BUILD_TYPE=Release

# Compile RTL simulation
cmake --build build --target sim

# Run smoke tests
cmake --build build --target test

# Run SPEC benchmarks (optional)
./scripts/run_benchmarks.sh
```

#### Customize MISC-R Instructions

The MISC-R extension zone is freely customizable. Edit the micro-op definition files under `src/misc-r/` and rebuild:

```bash
# Edit custom micro-ops
vim src/misc-r/custom_uops.v

# Rebuild
cmake --build build --target sim
```

---

## 5. 目录结构 / Directory Structure

### 中文

```
misc-2000/
├── README.md                  # 项目说明文档（本文件）
├── LICENSE                    # Apache 2.0 许可证文件
├── CMakeLists.txt             # 顶层 CMake 构建配置
│
├── docs/                      # 文档目录
│   ├── arch/                  #   架构设计文档
│   │   ├── isa_manual_cn.pdf  #     指令集手册（中文）
│   │   └── isa_manual_en.pdf  #     指令集手册（英文）
│   └── microarch/             #   微架构文档
│       └── pipeline.pdf       #     流水线设计说明
│
├── src/                       # RTL 源码
│   ├── core/                  #   处理器核心 (双发射 OoO, ROB, 寄存器重命名)
│   ├── decode/                #   译码模块 (CISC → μOP 翻译)
│   ├── execute/               #   执行单元 (ALU, FPU, LSU)
│   ├── misc-r/                #   MISC-R 厂商可定制微操作区
│   └── memory/                #   存储子系统 (Cache, TLB, MMU)
│
├── test/                      # 测试目录
│   ├── unit/                  #   单元测试
│   ├── integration/           #   集成测试
│   └── benchmarks/            #   基准测试程序
│
├── scripts/                   # 辅助脚本
│   ├── run_benchmarks.sh      #   基准测试运行脚本
│   └── gen_isa_tables.py      #   指令编码表生成脚本
│
└── tools/                     # 工具链
    ├── assembler/             #   汇编器
    └── disassembler/          #   反汇编器
```

### English

```
misc-2000/
├── README.md                  # Project documentation (this file)
├── LICENSE                    # Apache 2.0 license file
├── CMakeLists.txt             # Top-level CMake build configuration
│
├── docs/                      # Documentation
│   ├── arch/                  #   Architecture design docs
│   │   ├── isa_manual_cn.pdf  #     ISA manual (Chinese)
│   │   └── isa_manual_en.pdf  #     ISA manual (English)
│   └── microarch/             #   Microarchitecture docs
│       └── pipeline.pdf       #     Pipeline design notes
│
├── src/                       # RTL source
│   ├── core/                  #   Processor core (dual-issue OoO, ROB, renaming)
│   ├── decode/                #   Decode module (CISC → μOP translation)
│   ├── execute/               #   Execution units (ALU, FPU, LSU)
│   ├── misc-r/                #   MISC-R vendor-customizable micro-op zone
│   └── memory/                #   Memory subsystem (Cache, TLB, MMU)
│
├── test/                      # Testing
│   ├── unit/                  #   Unit tests
│   ├── integration/           #   Integration tests
│   └── benchmarks/            #   Benchmark programs
│
├── scripts/                   # Helper scripts
│   ├── run_benchmarks.sh      #   Benchmark runner
│   └── gen_isa_tables.py      #   ISA encoding table generator
│
└── tools/                     # Toolchain
    ├── assembler/             #   Assembler
    └── disassembler/          #   Disassembler
```

---

## 6. 许可证 / License

### 中文

MISC-2000 项目整体采用 **Apache 2.0** 开源许可证。详细信息请参阅项目根目录下的 [LICENSE](./LICENSE) 文件。

核心条款摘要：

- ✅ 允许自由使用、修改、分发
- ✅ 允许用于商业项目与闭源衍生作品
- ✅ 提供专利授权（明示的专利权许可）
- ⚠️ 修改后的文件需标注变更说明
- ⚠️ 分发时须保留原始版权声明与许可证副本

### English

MISC-2000 is licensed under the **Apache License, Version 2.0**. See the [LICENSE](./LICENSE) file in the project root for the full legal text.

Key points summary:

- ✅ Free to use, modify, and distribute
- ✅ Commercial use and closed-source derivatives allowed
- ✅ Explicit patent grant included
- ⚠️ Modified files must state changes made
- ⚠️ Must retain original copyright notice and license copy upon distribution

---

## 7. 贡献指南 / Contributing Guidelines

### 中文

我们欢迎社区对 MISC-2000 做出贡献！请遵循以下流程：

1. **Fork 本仓库**并创建您的特性分支：
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **遵循编码规范**：
   - RTL 代码遵循项目内 `.vscode/` 和 `scripts/lint.sh` 中的 Verilog/SystemVerilog 编码风格
   - 提交信息格式：`[模块] 简要描述`（如 `[decode] 优化 ADD 指令译码延迟`）

3. **编写测试**：所有新增或修改的逻辑须附带单元测试，确保覆盖率不降低。

4. **通过 CI 检查**：
   ```bash
   cmake --build build --target lint    # 代码风格检查
   cmake --build build --target test    # 运行全部测试
   ```

5. **提交 Pull Request**：在 PR 描述中清晰说明变更动机、实现方式与测试结果。

**重要提醒**：标准指令区（`0x100–0x7CF`）为强制开源部分，不可修改其语义。新增指令应放入 MISC-R 区（`0x000–0x0FF`）。

### English

Contributions to MISC-2000 are welcome! Please follow the process below:

1. **Fork the repository** and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow coding conventions**:
   - RTL code should conform to the Verilog/SystemVerilog style defined in `.vscode/` and `scripts/lint.sh`
   - Commit message format: `[module] Brief description` (e.g., `[decode] Optimize ADD instruction decode latency`)

3. **Write tests**: All new or modified logic must include unit tests to ensure coverage does not regress.

4. **Pass CI checks**:
   ```bash
   cmake --build build --target lint    # Lint check
   cmake --build build --target test    # Run all tests
   ```

5. **Submit a Pull Request**: Clearly describe the motivation, implementation approach, and test results in the PR description.

**Important**: The standard instruction zone (`0x100–0x7CF`) is mandatory open-source — its semantics must not be modified. New instructions should be placed in the MISC-R zone (`0x000–0x0FF`).

---

<p align="center">
  <em>CISC 为表，RISC 为里 · CISC Outside, RISC Inside</em>
</p>