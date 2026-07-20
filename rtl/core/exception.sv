// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Exception Management: IFU page fault > mem page fault > illegal instr
// ERET: PC = CSR_EPC + CSR_ILLEN; handler vector: 0x8000_0000

module misc_exception #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 64
) (
    // Clock & Reset
    input  logic                     clk_i,
    input  logic                     rst_n_i,

    // Exception inputs from IFU
    input  logic                     ifu_exception_i,
    input  logic [1:0]               ifu_exception_cause_i,
    input  logic [ADDR_WIDTH-1:0]    ifu_exception_addr_i,
    input  logic [2:0]               ifu_instr_len_i,

    // Exception inputs from memory stage
    input  logic                     mem_exception_i,
    input  logic [1:0]               mem_exception_cause_i,
    input  logic [ADDR_WIDTH-1:0]    mem_exception_addr_i,
    input  logic [2:0]               mem_instr_len_i,

    // Exception inputs from decode stage
    input  logic                     decode_exception_i,
    input  logic [1:0]               decode_exception_cause_i,
    input  logic [ADDR_WIDTH-1:0]    decode_exception_addr_i,
    input  logic [2:0]               decode_instr_len_i,

    // ERET execution
    input  logic                     eret_exec_i,

    // CSR interface inputs
    input  logic [ADDR_WIDTH-1:0]    csr_eret_target_i,

    // Outputs to CSR module
    output logic                     exception_taken_o,
    output logic [ADDR_WIDTH-1:0]    exception_pc_o,
    output logic [2:0]               exception_ilen_o,
    output logic [3:0]               exception_cause_o,

    // Outputs to pipeline
    output logic                     flush_pipeline_o,
    output logic [ADDR_WIDTH-1:0]    exception_target_pc_o,
    output logic [ADDR_WIDTH-1:0]    eret_target_pc_o,
    output logic                     exception_active_o
);

    // Local parameters
    localparam logic [3:0] EXC_CAUSE_ILLEGAL_INSTR    = 4'h2;
    localparam logic [3:0] EXC_CAUSE_INSTR_PAGE_FAULT  = 4'hC;
    localparam logic [3:0] EXC_CAUSE_LDST_PAGE_FAULT   = 4'hD;

    // IFU exception cause encoding (from IFU)
    localparam logic [1:0] IFU_CAUSE_PAGE_FAULT        = 2'b00;

    // Memory exception cause encoding (from memory stage)
    localparam logic [1:0] MEM_CAUSE_PAGE_FAULT        = 2'b00;

    // Exception handler entry point (vector address)
    localparam logic [ADDR_WIDTH-1:0] EXC_VECTOR_ADDR  = {ADDR_WIDTH{1'b0}} | 64'h0000_0000_8000_0000;

    // Internal signals
    logic                        exception_detected;
    logic [ADDR_WIDTH-1:0]       selected_exc_pc;
    logic [2:0]                  selected_exc_ilen;
    logic [3:0]                  selected_exc_cause;
    logic                        exception_active_q;
    logic [ADDR_WIDTH-1:0]       exception_pc_q;
    logic [2:0]                  exception_ilen_q;
    logic [3:0]                  exception_cause_q;
    logic                        take_exception;

    // Exception priority encoder
    // IFU page fault > mem page fault > illegal instr
    always_comb begin
        exception_detected  = 1'b0;
        selected_exc_pc     = '0;
        selected_exc_ilen   = 3'b0;
        selected_exc_cause  = 4'b0;

        // Priority 1: IFU instruction page fault
        if (ifu_exception_i && (ifu_exception_cause_i == IFU_CAUSE_PAGE_FAULT)) begin
            exception_detected  = 1'b1;
            selected_exc_pc     = ifu_exception_addr_i;
            selected_exc_ilen   = ifu_instr_len_i;
            selected_exc_cause  = EXC_CAUSE_INSTR_PAGE_FAULT;
        end
        // Priority 2: Memory (data) load/store page fault
        else if (mem_exception_i && (mem_exception_cause_i == MEM_CAUSE_PAGE_FAULT)) begin
            exception_detected  = 1'b1;
            selected_exc_pc     = mem_exception_addr_i;
            selected_exc_ilen   = mem_instr_len_i;
            selected_exc_cause  = EXC_CAUSE_LDST_PAGE_FAULT;
        end
        // Priority 3: IFU illegal instruction / atomic cross-page
        else if (ifu_exception_i) begin
            exception_detected  = 1'b1;
            selected_exc_pc     = ifu_exception_addr_i;
            selected_exc_ilen   = ifu_instr_len_i;
            selected_exc_cause  = EXC_CAUSE_ILLEGAL_INSTR;
        end
        // Priority 4: Decode illegal instruction
        else if (decode_exception_i) begin
            exception_detected  = 1'b1;
            selected_exc_pc     = decode_exception_addr_i;
            selected_exc_ilen   = decode_instr_len_i;
            selected_exc_cause  = EXC_CAUSE_ILLEGAL_INSTR;
        end
    end

    // Exception active state
    assign take_exception = !exception_active_q && exception_detected && !eret_exec_i;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            exception_active_q <= 1'b0;
        end else if (eret_exec_i) begin
            exception_active_q <= 1'b0;
        end else if (take_exception) begin
            exception_active_q <= 1'b1;
        end
    end

    // Exception info latch
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            exception_pc_q    <= '0;
            exception_ilen_q  <= 3'b0;
            exception_cause_q <= 4'b0;
        end else if (take_exception) begin
            exception_pc_q    <= selected_exc_pc;
            exception_ilen_q  <= selected_exc_ilen;
            exception_cause_q <= selected_exc_cause;
        end
    end

    // Output assignments
    assign exception_pc_o    = exception_pc_q;
    assign exception_ilen_o  = exception_ilen_q;
    assign exception_cause_o = exception_cause_q;
    assign exception_taken_o = take_exception;
    assign exception_active_o = exception_active_q;
    assign flush_pipeline_o = take_exception || eret_exec_i;

    assign exception_target_pc_o = eret_exec_i                     ? csr_eret_target_i :
                                   (exception_active_q || take_exception) ? EXC_VECTOR_ADDR :
                                   '0;

    assign eret_target_pc_o = csr_eret_target_i;

endmodule