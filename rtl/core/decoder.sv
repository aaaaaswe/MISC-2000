// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Instruction Decoder: 11-bit opcode → class / addr-mode / dtype.
// Priority: Int Arithmetic > Logic (0x400-0x407); System late > SIMD.
module misc_decoder (
    input  logic [10:0] opcode_i,
    output logic [3:0]  inst_class_o,   // see CLASS_* below
    output logic [2:0]  addr_mode_o,    // see ADDR_* below
    output logic [2:0]  data_type_o,    // see DTYPE_* below
    output logic [7:0]  uop_code_o,     // micro-op code (vendor zone only)
    output logic        is_vendor_o,    // opcode in 0x000–0x0FF
    output logic        is_standard_o,  // opcode in 0x100–0x7CF
    output logic        is_valid_o      // opcode maps to a defined instruction
);

    // Instruction class encodings
    localparam logic [3:0] CLASS_DATA_XFER = 4'd0;
    localparam logic [3:0] CLASS_INT_ARITH = 4'd1;
    localparam logic [3:0] CLASS_LOGIC     = 4'd2;
    localparam logic [3:0] CLASS_FLOAT     = 4'd3;
    localparam logic [3:0] CLASS_PROG_CTRL = 4'd4;
    localparam logic [3:0] CLASS_SIMD      = 4'd5;
    localparam logic [3:0] CLASS_SYSTEM    = 4'd6;
    localparam logic [3:0] CLASS_VENDOR    = 4'd7;

    // Addressing-mode encodings
    localparam logic [2:0] ADDR_IMM = 3'd0;
    localparam logic [2:0] ADDR_REG = 3'd1;
    localparam logic [2:0] ADDR_DIR = 3'd2;
    localparam logic [2:0] ADDR_IDX = 3'd3;
    localparam logic [2:0] ADDR_STK = 3'd4;

    // Integer data-type encodings (offset 0 of 20-opcode base)
    localparam logic [2:0] DTYPE_B = 3'd0;
    localparam logic [2:0] DTYPE_W = 3'd1;
    localparam logic [2:0] DTYPE_D = 3'd2;
    localparam logic [2:0] DTYPE_Q = 3'd3;

    // Floating-point data-type encodings (offset 4 of 20-opcode base)
    localparam logic [2:0] DTYPE_F16  = 3'd4;
    localparam logic [2:0] DTYPE_F32  = 3'd5;
    localparam logic [2:0] DTYPE_F64  = 3'd6;
    localparam logic [2:0] DTYPE_F128 = 3'd7;

    localparam int OPS_PER_BASE = 20;
    localparam int MODES_PER_BASE = 5;

    // Opcode range boundaries
    localparam logic [10:0] VENDOR_MIN   = 11'h000;
    localparam logic [10:0] VENDOR_MAX   = 11'h0FF;
    localparam logic [10:0] DATA_XFER_MIN = 11'h100;
    localparam logic [10:0] DATA_XFER_MAX = 11'h1FF;
    localparam logic [10:0] INT_ARITH_MIN = 11'h200;
    localparam logic [10:0] INT_ARITH_MAX = 11'h407;
    localparam logic [10:0] LOGIC_MIN     = 11'h408;
    localparam logic [10:0] LOGIC_MAX     = 11'h4EF;
    localparam logic [10:0] FLOAT_MIN    = 11'h500;
    localparam logic [10:0] FLOAT_MAX    = 11'h62B;
    localparam logic [10:0] PROG_CTRL_MIN = 11'h62C;
    localparam logic [10:0] PROG_CTRL_MAX = 11'h6FF;
    localparam logic [10:0] SIMD_MIN_1    = 11'h700;
    localparam logic [10:0] SIMD_MAX_1    = 11'h7BF;
    localparam logic [10:0] SYSTEM_MIN    = 11'h7C0;
    localparam logic [10:0] SYSTEM_MAX    = 11'h7CF;
    localparam logic [10:0] SIMD_MIN_2    = 11'h7D0;
    localparam logic [10:0] SIMD_MAX_2    = 11'h7FF;

    // Special opcodes with fixed addressing mode
    localparam logic [10:0] OP_DATA_XFER_IMM_1 = 11'h132;
    localparam logic [10:0] OP_DATA_XFER_IMM_2 = 11'h133;
    localparam logic [10:0] OP_DATA_XFER_IMM_3 = 11'h134;
    localparam logic [10:0] OP_DATA_XFER_IMM_4 = 11'h15D;
    localparam logic [10:0] OP_DATA_XFER_IMM_5 = 11'h15E;
    localparam logic [10:0] OP_PROG_CTRL_IMM_1  = 11'h695;
    localparam logic [10:0] OP_PROG_CTRL_IMM_2  = 11'h696;
    localparam logic [10:0] OP_PROG_CTRL_IMM_3  = 11'h697;

    // Offset variables (declared outside always_comb to avoid
    // iverilog "constant selects in always_* processes" warning)
    logic [10:0] off_dx;
    logic [10:0] off_ia;
    logic [10:0] off_lo;
    logic [10:0] off_fl;
    logic [10:0] off_pc;
    logic [10:0] off_simd1;
    logic [10:0] off_simd2;

    logic [2:0] m_dx_mode;
    logic [2:0] m_dx_dtype;
    logic [2:0] m_ia_mode;
    logic [2:0] m_ia_dtype;
    logic [2:0] m_lo_mode;
    logic [2:0] m_lo_dtype;
    logic [2:0] m_fl_mode;
    logic [2:0] m_fl_dtype;
    logic [2:0] m_pc_mode;
    logic [2:0] m_simd1_dtype;
    logic [2:0] m_simd2_dtype;

    logic is_special_dx;
    logic is_special_pc;
    logic [7:0] vendor_uop;

    // Pre-compute all offsets and derived fields via continuous assigns
    assign off_dx    = opcode_i - DATA_XFER_MIN;
    assign off_ia    = opcode_i - INT_ARITH_MIN;
    assign off_lo    = opcode_i - LOGIC_MIN;
    assign off_fl    = opcode_i - FLOAT_MIN;
    assign off_pc    = opcode_i - PROG_CTRL_MIN;
    assign off_simd1 = opcode_i - SIMD_MIN_1;
    assign off_simd2 = opcode_i - SIMD_MIN_2;

    assign m_dx_mode  = 3'((off_dx)     % MODES_PER_BASE);
    assign m_dx_dtype = 3'(((off_dx)    % OPS_PER_BASE) / MODES_PER_BASE);
    assign m_ia_mode  = 3'((off_ia)     % MODES_PER_BASE);
    assign m_ia_dtype = 3'(((off_ia)    % OPS_PER_BASE) / MODES_PER_BASE);
    assign m_lo_mode  = 3'((off_lo)     % MODES_PER_BASE);
    assign m_lo_dtype = 3'(((off_lo)    % OPS_PER_BASE) / MODES_PER_BASE);
    assign m_fl_mode  = 3'((off_fl)     % MODES_PER_BASE);
    assign m_fl_dtype = 3'(4 + (((off_fl) % OPS_PER_BASE) / MODES_PER_BASE));
    assign m_pc_mode  = 3'((off_pc)     % MODES_PER_BASE);
    assign m_simd1_dtype = 3'((off_simd1) % 5);
    assign m_simd2_dtype = 3'((off_simd2) % 5);

    assign is_special_dx = (opcode_i == OP_DATA_XFER_IMM_1) ||
                           (opcode_i == OP_DATA_XFER_IMM_2) ||
                           (opcode_i == OP_DATA_XFER_IMM_3) ||
                           (opcode_i == OP_DATA_XFER_IMM_4) ||
                           (opcode_i == OP_DATA_XFER_IMM_5);
    assign is_special_pc = (opcode_i == OP_PROG_CTRL_IMM_1) ||
                           (opcode_i == OP_PROG_CTRL_IMM_2) ||
                           (opcode_i == OP_PROG_CTRL_IMM_3);

    assign vendor_uop = opcode_i[7:0];

    // Decoding
    // Priority ordering: System late (0x7C0-0x7CF) before SIMD;
    // Integer Arithmetic (0x200-0x407) before Logic (0x408-0x4EF).
    always_comb begin
        inst_class_o  = CLASS_DATA_XFER;
        addr_mode_o   = ADDR_IMM;
        data_type_o   = DTYPE_Q;
        uop_code_o    = 8'd0;
        is_vendor_o   = 1'b0;
        is_standard_o = 1'b0;
        is_valid_o    = 1'b0;

        if (opcode_i <= VENDOR_MAX) begin
            is_vendor_o   = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_VENDOR;
            uop_code_o    = vendor_uop;

        end else if (opcode_i >= DATA_XFER_MIN && opcode_i <= DATA_XFER_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_DATA_XFER;
            data_type_o   = m_dx_dtype;
            addr_mode_o   = is_special_dx ? ADDR_IMM : m_dx_mode;

        end else if (opcode_i >= INT_ARITH_MIN && opcode_i <= INT_ARITH_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_INT_ARITH;
            addr_mode_o   = m_ia_mode;
            data_type_o   = m_ia_dtype;

        end else if (opcode_i >= LOGIC_MIN && opcode_i <= LOGIC_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_LOGIC;
            addr_mode_o   = m_lo_mode;
            data_type_o   = m_lo_dtype;

        end else if (opcode_i >= FLOAT_MIN && opcode_i <= FLOAT_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_FLOAT;
            addr_mode_o   = m_fl_mode;
            data_type_o   = m_fl_dtype;

        end else if (opcode_i >= PROG_CTRL_MIN && opcode_i <= PROG_CTRL_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_PROG_CTRL;
            addr_mode_o   = is_special_pc ? ADDR_IMM : m_pc_mode;

        end else if (opcode_i >= SYSTEM_MIN && opcode_i <= SYSTEM_MAX) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SYSTEM;
            addr_mode_o   = ADDR_IMM;

        end else if (opcode_i >= SIMD_MIN_1 && opcode_i <= SIMD_MAX_1) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SIMD;
            addr_mode_o   = ADDR_REG;
            data_type_o   = m_simd1_dtype;

        end else if (opcode_i >= SIMD_MIN_2 && opcode_i <= SIMD_MAX_2) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SIMD;
            addr_mode_o   = ADDR_REG;
            data_type_o   = m_simd2_dtype;
        end
    end

endmodule
