// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0

// Register File for the MISC-2000 processor.
// - NUM_REGS general-purpose registers, each DATA_WIDTH bits wide.
// - x0 (register 0) is hardwired to zero: reads return 0, writes are
//   silently ignored.
// - Dual combinational read ports (rs1, rs2).
// - Single synchronous write port with sub-word write support controlled
//   by rd_width_i:
//       0 -> write low 8  bits (byte)
//       1 -> write low 16 bits (half-word)
//       2 -> write low 32 bits (word)
//       3 -> write full DATA_WIDTH bits (quad-word)
// - Write-through forwarding: when the write address matches a read
//   address and rd_wen_i is high, the composed value is driven on the
//   read port in the same cycle.

module misc_regfile #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 32
) (
    // Clock and reset (asynchronous active-low clear)
    input  logic                          clk_i,
    input  logic                          rst_n_i,

    // Read port 1
    input  logic [ADDR_WIDTH-1:0]         rs1_addr_i,
    output logic [DATA_WIDTH-1:0]         rs1_data_o,

    // Read port 2
    input  logic [ADDR_WIDTH-1:0]         rs2_addr_i,
    output logic [DATA_WIDTH-1:0]         rs2_data_o,

    // Write port
    input  logic [ADDR_WIDTH-1:0]         rd_addr_i,
    input  logic [DATA_WIDTH-1:0]         rd_data_i,
    input  logic                          rd_wen_i,
    input  logic [2:0]                     rd_width_i
);

    // =====================================================================
    // Local parameters / helpers
    //   Width of the "upper" (unchanged) part of the register during a
    //   sub-word write.  Clamped at 0 so that a narrow DATA_WIDTH does not
    //   produce a negative (and thus invalid) Verilog part-select width.
    // =====================================================================
    localparam int UPPER_BYTE = (DATA_WIDTH > 8)  ? (DATA_WIDTH - 8)  : 0;
    localparam int UPPER_HALF = (DATA_WIDTH > 16) ? (DATA_WIDTH - 16) : 0;
    localparam int UPPER_WORD = (DATA_WIDTH > 32) ? (DATA_WIDTH - 32) : 0;

    // Sub-word composer: returns the new value of a register after
    // replacing the low N bits with the corresponding slice of write
    // data.  The upper bits are preserved from `old_val`.
    function automatic logic [DATA_WIDTH-1:0] compose(
        input logic [DATA_WIDTH-1:0] old_val,
        input logic [DATA_WIDTH-1:0] wr_val,
        input logic [2:0]             width
    );
        logic [DATA_WIDTH-1:0] result;
        result = old_val;                 // default: preserve all bits
        unique case (width[1:0])
            2'd0: begin
                result[7:0] = wr_val[7:0];
                if (UPPER_BYTE > 0) result[DATA_WIDTH-1:8] = old_val[DATA_WIDTH-1:8];
            end
            2'd1: begin
                result[15:0] = wr_val[15:0];
                if (UPPER_HALF > 0) result[DATA_WIDTH-1:16] = old_val[DATA_WIDTH-1:16];
            end
            2'd2: begin
                result[31:0] = wr_val[31:0];
                if (UPPER_WORD > 0) result[DATA_WIDTH-1:32] = old_val[DATA_WIDTH-1:32];
            end
            default: result = wr_val;
        endcase
        return result;
    endfunction

    // =====================================================================
    // Register array
    // =====================================================================
    logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

    // =====================================================================
    // Combinational reads (x0 hardwired to zero)
    // =====================================================================
    wire [DATA_WIDTH-1:0] rf_rs1_raw = regs[rs1_addr_i];
    wire [DATA_WIDTH-1:0] rf_rs2_raw = regs[rs2_addr_i];

    wire [DATA_WIDTH-1:0] rf_rs1 = (rs1_addr_i == '0) ? '0 : rf_rs1_raw;
    wire [DATA_WIDTH-1:0] rf_rs2 = (rs2_addr_i == '0) ? '0 : rf_rs2_raw;

    // =====================================================================
    // Write-through forwarding
    // =====================================================================
    wire [DATA_WIDTH-1:0] rf_rd_raw = regs[rd_addr_i];
    logic [DATA_WIDTH-1:0] fwd_data;

    always @(*) begin
        fwd_data = compose(rf_rd_raw, rd_data_i, rd_width_i);
    end

    // Forward to each read port.  x0 forwarding is suppressed because x0
    // is always zero regardless of any attempted write.
    assign rs1_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs1_addr_i))
                        ? fwd_data
                        : rf_rs1;

    assign rs2_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs2_addr_i))
                        ? fwd_data
                        : rf_rs2;

    // =====================================================================
    // Synchronous write with asynchronous active-low reset
    // =====================================================================
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            // Clear all registers to zero on reset.
            for (int i = 0; i < NUM_REGS; i++) begin
                regs[i] <= '0;
            end
        end else if (rd_wen_i && (rd_addr_i != '0)) begin
            regs[rd_addr_i] <= compose(rf_rd_raw, rd_data_i, rd_width_i);
        end
    end

endmodule
