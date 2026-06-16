// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 instruction decoder — 11-bit opcode -> class / addr-mode / dtype.
// Priority-based: Integer Arithmetic wins over Logic in 0x400–0x407;
// System late entries (0x7C0–0x7CF) win over SIMD.

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

    // Each "base" (opcode / 20) occupies 20 opcodes:
    //   5 addressing modes × 4 data types  (integer classes)
    //   5 addressing modes × 4 float types (float class)
    localparam int OPS_PER_BASE = 20;
    localparam int MODES_PER_BASE = 5;

    // Helper: convert in-class offset -> addressing mode (0..4)
    function automatic logic [2:0] offset_to_mode(logic [10:0] off);
        logic [2:0] tmp;
        tmp = 3'(off % MODES_PER_BASE);
        return tmp;
    endfunction

    // Helper: integer class dtype (B/W/D/Q) from in-class offset
    function automatic logic [2:0] offset_to_int_dtype(logic [10:0] off);
        logic [2:0] tmp;
        tmp = 3'((off % OPS_PER_BASE) / MODES_PER_BASE);
        return tmp;
    endfunction

    // Helper: float class dtype (F16/F32/F64/F128) from in-class offset
    function automatic logic [2:0] offset_to_float_dtype(logic [10:0] off);
        logic [2:0] tmp;
        tmp = 3'(4 + ((off % OPS_PER_BASE) / MODES_PER_BASE));
        return tmp;
    endfunction

    // =========================================================================
    // Decoding
    //
    // NOTE on range ordering:
    //   * System "late" entries (0x7C0..0x7CF) live inside the SIMD opcode
    //     space (0x700..0x7FF) and must be matched BEFORE the generic SIMD
    //     rule.
    //   * Logic (0x408..0x4EF) is matched AFTER Integer Arithmetic so the
    //     overlap 0x400..0x407 is unambiguously Integer Arithmetic.
    //   * 11-bit opcodes can only reach 0x7FF; the privileged "System"
    //     range 0x800..0x9FF described in the architecture document is
    //     therefore unreachable from this decoder — it would require a
    //     longer opcode word and is handled by a separate privileged
    //     front-end.
    // =========================================================================
    always_comb begin
        // Default: invalid opcode (NOP).  Outputs are assigned stable
        // defaults so downstream logic never sees X on an un-matched path.
        inst_class_o  = CLASS_DATA_XFER;
        addr_mode_o   = ADDR_IMM;
        data_type_o   = DTYPE_Q;
        uop_code_o    = 8'd0;
        is_vendor_o   = 1'b0;
        is_standard_o = 1'b0;
        is_valid_o    = 1'b0;

        // --------------------------------------------------------------------
        // Vendor Zone — 0x000 .. 0x0FF
        //   Pass-through for customer-defined micro-ops.  uop_code is just
        //   the low 8 bits of the opcode.
        // --------------------------------------------------------------------
        if (opcode_i <= 11'h0FF) begin
            is_vendor_o  = 1'b1;
            is_valid_o   = 1'b1;
            inst_class_o = CLASS_VENDOR;
            uop_code_o   = opcode_i[7:0];

        // --------------------------------------------------------------------
        // Data Transfer — 0x100 .. 0x1FF
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h100 && opcode_i <= 11'h1FF) begin
            logic [10:0] off;
            off = opcode_i - 11'h100;
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_DATA_XFER;
            data_type_o   = offset_to_int_dtype(off);
            // Special single-opcode instructions always use IMM addressing.
            if (opcode_i == 11'h132 ||   // MOV.R2M
                opcode_i == 11'h133 ||   // MOV.M2R
                opcode_i == 11'h134 ||   // MOV.M2M
                opcode_i == 11'h15D ||   // MEMBAR
                opcode_i == 11'h15E) begin // FENCE
                addr_mode_o = ADDR_IMM;
            end else begin
                addr_mode_o = offset_to_mode(off);
            end

        // --------------------------------------------------------------------
        // Integer Arithmetic — 0x200 .. 0x407
        //   20 opcodes per base: (addr_mode × type) = 5 × 4
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h200 && opcode_i <= 11'h407) begin
            logic [10:0] off;
            off = opcode_i - 11'h200;
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_INT_ARITH;
            addr_mode_o   = offset_to_mode(off);
            data_type_o   = offset_to_int_dtype(off);

        // --------------------------------------------------------------------
        // Logic — 0x408 .. 0x4EF
        //   0x400..0x407 belongs to Integer Arithmetic (handled above), so
        //   Logic starts at 0x408 to avoid double-mapping.  Same layout
        //   (20 opcodes / base) otherwise.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h408 && opcode_i <= 11'h4EF) begin
            logic [10:0] off;
            off = opcode_i - 11'h408;
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_LOGIC;
            addr_mode_o   = offset_to_mode(off);
            data_type_o   = offset_to_int_dtype(off);

        // --------------------------------------------------------------------
        // Float — 0x500 .. 0x62B
        //   4 float types: F16 / F32 / F64 / F128
        //   Takes priority over Program Control in the 0x600..0x62B overlap.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h500 && opcode_i <= 11'h62B) begin
            logic [10:0] off;
            off = opcode_i - 11'h500;
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_FLOAT;
            addr_mode_o   = offset_to_mode(off);
            data_type_o   = offset_to_float_dtype(off);

        // --------------------------------------------------------------------
        // Program Control — 0x62C .. 0x6FF
        //   5 addressing modes per base instruction.  Note the float block
        //   consumed 0x600..0x62B, so this block starts at 0x62C.  We still
        //   subtract 0x600 to keep the mode index aligned with the spec.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h62C && opcode_i <= 11'h6FF) begin
            logic [10:0] off;
            off = opcode_i - 11'h600;
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_PROG_CTRL;
            // BKPT, TRACE, WATCHDOG are special and always use IMM.
            if (opcode_i == 11'h669 ||
                opcode_i == 11'h66A ||
                opcode_i == 11'h66B) begin
                addr_mode_o = ADDR_IMM;
            end else begin
                addr_mode_o = offset_to_mode(off);
            end

        // --------------------------------------------------------------------
        // System (late) — 0x7C0 .. 0x7CF
        //   These are System-class opcodes placed inside the SIMD range and
        //   must be matched BEFORE the SIMD rule below.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h7C0 && opcode_i <= 11'h7CF) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SYSTEM;
            addr_mode_o   = ADDR_IMM;

        // --------------------------------------------------------------------
        // SIMD Vector — 0x700 .. 0x7BF  &  0x7D0 .. 0x7FF
        //   5 vector data types per instruction.
        // --------------------------------------------------------------------
        end else if ((opcode_i >= 11'h700 && opcode_i <= 11'h7BF) ||
                     (opcode_i >= 11'h7D0 && opcode_i <= 11'h7FF)) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SIMD;
            addr_mode_o   = ADDR_REG;
            data_type_o   = (opcode_i - 11'h700) % 5;
        end

        // NOTE: 11-bit opcodes cannot express 0x800+.  There is no
        // "privileged range" in this decoder — privileged instructions must
        // be dispatched by a wider front-end (not this module).
    end

endmodule