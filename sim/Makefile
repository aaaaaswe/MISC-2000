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
        run_alu run_decoder run_regfile \
        test_alu test_decoder test_regfile \
        wave_alu wave_decoder wave_regfile \
        clean help

# ---- Top-Level Targets -------------------------------------------------------
all: $(VCD_DIR) test_alu test_decoder test_regfile
	@echo "$(GREEN)[DONE]$(NC) All 3 testbenches compiled and simulated successfully."

# ---- Compile Targets ---------------------------------------------------------
compile_alu: $(VCD_DIR) test_alu.vvp
compile_decoder: $(VCD_DIR) test_decoder.vvp
compile_regfile: $(VCD_DIR) test_regfile.vvp

test_alu.vvp: $(RTL_DIR)/alu.sv $(SIM_DIR)/test_alu.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_alu.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/alu.sv $(SIM_DIR)/test_alu.sv

test_decoder.vvp: $(RTL_DIR)/decoder.sv $(SIM_DIR)/test_decoder.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_decoder.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/decoder.sv $(SIM_DIR)/test_decoder.sv

test_regfile.vvp: $(RTL_DIR)/regfile.sv $(SIM_DIR)/test_regfile.sv $(RTL_SRCS)
	@echo "$(CYAN)[COMPILE]$(NC) Building test_regfile.vvp ..."
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(RTL_DIR)/regfile.sv $(SIM_DIR)/test_regfile.sv

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

# ---- Combined Test Targets (compile + run) -----------------------------------
test_alu:      compile_alu  run_alu
test_decoder:  compile_decoder  run_decoder
test_regfile:  compile_regfile  run_regfile

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
	@echo "  all                  Compile and run all 3 testbenches"
	@echo ""
	@echo "  compile_alu          Compile test_alu only"
	@echo "  compile_decoder      Compile test_decoder only"
	@echo "  compile_regfile      Compile test_regfile only"
	@echo ""
	@echo "  run_alu              Run test_alu simulation"
	@echo "  run_decoder          Run test_decoder simulation"
	@echo "  run_regfile          Run test_regfile simulation"
	@echo ""
	@echo "  test_alu             Compile + run test_alu"
	@echo "  test_decoder         Compile + run test_decoder"
	@echo "  test_regfile         Compile + run test_regfile"
	@echo ""
	@echo "  wave_alu             Open test_alu.vcd in gtkwave"
	@echo "  wave_decoder         Open test_decoder.vcd in gtkwave"
	@echo "  wave_regfile         Open test_regfile.vcd in gtkwave"
	@echo ""
	@echo "  clean                Remove all generated files"
	@echo "  help                 Show this help message"
	@echo ""