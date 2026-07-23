// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
module misc_csr #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 64
) (
    // Clock and reset
    input  logic                         clk_i,
    input  logic                         rst_n_i,

    // CSR read / write interface
    input  logic                         csr_ren_i,
    input  logic                         csr_wen_i,
    input  logic [11:0]                  csr_addr_i,
    input  logic [DATA_WIDTH-1:0]        csr_wdata_i,
    output logic [DATA_WIDTH-1:0]        csr_rdata_o,

    // Exception entry interface
    input  logic                         exception_taken_i,
    input  logic [ADDR_WIDTH-1:0]        exception_pc_i,
    input  logic [2:0]                   exception_ilen_i,
    input  logic [3:0]                   exception_cause_i,

    // ERET interface
    input  logic                         eret_exec_i,
    output logic [ADDR_WIDTH-1:0]        eret_target_o,

    // LL/SC monitor interface
    input  logic                         ll_exec_i,
    input  logic [ADDR_WIDTH-1:0]        ll_addr_i,
    input  logic                         sc_exec_i,
    output logic                         sc_success_o,
    input  logic                         monitor_clear_i
);

    // CSR address constants
    localparam logic [11:0] CSR_EPC           = 12'h300;
    localparam logic [11:0] CSR_ILLEN         = 12'h301;
    localparam logic [11:0] CSR_ECAUSE        = 12'h302;
    localparam logic [11:0] CSR_ETVAL         = 12'h303;
    localparam logic [11:0] CSR_ESTATUS       = 12'h304;
    localparam logic [11:0] CSR_MONITOR_ADDR  = 12'h340;
    localparam logic [11:0] CSR_MONITOR_VALID = 12'h341;

    // Internal registers
    logic [ADDR_WIDTH-1:0] mepc;           // CSR_EPC
    logic [15:0]           millen;         // CSR_ILLEN (2/4/6/8 bytes)
    logic [3:0]            mecause;        // CSR_ECAUSE
    logic [ADDR_WIDTH-1:0] metval;         // CSR_ETVAL
    logic [DATA_WIDTH-1:0] mestatus;       // CSR_ESTATUS
    logic [ADDR_WIDTH-1:0] monitor_addr;   // CSR_MONITOR_ADDR
    logic                  monitor_valid;  // CSR_MONITOR_VALID

    // ILLEN decode: encoded 0->2B, 1->4B, 2->6B, 3->8B
    function automatic logic [15:0] decode_ilen(input logic [2:0] encoded);
        unique case (encoded)
            3'd0: decode_ilen = 16'd2;
            3'd1: decode_ilen = 16'd4;
            3'd2: decode_ilen = 16'd6;
            3'd3: decode_ilen = 16'd8;
            default: decode_ilen = 16'd2;
        endcase
    endfunction

    assign eret_target_o = mepc + { {(ADDR_WIDTH-16){1'b0}}, millen };
    assign sc_success_o = sc_exec_i & monitor_valid;

    // CSR read multiplexer
    always_comb begin
        csr_rdata_o = {DATA_WIDTH{1'b0}};
        if (csr_ren_i) begin
            unique case (csr_addr_i)
                CSR_EPC:           csr_rdata_o = { {(DATA_WIDTH-ADDR_WIDTH){1'b0}}, mepc };
                CSR_ILLEN:         csr_rdata_o = { {(DATA_WIDTH-16){1'b0}}, millen };
                CSR_ECAUSE:        csr_rdata_o = { {(DATA_WIDTH-4){1'b0}}, mecause };
                CSR_ETVAL:         csr_rdata_o = { {(DATA_WIDTH-ADDR_WIDTH){1'b0}}, metval };
                CSR_ESTATUS:       csr_rdata_o = mestatus;
                CSR_MONITOR_ADDR:  csr_rdata_o = { {(DATA_WIDTH-ADDR_WIDTH){1'b0}}, monitor_addr };
                CSR_MONITOR_VALID: csr_rdata_o = { {(DATA_WIDTH-1){1'b0}}, monitor_valid };
                default:           csr_rdata_o = {DATA_WIDTH{1'b0}};
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            mepc          <= {ADDR_WIDTH{1'b0}};
            millen        <= 16'd0;
            mecause       <= 4'd0;
            metval        <= {ADDR_WIDTH{1'b0}};
            mestatus       <= {DATA_WIDTH{1'b0}};
            monitor_addr  <= {ADDR_WIDTH{1'b0}};
            monitor_valid <= 1'b0;
        end else begin
            if (exception_taken_i) begin
                mepc    <= exception_pc_i;
                millen  <= decode_ilen(exception_ilen_i);
                mecause <= exception_cause_i;
            end

            if (csr_wen_i) begin
                unique case (csr_addr_i)
                    CSR_EPC:           mepc    <= csr_wdata_i[ADDR_WIDTH-1:0];
                    CSR_ILLEN:         millen  <= csr_wdata_i[15:0];
                    CSR_ECAUSE:        mecause <= csr_wdata_i[3:0];
                    CSR_ETVAL:         metval  <= csr_wdata_i[ADDR_WIDTH-1:0];
                    CSR_ESTATUS:       mestatus <= csr_wdata_i;
                    CSR_MONITOR_ADDR:  monitor_addr <= csr_wdata_i[ADDR_WIDTH-1:0];
                    CSR_MONITOR_VALID: monitor_valid <= csr_wdata_i[0];
                    default: ;
                endcase
            end

            if (ll_exec_i) begin
                monitor_addr  <= {ll_addr_i[ADDR_WIDTH-1:6], 6'b0};
                monitor_valid <= 1'b1;
            end

            if (sc_exec_i) begin
                monitor_valid <= 1'b0;
            end

            if (monitor_clear_i) begin
                monitor_valid <= 1'b0;
            end
        end
    end

endmodule