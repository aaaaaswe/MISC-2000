# Tasks

- [x] Task 1: 搭建项目目录结构
  - [x] 创建 doc/、rtl/、sim/、tools/、sw/ 子目录
  - [x] 创建 .gitignore 文件
  - [x] 创建 rtl/ 子目录：core/、include/、top/

- [x] Task 2: 完善 README.md（中英双语）
  - [x] 编写中文版项目简介、架构特点、快速开始、目录结构、许可证
  - [x] 编写英文版项目简介、架构特点、快速开始、目录结构、许可证

- [x] Task 3: 编写架构设计文档 doc/architecture.md（中英双语）
  - [x] 中文版：CISC+RISC 混合架构、双发射乱序、ROB、寻址模式、数据类型、数据通路、流水线
  - [x] 英文版：同上

- [x] Task 4: 编写指令集规范文档 doc/isa.md（中英双语）
  - [x] 中文版：指令集概述、编码规则、命名规则、数据传送类、整数算术类、逻辑运算类、浮点标量类、程序控制类、SIMD 向量类、系统与特权类、厂商自定义区
  - [x] 英文版：同上

- [x] Task 5: 实现指令译码器 (rtl/core/decoder.sv)
  - [x] 定义操作码到指令类别/数据类型/寻址模式的映射表
  - [x] 实现厂商自定义区透传逻辑
  - [x] 输出控制信号接口

- [x] Task 6: 实现 ALU 模块 (rtl/core/alu.sv)
  - [x] 实现整数的 ADD/SUB/MUL/DIV/MOD
  - [x] 实现逻辑运算 AND/OR/XOR/NOT
  - [x] 实现移位 SHL/SHR/ROL/ROR
  - [x] 实现位操作 CLZ/CTZ/POPCNT/BSWAP/BITREV
  - [x] 支持 B/W/D/Q 数据宽度选择

- [x] Task 7: 实现寄存器文件 (rtl/core/regfile.sv)
  - [x] 32 个 64 位通用寄存器
  - [x] 双读端口 + 单写端口
  - [x] 支持 B/W/D/Q 子字读写

- [x] Task 8: 实现基础流水线控制模块 (rtl/core/pipeline_ctrl.sv)
  - [x] 取指-译码-执行-访存-写回五级流水控制
  - [x] 流水线寄存器定义

- [x] Task 9: 创建仿真环境 (sim/)
  - [x] 创建 Makefile（编译 + 仿真 + 波形查看）
  - [x] 创建基础测试用例（test_alu, test_decoder, test_regfile）

- [x] Task 10: 验证与检查
  - [x] 运行仿真验证所有 RTL 模块
  - [x] 确认所有文档中英双语
  - [x] 确认 Apache 2.0 许可证声明完整
  - [x] 确认标准指令集未被修改

# Task Dependencies
- Task 2, 3, 4 可并行执行（纯文档，无依赖）
- Task 5, 6, 7 可并行执行（独立 RTL 模块）
- Task 8 依赖 Task 5, 6, 7（流水线需要各模块接口）
- Task 9 依赖 Task 5, 6, 7, 8（仿真需要完整 RTL）
- Task 10 依赖所有前置任务