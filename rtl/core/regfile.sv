// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 Register File — NUM_REGS registers, DATA_WIDTH bits each.
// x0 is hardwired to zero; dual combinational read ports; single sync write.
// Write-through forwarding for same-cycle reads.

module misc_regfile #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 32
) (
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

    // Local parameters / helpers
    localparam int UPPER_BYTE = (DATA_WIDTH > 8)  ? (DATA_WIDTH - 8)  : 0;
    localparam int UPPER_HALF = (DATA_WIDTH > 16) ? (DATA_WIDTH - 16) : 0;
    localparam int UPPER_WORD = (DATA_WIDTH > 32) ? (DATA_WIDTH - 32) : 0;

    function automatic logic [DATA_WIDTH-1:0] compose(
        input logic [DATA_WIDTH-1:0] old_val,
        input logic [DATA_WIDTH-1:0] wr_val,
        input logic [2:0]             width
    );
        logic [DATA_WIDTH-1:0] result;
        result = old_val;
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

    // Register array
    logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

    // Combinational reads (x0 hardwired to zero)
    wire [DATA_WIDTH-1:0] rf_rs1_raw = regs[rs1_addr_i];
    wire [DATA_WIDTH-1:0] rf_rs2_raw = regs[rs2_addr_i];
    wire [DATA_WIDTH-1:0] rf_rs1 = (rs1_addr_i == '0) ? '0 : rf_rs1_raw;
    wire [DATA_WIDTH-1:0] rf_rs2 = (rs2_addr_i == '0) ? '0 : rf_rs2_raw;

    // Write-through forwarding
    wire [DATA_WIDTH-1:0] rf_rd_raw = regs[rd_addr_i];
    logic [DATA_WIDTH-1:0] fwd_data;

    always @(*) begin
        fwd_data = compose(rf_rd_raw, rd_data_i, rd_width_i);
    end

    assign rs1_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs1_addr_i))
                        ? fwd_data
                        : rf_rs1;

    assign rs2_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs2_addr_i))
                        ? fwd_data
                        : rf_rs2;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                regs[i] <= '0;
            end
        end else if (rd_wen_i && (rd_addr_i != '0)) begin
            regs[rd_addr_i] <= compose(rf_rd_raw, rd_data_i, rd_width_i);
        end
    end

endmodule
