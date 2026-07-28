// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Register File: NUM_REGS x DATA_WIDTH. x0 hardwired to zero.
// Dual combinational read; single sync write. Write-through forwarding.
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

    // Register array
    logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

    // Combinational reads (x0 hardwired to zero)
    logic [DATA_WIDTH-1:0] rf_rs1_raw;
    logic [DATA_WIDTH-1:0] rf_rs2_raw;
    logic [DATA_WIDTH-1:0] rf_rs1;
    logic [DATA_WIDTH-1:0] rf_rs2;

    always @(*) begin
        rf_rs1_raw = regs[rs1_addr_i];
        rf_rs2_raw = regs[rs2_addr_i];
    end

    assign rf_rs1 = (rs1_addr_i == '0) ? '0 : rf_rs1_raw;
    assign rf_rs2 = (rs2_addr_i == '0) ? '0 : rf_rs2_raw;

    // Write-through forwarding
    logic [DATA_WIDTH-1:0] rf_rd_raw;
    logic [DATA_WIDTH-1:0] fwd_data;
    logic [DATA_WIDTH-1:0] wr_data_next;

    always @(*) begin
        rf_rd_raw = regs[rd_addr_i];

        case (rd_width_i[1:0])
            2'd0:    fwd_data = {rf_rd_raw[DATA_WIDTH-1:8], rd_data_i[7:0]};
            2'd1:    fwd_data = {rf_rd_raw[DATA_WIDTH-1:16], rd_data_i[15:0]};
            2'd2:    fwd_data = {rf_rd_raw[DATA_WIDTH-1:32], rd_data_i[31:0]};
            default: fwd_data = rd_data_i;
        endcase

        wr_data_next = fwd_data;
    end

    assign rs1_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs1_addr_i))
                        ? fwd_data
                        : rf_rs1;

    assign rs2_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs2_addr_i))
                        ? fwd_data
                        : rf_rs2;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                regs[i] <= '0;
            end
        end else if (rd_wen_i && (rd_addr_i != '0)) begin
            regs[rd_addr_i] <= wr_data_next;
        end
    end

endmodule
