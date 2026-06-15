// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 instruction decoder — 11-bit opcode -> class / addr-mode / dtype.
// Priority-based: Integer Arithmetic wins over Logic in 0x400–0x407;
// System late entries (0x7C0–0x7CF) win over SIMD.

module misc_decoder (
    input  logic [10:0] opcode_i,
    output logic [3:0]  inst_class_o,   // 0=DataXfer 1=IntArith 2=Logic
                                        // 3=Float 4=ProgCtrl 5=SIMD
                                        // 6=System 7=Vendor
    output logic [2:0]  addr_mode_o,    // 0=IMM 1=REG 2=DIR 3=IDX 4=STK
    output logic [2:0]  data_type_o,    // 0=B 1=W 2=D 3=Q
                                        // 4=F16 5=F32 6=F64 7=F128
    output logic [7:0]  uop_code_o,     // micro-op code (vendor zone only)
    output logic        is_vendor_o,    // opcode in 0x000–0x0FF
    output logic        is_standard_o,  // opcode in 0x100–0x7CF
    output logic        is_valid_o      // opcode maps to a defined instruction
);

    // Instruction class encodings (matches MISC-2000 opcode-class order)
    localparam logic [3:0] CLASS_DATA_XFER     = 4'd0;
    localparam logic [3:0] CLASS_INT_ARITH     = 4'd1;
    localparam logic [3:0] CLASS_LOGIC         = 4'd2;
    localparam logic [3:0] CLASS_FLOAT         = 4'd3;
    localparam logic [3:0] CLASS_PROG_CTRL     = 4'd4;
    localparam logic [3:0] CLASS_SIMD          = 4'd5;
    localparam logic [3:0] CLASS_SYSTEM        = 4'd6;
    localparam logic [3:0] CLASS_VENDOR        = 4'd7;

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
        // Default: invalid opcode
        inst_class_o  = CLASS_DATA_XFER;
        addr_mode_o   = 3'd0;
        data_type_o   = 3'd0;
        uop_code_o    = 8'd0;
        is_vendor_o   = 1'b0;
        is_standard_o = 1'b0;
        is_valid_o    = 1'b0;

        // --------------------------------------------------------------------
        // Vendor Zone — 0x000 .. 0x0FF
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
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_DATA_XFER;
            // Single-opcode special instructions always use IMM addressing.
            if (opcode_i == 11'h132 ||   // MOV.R2M
                opcode_i == 11'h133 ||   // MOV.M2R
                opcode_i == 11'h134 ||   // MOV.M2M
                opcode_i == 11'h15D ||   // MEMBAR
                opcode_i == 11'h15E) begin // FENCE
                addr_mode_o = 3'd0;
            end else begin
                addr_mode_o = (opcode_i - 11'h100) % 5;
            end

        // --------------------------------------------------------------------
        // Integer Arithmetic — 0x200 .. 0x407
        //   20 opcodes per base: (addr_mode × type) = 5 × 4
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h200 && opcode_i <= 11'h407) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_INT_ARITH;
            addr_mode_o   = (opcode_i - 11'h200) % 5;
            data_type_o   = ((opcode_i - 11'h200) % 20) / 5;

        // --------------------------------------------------------------------
        // Logic — 0x408 .. 0x4EF
        //   0x400..0x407 belongs to Integer Arithmetic (handled above), so
        //   Logic starts at 0x408 to avoid double-mapping.  Same layout
        //   (20 opcodes / base) otherwise.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h408 && opcode_i <= 11'h4EF) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_LOGIC;
            addr_mode_o   = (opcode_i - 11'h408) % 5;
            data_type_o   = ((opcode_i - 11'h408) % 20) / 5;

        // --------------------------------------------------------------------
        // Float — 0x500 .. 0x62B
        //   4 float types: F16 / F32 / F64 / F128
        //   Takes priority over Program Control in the 0x600..0x62B overlap.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h500 && opcode_i <= 11'h62B) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_FLOAT;
            addr_mode_o   = (opcode_i - 11'h500) % 5;
            // Floating-point types: 4..7 map to F16/F32/F64/F128.
            data_type_o   = 4 + ((opcode_i - 11'h500) % 20) / 5;

        // --------------------------------------------------------------------
        // Program Control — 0x62C .. 0x6FF
        //   5 addressing modes per base instruction.
        //   Float occupies 0x600..0x62B, so Program Control starts at 0x62C.
        // --------------------------------------------------------------------
        end else if (opcode_i >= 11'h62C && opcode_i <= 11'h6FF) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_PROG_CTRL;
            // BKPT (0x669), TRACE (0x66A), WATCHDOG (0x66B) override to IMM.
            if (opcode_i == 11'h669 ||
                opcode_i == 11'h66A ||
                opcode_i == 11'h66B) begin
                addr_mode_o = 3'd0;
            end else begin
                addr_mode_o = (opcode_i - 11'h600) % 5;
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

        // --------------------------------------------------------------------
        // SIMD Vector — 0x700 .. 0x7BF  &  0x7D0 .. 0x7FF
        //   5 vector data types per instruction.
        // --------------------------------------------------------------------
        end else if ((opcode_i >= 11'h700 && opcode_i <= 11'h7BF) ||
                     (opcode_i >= 11'h7D0 && opcode_i <= 11'h7FF)) begin
            is_standard_o = 1'b1;
            is_valid_o    = 1'b1;
            inst_class_o  = CLASS_SIMD;
            data_type_o   = (opcode_i - 11'h700) % 5;

        // --------------------------------------------------------------------
        // NOTE: System privileged range 0x800 .. 0x9FF
        //   These opcodes cannot be encoded in an 11-bit word (max 0x7FF) and
        //   are intentionally left unmapped here.  A separate privileged
        //   decoder / longer opcode word is required to dispatch them.
        // --------------------------------------------------------------------
        end else begin
            // Anything else is treated as invalid (NOP).  Outputs retain the
            // default (CLASS_DATA_XFER / zero) set at the top of the block.
        end
    end

endmodule