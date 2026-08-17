// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Shared opcode and related constant definitions for MISC-2000.
// Include via `include "misc_opcodes.svh" (requires -I path to rtl/include).

// ---------------------------------------------------------------------------
// Atomic / system-sync opcodes (4-byte fixed-length, must not cross page)
// Spec: LL.D, SC.D, CAS.D all in 0x144-0x148 (5 opcodes total).
// Trade-off: reduce CAS from 5 variants to 3 (IMM/REG/DIR) to fit LL/SC.
// ---------------------------------------------------------------------------
localparam logic [10:0] OP_LL_D    = 11'h144;
localparam logic [10:0] OP_SC_D    = 11'h145;
localparam logic [10:0] OP_CAS_IMM = 11'h146;
localparam logic [10:0] OP_CAS_REG = 11'h147;
localparam logic [10:0] OP_CAS_DIR = 11'h148;
localparam logic [10:0] OP_FENCE   = 11'h15E;
localparam logic [10:0] OP_GETILEN = 11'h0FE;

// ---------------------------------------------------------------------------
// IFU exception cause encoding (2-bit)
// ---------------------------------------------------------------------------
localparam logic [1:0] EXC_PAGE_FAULT        = 2'b00;
localparam logic [1:0] EXC_ILLEGAL_INSTR     = 2'b01;
localparam logic [1:0] EXC_ATOMIC_CROSS_PAGE = 2'b10;

// ---------------------------------------------------------------------------
// Instruction-length encoding (IFU output, 3-bit)
// ---------------------------------------------------------------------------
localparam logic [2:0] LEN_2B = 3'd0;
localparam logic [2:0] LEN_4B = 3'd1;
localparam logic [2:0] LEN_6B = 3'd2;
localparam logic [2:0] LEN_8B = 3'd3;

// ---------------------------------------------------------------------------
// Page size constant (4 KB)
// Declared as 13-bit unsigned to match the 13-bit addition used in the
// atomic/IFU cross-page check without mixed signedness.
// ---------------------------------------------------------------------------
localparam logic [12:0] PAGE_SIZE = 13'h1000;

// ---------------------------------------------------------------------------
// Atomic instruction byte count (4 bytes, fixed-length)
// ---------------------------------------------------------------------------
localparam logic [12:0] ATOMIC_INST_BYTES = 13'd4;
