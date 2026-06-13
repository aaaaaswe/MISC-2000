# Checklist

- [x] 项目目录结构完整（doc/、rtl/、sim/、tools/、sw/、.gitignore）
- [x] rtl/ 子目录完整（core/、include/、top/）
- [x] README.md 包含中英双语版本，覆盖项目简介、架构特点、快速开始、目录结构、许可证
- [x] doc/architecture.md 存在且为中英双语，描述 CISC+RISC 混合架构、双发射乱序、ROB、寻址模式、数据类型
- [x] doc/isa.md 存在且为中英双语，完整列出所有指令，明确区分标准指令集和厂商自定义区
- [x] 指令译码器 (decoder.sv) 存在且正确实现操作码到控制信号的映射
- [x] 厂商自定义区 (0x000–0x0FF) 在译码器中正确透传
- [x] ALU 模块 (alu.sv) 支持整数算术、逻辑运算、移位、位操作，支持 B/W/D/Q 数据宽度
- [x] 寄存器文件 (regfile.sv) 包含 32 个 64 位寄存器，双读单写，支持子字访问
- [x] 流水线控制模块 (pipeline_ctrl.sv) 实现五级流水控制
- [x] 仿真 Makefile 存在且可编译运行
- [x] 基础测试用例存在（test_alu, test_decoder, test_regfile）
- [x] 所有源码文件头包含 Apache 2.0 许可证声明
- [x] 标准指令集 (0x100–0x7CF) 未被修改
- [x] 所有文档均为中英双语