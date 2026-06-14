#===============================================================================
# MISC-2000 Processor Simulation Makefile
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#===============================================================================

# ---- Simulator Tools ---------------------------------------------------------
SIM      := iverilog
VVP      := vvp
WAVES    := gtkwave

# ---- Directories -------------------------------------------------------------
RTL_DIR  := ../rtl/core
SIM_DIR  := .
VCD_DIR  := ./waves

# ---- Colors ------------------------------------------------------------------
NC       := \033[0m
GREEN    := \033[0;32m
CYAN     := \033[0;36m
YELLOW   := \033[0;33m
RED      := \033[0;31m

# ---- Source Files ------------------------------------------------------------
RTL_SRCS := $(wildcard $(RTL_DIR)/*.sv)

# ---- Compile/Run Flags -------------------------------------------------------
IVERILOG_FLAGS := -g2012

# ---- .PHONY ------------------------------------------------------------------
.PHONY: all \
        compile_alu compile_decoder compile_regfile \
        compile_ifu compile_exception compile_atomic compile_getilen \
        run_alu run_decoder run_regfile \
        run_ifu run_exception run_atomic run_getilen \
        test_alu test_decoder test_regfile \
        test_ifu test_exception test_atomic test_getilen \
        wave_alu wave_decoder wave_regfile \
        wave_ifu wave_exception wave_atomic wave_getilen \
        clean help

# ---- Top-Level Targets -------------------------------------------------------
all: $(VCD_DIR) test_alu test_decoder test_regfile test_ifu test_exception test_atomic test_getilen
	@echo "$(GREEN)[DONE]$(NC) All 7 testbenches compiled and simulated successfully."

# ---- Compile Targets ---------------------------------------------------------
compile_alu: $(VCD_DIR) test_alu.vvp
compile_decoder: $(VCD_DIR) test_decoder.vvp
compile_regfile: $(VCD_DIR) test_regfile.vvp
compile_ifu: $(VCD_DIR) test_ifu.vvp
compile_exception: $(VCD_DIR) test_exception.vvp
compile_atomic: $(VCD_DIR) test_atomic.vvp
compile_getilen: $(VCD_DIR) test_getilen.vvp

test_alu.vvp: $(RTL_DIR)/alu.sv $(SIM_DIR)/test_alu.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_alu.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/alu.sv $(SIM_DIR)/test_alu.sv

test_decoder.vvp: $(RTL_DIR)/decoder.sv $(SIM_DIR)/test_decoder.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_decoder.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/decoder.sv $(SIM_DIR)/test_decoder.sv

test_regfile.vvp: $(RTL_DIR)/regfile.sv $(SIM_DIR)/test_regfile.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_regfile.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/regfile.sv $(SIM_DIR)/test_regfile.sv

test_getilen.vvp: $(RTL_DIR)/getilen.sv $(SIM_DIR)/test_getilen.sv
	@echo "$(CYAN)[COMPILE]$(NC) Building test_getilen.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(SIM_DIR)/test_getilen.sv

test_ifu.vvp: $(RTL_DIR)/ifu.sv $(SIM_DIR)/test_ifu.sv
	@echo "$(CYAN)[COMPILE]$(NC) Building test_ifu.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/ifu.sv $(SIM_DIR)/test_ifu.sv

test_exception.vvp: $(RTL_DIR)/exception.sv $(RTL_DIR)/csr.sv $(SIM_DIR)/test_exception.sv
	@echo "$(CYAN)[COMPILE]$(NC) Building test_exception.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/exception.sv $(RTL_DIR)/csr.sv $(SIM_DIR)/test_exception.sv

test_atomic.vvp: $(RTL_DIR)/atomic.sv $(RTL_DIR)/csr.sv $(SIM_DIR)/test_atomic.sv
	@echo "$(CYAN)[COMPILE]$(NC) Building test_atomic.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/atomic.sv $(RTL_DIR)/csr.sv $(SIM_DIR)/test_atomic.sv

# ---- Run Targets -------------------------------------------------------------
run_alu: $(VCD_DIR) test_alu.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_alu ..."
	$(VVP) test_alu.vvp

run_decoder: $(VCD_DIR) test_decoder.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_decoder ..."
	$(VVP) test_decoder.vvp

run_regfile: $(VCD_DIR) test_regfile.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_regfile ..."
	$(VVP) test_regfile.vvp

run_getilen: $(VCD_DIR) test_getilen.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_getilen ..."
	$(VVP) test_getilen.vvp

run_ifu: $(VCD_DIR) test_ifu.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_ifu ..."
	$(VVP) test_ifu.vvp

run_exception: $(VCD_DIR) test_exception.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_exception ..."
	$(VVP) test_exception.vvp

run_atomic: $(VCD_DIR) test_atomic.vvp
	@echo "$(YELLOW)[RUN]$(NC) Simulating test_atomic ..."
	$(VVP) test_atomic.vvp

# ---- Combined Test Targets (compile + run) -----------------------------------
test_alu:      compile_alu  run_alu
test_decoder:  compile_decoder  run_decoder
test_regfile:  compile_regfile  run_regfile
test_ifu:      compile_ifu  run_ifu
test_exception: compile_exception  run_exception
test_atomic:   compile_atomic  run_atomic
test_getilen:  compile_getilen  run_getilen

# ---- Wave Viewer Targets -----------------------------------------------------
wave_alu: $(VCD_DIR)/test_alu.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_alu.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_alu.vcd &

wave_decoder: $(VCD_DIR)/test_decoder.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_decoder.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_decoder.vcd &

wave_regfile: $(VCD_DIR)/test_regfile.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_regfile.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_regfile.vcd &

wave_getilen: $(VCD_DIR)/test_getilen.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_getilen.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_getilen.vcd &

wave_ifu: $(VCD_DIR)/test_ifu.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_ifu.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_ifu.vcd &

wave_exception: $(VCD_DIR)/test_exception.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_exception.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_exception.vcd &

wave_atomic: $(VCD_DIR)/test_atomic.vcd
	@echo "$(GREEN)[WAVE]$(NC) Opening test_atomic.vcd in gtkwave ..."
	$(WAVES) $(VCD_DIR)/test_atomic.vcd &

# ---- Utilities ---------------------------------------------------------------
$(VCD_DIR):
	@mkdir -p $(VCD_DIR)

clean:
	@echo "$(RED)[CLEAN]$(NC) Removing generated files ..."
	@rm -rf *.vvp *.vcd $(VCD_DIR)

help:
	@echo ""
	@echo "$(CYAN)MISC-2000 Simulation Makefile$(NC)"
	@echo "============================================"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@echo "  all                  Compile and run all 7 testbenches"
	@echo ""
	@echo "  compile_alu          Compile test_alu only"
	@echo "  compile_decoder      Compile test_decoder only"
	@echo "  compile_regfile      Compile test_regfile only"
	@echo "  compile_ifu          Compile test_ifu only"
	@echo "  compile_exception    Compile test_exception only"
	@echo "  compile_atomic       Compile test_atomic only"
	@echo "  compile_getilen      Compile test_getilen only"
	@echo ""
	@echo "  run_alu              Run test_alu simulation"
	@echo "  run_decoder          Run test_decoder simulation"
	@echo "  run_regfile          Run test_regfile simulation"
	@echo "  run_ifu              Run test_ifu simulation"
	@echo "  run_exception        Run test_exception simulation"
	@echo "  run_atomic           Run test_atomic simulation"
	@echo "  run_getilen          Run test_getilen simulation"
	@echo ""
	@echo "  test_alu             Compile + run test_alu"
	@echo "  test_decoder         Compile + run test_decoder"
	@echo "  test_regfile         Compile + run test_regfile"
	@echo "  test_ifu             Compile + run test_ifu"
	@echo "  test_exception       Compile + run test_exception"
	@echo "  test_atomic          Compile + run test_atomic"
	@echo "  test_getilen         Compile + run test_getilen"
	@echo ""
	@echo "  wave_alu             Open test_alu.vcd in gtkwave"
	@echo "  wave_decoder         Open test_decoder.vcd in gtkwave"
	@echo "  wave_regfile         Open test_regfile.vcd in gtkwave"
	@echo "  wave_ifu             Open test_ifu.vcd in gtkwave"
	@echo "  wave_exception       Open test_exception.vcd in gtkwave"
	@echo "  wave_atomic          Open test_atomic.vcd in gtkwave"
	@echo "  wave_getilen         Open test_getilen.vcd in gtkwave"
	@echo ""
	@echo "  clean                Remove all generated files"
	@echo "  help                 Show this help message"
	@echo ""