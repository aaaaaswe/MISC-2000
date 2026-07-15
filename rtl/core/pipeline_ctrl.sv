// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 5-Stage Pipeline Controller — Fetch → Decode → Execute → Memory → Writeback.
// Supports stall, flush (branch mispredict recovery), and branch target redirection.

module misc_pipeline_ctrl #(
    parameter int DATA_WIDTH   = 64,
    parameter int ADDR_WIDTH   = 64,
    parameter int OPCODE_WIDTH = 11
) (
    // ---- Clock and reset ----
    input  logic                         clk_i,
    input  logic                         rst_n_i,

    // ---- Pipeline control ----
    input  logic                         stall_i,        // stall the pipeline
    input  logic                         flush_i,        // flush fetch/decode (e.g. branch mispredict)

    // ---- Fetch-stage inputs ----
    input  logic [OPCODE_WIDTH-1:0]      opcode_i,       // instruction opcode from fetch
    input  logic [ADDR_WIDTH-1:0]        pc_i,           // program counter from fetch

    // ---- Decode-stage inputs (register file read data) ----
    input  logic [DATA_WIDTH-1:0]        rs1_data_i,     // register file read data 1
    input  logic [DATA_WIDTH-1:0]        rs2_data_i,     // register file read data 2

    // ---- Execute-stage inputs ----
    input  logic [DATA_WIDTH-1:0]        alu_result_i,   // ALU result

    // ---- Memory-stage inputs ----
    input  logic [DATA_WIDTH-1:0]        mem_rdata_i,    // memory read data

    // ---- Branch control ----
    input  logic                         branch_taken_i,  // branch was taken
    input  logic [ADDR_WIDTH-1:0]        branch_target_i, // branch target address

    // ---- PC outputs ----
    output logic [ADDR_WIDTH-1:0]        next_pc_o,      // next PC (pc+4 or branch target)
    output logic [ADDR_WIDTH-1:0]        pc_fetch_o,     // PC in fetch stage
    output logic [ADDR_WIDTH-1:0]        pc_decode_o,    // PC in decode stage
    output logic [ADDR_WIDTH-1:0]        pc_execute_o,   // PC in execute stage
    output logic [ADDR_WIDTH-1:0]        pc_memory_o,    // PC in memory stage

    // ---- Opcode outputs (per stage) ----
    output logic [OPCODE_WIDTH-1:0]      opcode_decode_o,
    output logic [OPCODE_WIDTH-1:0]      opcode_execute_o,
    output logic [OPCODE_WIDTH-1:0]      opcode_memory_o,

    // ---- Register addresses (from decode stage) ----
    output logic [4:0]                   rs1_addr_o,     // source register 1
    output logic [4:0]                   rs2_addr_o,     // source register 2
    output logic [4:0]                   rd_addr_o,      // destination register

    // ---- ALU interface ----
    output logic [DATA_WIDTH-1:0]        alu_op_a_o,     // ALU operand A
    output logic [DATA_WIDTH-1:0]        alu_op_b_o,     // ALU operand B
    output logic [5:0]                   alu_op_o,       // ALU operation select

    // ---- Memory / register-file control ----
    output logic                         reg_write_o,    // register file write enable
    output logic                         mem_read_o,     // memory read enable
    output logic                         mem_write_o,    // memory write enable
    output logic [DATA_WIDTH-1:0]        mem_wdata_o,    // memory write data

    // ---- Writeback result ----
    output logic [DATA_WIDTH-1:0]        result_o,       // final result (writeback data)

    // ---- Stall status ----
    output logic                         stall_fetch_o,  // fetch stage stalled
    output logic                         stall_decode_o, // decode stage stalled

    // ---- Pipeline state (0=IDLE, 1=RUNNING, 2=STALLED, 3=FLUSHING) ----
    output logic [1:0]                   pipeline_state_o
);

    // ---- Pipeline state encoding ----
    localparam logic [1:0] STATE_IDLE    = 2'd0;
    localparam logic [1:0] STATE_RUNNING = 2'd1;
    localparam logic [1:0] STATE_STALLED = 2'd2;
    localparam logic [1:0] STATE_FLUSHING = 2'd3;

    // ---- Pipeline registers: Fetch → Decode ----
    logic [ADDR_WIDTH-1:0]   fd_pc;
    logic [OPCODE_WIDTH-1:0] fd_opcode;
    logic                    fd_valid;

    // ---- Pipeline registers: Decode → Execute ----
    logic [ADDR_WIDTH-1:0]   de_pc;
    logic [OPCODE_WIDTH-1:0] de_opcode;
    logic [DATA_WIDTH-1:0]   de_rs1_data;
    logic [DATA_WIDTH-1:0]   de_rs2_data;
    logic [4:0]              de_rs1_addr;
    logic [4:0]              de_rs2_addr;
    logic [4:0]              de_rd_addr;
    logic                    de_valid;

    // ---- Pipeline registers: Execute → Memory ----
    logic [ADDR_WIDTH-1:0]   em_pc;
    logic [OPCODE_WIDTH-1:0] em_opcode;
    logic [DATA_WIDTH-1:0]   em_alu_result;
    logic [DATA_WIDTH-1:0]   em_mem_wdata;
    logic [4:0]              em_rd_addr;
    logic                    em_reg_write;
    logic                    em_mem_read;
    logic                    em_mem_write;
    logic                    em_valid;

    // ---- Pipeline registers: Memory → Writeback ----
    logic [ADDR_WIDTH-1:0]   mw_pc;
    logic [OPCODE_WIDTH-1:0] mw_opcode;
    logic [DATA_WIDTH-1:0]   mw_mem_rdata;
    logic [DATA_WIDTH-1:0]   mw_alu_result;
    logic [4:0]              mw_rd_addr;
    logic                    mw_reg_write;
    logic                    mw_valid;

    // ---- Next-state signals (combinational) ----
    logic                    flush_active;
    logic                    stall_active;
    logic                    advance_pipe;     // normal pipeline advance this cycle
    logic [1:0]              next_state;

    // ---- Instruction decode helpers (combinational) ----
    // Register fields are derived from opcode bits per MISC-2000 encoding.
    logic [4:0]  decode_rs1_addr;
    logic [4:0]  decode_rs2_addr;
    logic [4:0]  decode_rd_addr;
    logic [5:0]  decode_alu_op;
    logic        decode_reg_write;
    logic        decode_mem_read;
    logic        decode_mem_write;

    // Simplified opcode decode: ranges match misc_decoder so interpretations
    // never disagree.  11-bit opcodes cannot reach 0x800+.
    always_comb begin
        // Default: no operation
        decode_rs1_addr  = 5'd0;
        decode_rs2_addr  = 5'd0;
        decode_rd_addr   = 5'd0;
        decode_alu_op    = 6'd0;
        decode_reg_write = 1'b0;
        decode_mem_read  = 1'b0;
        decode_mem_write = 1'b0;

        if (fd_opcode >= 11'h100 && fd_opcode <= 11'h1FF) begin
            // ---- Data Transfer ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_mem_read  = ~fd_opcode[5];   // loads
            decode_mem_write =  fd_opcode[5];   // stores
            decode_reg_write = ~fd_opcode[5];   // loads write back to register

        end else if (fd_opcode >= 11'h200 && fd_opcode <= 11'h407) begin
            // ---- Integer Arithmetic ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_alu_op    = fd_opcode[5:0];   // lower 6 bits select ALU op
            decode_reg_write = 1'b1;

        end else if (fd_opcode >= 11'h408 && fd_opcode <= 11'h4EF) begin
            // ---- Logic ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_alu_op    = fd_opcode[5:0];
            decode_reg_write = 1'b1;

        end else if (fd_opcode >= 11'h500 && fd_opcode <= 11'h62B) begin
            // ---- Float ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_alu_op    = fd_opcode[5:0];
            decode_reg_write = 1'b1;

        end else if (fd_opcode >= 11'h62C && fd_opcode <= 11'h6FF) begin
            // ---- Program Control ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = 5'd0;

        end else if ((fd_opcode >= 11'h700 && fd_opcode <= 11'h7BF) ||
                     (fd_opcode >= 11'h7D0 && fd_opcode <= 11'h7FF)) begin
            // ---- SIMD Vector ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_alu_op    = fd_opcode[5:0];
            decode_reg_write = 1'b1;

        end else if (fd_opcode >= 11'h7C0 && fd_opcode <= 11'h7CF) begin
            // ---- System (late) ----
            decode_rs1_addr  = fd_opcode[4:0];
            decode_rs2_addr  = fd_opcode[9:5];
            decode_rd_addr   = fd_opcode[4:0];
            decode_reg_write = 1'b0;   // system ops do not write GPRs here

        end else begin
            // ---- Vendor zone (0x000..0x0FF) or invalid -> NOP ----
            decode_rs1_addr  = 5'd0;
            decode_rs2_addr  = 5'd0;
            decode_rd_addr   = 5'd0;
            decode_alu_op    = 6'd0;
            decode_reg_write = 1'b0;
            decode_mem_read  = 1'b0;
            decode_mem_write = 1'b0;
        end
    end

    // ---- Pipeline control FSM ----
    assign flush_active = flush_i || branch_taken_i;
    assign stall_active = stall_i && !flush_active;

    always_comb begin
        if (!rst_n_i)
            next_state = STATE_IDLE;
        else if (flush_active)
            next_state = STATE_FLUSHING;
        else if (stall_active)
            next_state = STATE_STALLED;
        else
            next_state = STATE_RUNNING;
    end

    // advance_pipe is asserted when the pipeline should shift normally
    assign advance_pipe = (next_state == STATE_RUNNING);

    // ---- Pipeline state register ----
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            pipeline_state_o <= STATE_IDLE;
        else
            pipeline_state_o <= next_state;
    end

    // ---- Stall outputs ----
    assign stall_fetch_o  = stall_active;
    assign stall_decode_o = stall_active;

    // ---- Next PC computation ----
    assign next_pc_o = branch_taken_i ? branch_target_i : (pc_i + {{ADDR_WIDTH-3}{1'b0}, 3'd4});

    // ---- Pipeline register update (sequential) ----
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            // Reset: clear all pipeline registers
            fd_pc         <= '0;
            fd_opcode     <= '0;
            fd_valid      <= 1'b0;

            de_pc         <= '0;
            de_opcode     <= '0;
            de_rs1_data   <= '0;
            de_rs2_data   <= '0;
            de_rs1_addr   <= '0;
            de_rs2_addr   <= '0;
            de_rd_addr    <= '0;
            de_valid      <= 1'b0;

            em_pc         <= '0;
            em_opcode     <= '0;
            em_alu_result <= '0;
            em_mem_wdata  <= '0;
            em_rd_addr    <= '0;
            em_reg_write  <= 1'b0;
            em_mem_read   <= 1'b0;
            em_mem_write  <= 1'b0;
            em_valid      <= 1'b0;

            mw_pc         <= '0;
            mw_opcode     <= '0;
            mw_mem_rdata  <= '0;
            mw_alu_result <= '0;
            mw_rd_addr    <= '0;
            mw_reg_write  <= 1'b0;
            mw_valid      <= 1'b0;

        end else if (flush_active) begin
            // Flush: invalidate fetch/decode; execute/memory continue to drain.
            fd_valid <= 1'b0;
            de_valid <= 1'b0;

            // Execute → Memory (shift even during flush to drain the pipe)
            em_pc         <= de_pc;
            em_opcode     <= de_opcode;
            em_alu_result <= alu_result_i;
            em_mem_wdata  <= de_rs2_data;
            em_rd_addr    <= de_rd_addr;
            em_reg_write  <= decode_reg_write & de_valid;
            em_mem_read   <= decode_mem_read  & de_valid;
            em_mem_write  <= decode_mem_write & de_valid;
            em_valid      <= de_valid;

            // Memory → Writeback
            mw_pc         <= em_pc;
            mw_opcode     <= em_opcode;
            mw_mem_rdata  <= mem_rdata_i;
            mw_alu_result <= em_alu_result;
            mw_rd_addr    <= em_rd_addr;
            mw_reg_write  <= em_reg_write;
            mw_valid      <= em_valid;

        end else if (stall_active) begin
            // Stall: freeze fetch/decode; execute/memory continue to run.
            // Fetch → Decode: no update (frozen)
            // (fd_* registers hold their values)

            // Decode → Execute: no update (frozen)
            // (de_* registers hold their values)

            // Execute → Memory
            em_pc         <= de_pc;
            em_opcode     <= de_opcode;
            em_alu_result <= alu_result_i;
            em_mem_wdata  <= de_rs2_data;
            em_rd_addr    <= de_rd_addr;
            em_reg_write  <= decode_reg_write & de_valid;
            em_mem_read   <= decode_mem_read  & de_valid;
            em_mem_write  <= decode_mem_write & de_valid;
            em_valid      <= de_valid;

            // Memory → Writeback
            mw_pc         <= em_pc;
            mw_opcode     <= em_opcode;
            mw_mem_rdata  <= mem_rdata_i;
            mw_alu_result <= em_alu_result;
            mw_rd_addr    <= em_rd_addr;
            mw_reg_write  <= em_reg_write;
            mw_valid      <= em_valid;

        end else begin
            // Normal operation: shift all stages forward

            // Fetch → Decode
            fd_pc     <= pc_i;
            fd_opcode <= opcode_i;
            fd_valid  <= 1'b1;

            // Decode → Execute
            de_pc         <= fd_pc;
            de_opcode     <= fd_opcode;
            de_rs1_data   <= rs1_data_i;
            de_rs2_data   <= rs2_data_i;
            de_rs1_addr   <= decode_rs1_addr;
            de_rs2_addr   <= decode_rs2_addr;
            de_rd_addr    <= decode_rd_addr;
            de_valid      <= fd_valid;

            // Execute → Memory
            em_pc         <= de_pc;
            em_opcode     <= de_opcode;
            em_alu_result <= alu_result_i;
            em_mem_wdata  <= de_rs2_data;
            em_rd_addr    <= de_rd_addr;
            em_reg_write  <= decode_reg_write & de_valid;
            em_mem_read   <= decode_mem_read  & de_valid;
            em_mem_write  <= decode_mem_write & de_valid;
            em_valid      <= de_valid;

            // Memory → Writeback
            mw_pc         <= em_pc;
            mw_opcode     <= em_opcode;
            mw_mem_rdata  <= mem_rdata_i;
            mw_alu_result <= em_alu_result;
            mw_rd_addr    <= em_rd_addr;
            mw_reg_write  <= em_reg_write;
            mw_valid      <= em_valid;
        end
    end

    // ---- Combinational output assignments ----

    // PC outputs (from internal pipeline registers)
    assign pc_fetch_o   = pc_i;
    assign pc_decode_o  = fd_pc;
    assign pc_execute_o = de_pc;
    assign pc_memory_o  = em_pc;

    // Opcode outputs
    assign opcode_decode_o  = fd_opcode;
    assign opcode_execute_o = de_opcode;
    assign opcode_memory_o  = em_opcode;

    // Register addresses (from decode stage)
    assign rs1_addr_o = de_rs1_addr;
    assign rs2_addr_o = de_rs2_addr;
    assign rd_addr_o  = (mw_valid && mw_reg_write) ? mw_rd_addr : em_rd_addr;

    // ALU interface — driven by decode-stage values
    assign alu_op_a_o = de_rs1_data;
    assign alu_op_b_o = de_rs2_data;
    assign alu_op_o   = decode_alu_op;

    // Memory / register-file control (from execute/memory stage)
    assign reg_write_o = mw_reg_write && mw_valid;
    assign mem_read_o  = em_mem_read  && em_valid;
    assign mem_write_o = em_mem_write && em_valid;
    assign mem_wdata_o = em_mem_wdata;

    // Writeback result — select between ALU result and memory read data.
    // Load instructions return mem_rdata; all others return alu_result.
    assign result_o = (mw_valid && (mw_opcode >= 11'h100 && mw_opcode <= 11'h1FF && !mw_opcode[5]))
                      ? mw_mem_rdata
                      : mw_alu_result;

endmodule