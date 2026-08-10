// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Register File: NUM_REGS × DATA_WIDTH. x0 hardwired to zero.
// Dual combinational read; single sync write. Write-through forwarding.
module misc_regfile #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 32
) (
    input  logic                          clk_i,
    input  logic                          rst_n_i,

    input  logic [ADDR_WIDTH-1:0]         rs1_addr_i,
    output logic [DATA_WIDTH-1:0]         rs1_data_o,

    input  logic [ADDR_WIDTH-1:0]         rs2_addr_i,
    output logic [DATA_WIDTH-1:0]         rs2_data_o,

    input  logic [ADDR_WIDTH-1:0]         rd_addr_i,
    input  logic [DATA_WIDTH-1:0]         rd_data_i,
    input  logic                          rd_wen_i,
    input  logic [2:0]                     rd_width_i
);

    localparam int W_B = 8;
    localparam int W_W = 16;
    localparam int W_D = 32;

    logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

    logic [DATA_WIDTH-1:0] rs1_raw;
    logic [DATA_WIDTH-1:0] rs2_raw;
    logic [DATA_WIDTH-1:0] rd_old;
    logic [DATA_WIDTH-1:0] rd_written_b;
    logic [DATA_WIDTH-1:0] rd_written_w;
    logic [DATA_WIDTH-1:0] rd_written_d;

    // Pre-compute each sub-word merge variant with continuous assigns
    // (avoids iverilog "constant selects in always_* processes" warning)
    assign rs1_raw = (rs1_addr_i == '0) ? '0 : regs[rs1_addr_i];
    assign rs2_raw = (rs2_addr_i == '0) ? '0 : regs[rs2_addr_i];
    assign rd_old  = regs[rd_addr_i];

    assign rd_written_b = {{(DATA_WIDTH-W_B){1'b0}}, rd_old[DATA_WIDTH-1:W_B]}
                         & rd_old
                       | {{(DATA_WIDTH-W_B){1'b0}}, rd_data_i[W_B-1:0]};
    // Simpler direct mux per width:
    logic [DATA_WIDTH-1:0] wr_b;
    logic [DATA_WIDTH-1:0] wr_w;
    logic [DATA_WIDTH-1:0] wr_d;
    logic [DATA_WIDTH-1:0] wr_q;

    // B: keep [DATA_WIDTH-1:8] from old, write [7:0] from new
    generate
        if (DATA_WIDTH > 8) begin : gen_b
            assign wr_b = {rd_old[DATA_WIDTH-1:8], rd_data_i[7:0]};
        end else begin : gen_b_tiny
            assign wr_b = rd_data_i[7:0];
        end
        if (DATA_WIDTH > 16) begin : gen_w
            assign wr_w = {rd_old[DATA_WIDTH-1:16], rd_data_i[15:0]};
        end else begin : gen_w_tiny
            assign wr_w = rd_data_i[15:0];
        end
        if (DATA_WIDTH > 32) begin : gen_d
            assign wr_d = {rd_old[DATA_WIDTH-1:32], rd_data_i[31:0]};
        end else begin : gen_d_tiny
            assign wr_d = rd_data_i[31:0];
        end
    endgenerate
    assign wr_q = rd_data_i;

    logic [DATA_WIDTH-1:0] rd_written;
    logic [1:0] wr_sel;
    assign wr_sel = rd_width_i[1:0];

    // Width mux outside always_comb
    assign rd_written = (wr_sel == 2'b00) ? wr_b :
                        (wr_sel == 2'b01) ? wr_w :
                        (wr_sel == 2'b10) ? wr_d : wr_q;

    // Write-through forwarding for read ports
    assign rs1_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs1_addr_i))
                        ? rd_written : rs1_raw;
    assign rs2_data_o = (rd_wen_i && (rd_addr_i != '0) && (rd_addr_i == rs2_addr_i))
                        ? rd_written : rs2_raw;

    // Sequential write
    integer i;
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                regs[i] <= '0;
            end
        end else begin
            if (rd_wen_i && (rd_addr_i != '0)) begin
                regs[rd_addr_i] <= rd_written;
            end
        end
    end

endmodule
