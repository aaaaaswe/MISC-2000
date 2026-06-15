// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0

// Register File for the MISC-2000 RISC-V style processor.
// - 32 general-purpose registers (x0–x31), 64-bit wide each.
// - x0 is hardwired to zero: reads return 0, writes are silently ignored.
// - Dual combinational read ports (rs1, rs2).
// - Single synchronous write port with sub-word write support.
// - Asynchronous active-low reset clears all registers.
// - Write-through forwarding: when the write address matches a read address
//   and write enable is high, the forwarded (partially-updated) value is
//   driven on the read port in the same cycle.

module misc_regfile #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 32
) (
    // Clock and reset
    input  logic                         clk_i,
    input  logic                         rst_n_i,

    // Read port 1
    input  logic [ADDR_WIDTH-1:0]        rs1_addr_i,
    output logic [DATA_WIDTH-1:0]        rs1_data_o,

    // Read port 2
    input  logic [ADDR_WIDTH-1:0]        rs2_addr_i,
    output logic [DATA_WIDTH-1:0]        rs2_data_o,

    // Write port
    input  logic [ADDR_WIDTH-1:0]        rd_addr_i,
    input  logic [DATA_WIDTH-1:0]        rd_data_i,
    input  logic                         rd_wen_i,
    // Write width: 0 = B (byte, 8-bit), 1 = W (half-word, 16-bit),
    //              2 = D (word, 32-bit),   3 = Q (quad-word, 64-bit)
    input  logic [2:0]                    rd_width_i
);

    // -----------------------------------------------------------------------
    // Register array
    // -----------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

    // -----------------------------------------------------------------------
    // Combinational reads (x0 hardwired to zero)
    // -----------------------------------------------------------------------
    wire [DATA_WIDTH-1:0] rf_rs1_raw;
    wire [DATA_WIDTH-1:0] rf_rs2_raw;

    assign rf_rs1_raw = regs[rs1_addr_i];
    assign rf_rs2_raw = regs[rs2_addr_i];

    // x0 always reads as zero
    wire [DATA_WIDTH-1:0] rf_rs1 = (rs1_addr_i == '0) ? '0 : rf_rs1_raw;
    wire [DATA_WIDTH-1:0] rf_rs2 = (rs2_addr_i == '0) ? '0 : rf_rs2_raw;

    // -----------------------------------------------------------------------
    // Write-through forwarding
    // When rd_wen_i is high and the write target matches a read address,
    // forward the value that will be written (composed from old register
    // data and the incoming write data according to width).
    // -----------------------------------------------------------------------
    wire [DATA_WIDTH-1:0] rf_rd_raw;
    assign rf_rd_raw = regs[rd_addr_i];

    // Build the value that will actually be committed to the register file
    // on the next clock edge.  For x0 this is always zero (writes ignored).
    logic [DATA_WIDTH-1:0] fwd_data;

    always_comb begin
        unique case (rd_width_i[1:0])
            2'd0:   fwd_data = {rf_rd_raw[63:8],  rd_data_i[7:0]};   // B
            2'd1:   fwd_data = {rf_rd_raw[63:16], rd_data_i[15:0]};  // W
            2'd2:   fwd_data = {rf_rd_raw[63:32], rd_data_i[31:0]};  // D
            default: fwd_data = rd_data_i;                            // Q (64-bit)
        endcase
    end

    // Forward to rs1 if addresses match, write is enabled, and target is not x0
    assign rs1_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs1_addr_i))
                        ? fwd_data
                        : rf_rs1;

    // Forward to rs2 if addresses match, write is enabled, and target is not x0
    assign rs2_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs2_addr_i))
                        ? fwd_data
                        : rf_rs2;

    // -----------------------------------------------------------------------
    // Synchronous write with asynchronous active-low reset
    // -----------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            // Clear all registers to zero
            foreach (regs[i]) begin
                regs[i] <= '0;
            end
        end else if (rd_wen_i && (rd_addr_i != '0)) begin
            // Sub-word write — replace the appropriate byte lanes.
            // Explicit 2-bit width selector so tools do not infer
            // unreachable 4..7 case logic.
            unique case (rd_width_i[1:0])
                2'd0: regs[rd_addr_i] <= {regs[rd_addr_i][63:8],  rd_data_i[7:0]};   // B
                2'd1: regs[rd_addr_i] <= {regs[rd_addr_i][63:16], rd_data_i[15:0]};  // W
                2'd2: regs[rd_addr_i] <= {regs[rd_addr_i][63:32], rd_data_i[31:0]};  // D
                2'd3: regs[rd_addr_i] <= rd_data_i;                                    // Q
            endcase
        end
    end

endmodule