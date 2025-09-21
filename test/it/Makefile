
INSTALL_PATH ?= /Volumes/work/git/digital_chip_script/output/darwin24
IVERILOG ?= $(INSTALL_PATH)/bin/iverilog
VVP ?= $(INSTALL_PATH)/bin/vvp
CUR_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TOP_DIR := $(CUR_DIR)/../../
SRC_DIR := $(TOP_DIR)/rtl/
BUILD_DIR ?= $(TOP_DIR)/build/it/
SRC := $(shell find $(SRC_DIR) -name "*.v")

.PHONY: compile
default: compile

env:
	@echo "INSTALL_PATH : $(INSTALL_PATH)"
	@echo "IVERILOG     : $(IVERILOG)"
	@echo "VVP          : $(VVP)"
	@echo "CUR_DIR      : $(CUR_DIR)"
	@echo "TOP_DIR      : $(TOP_DIR)"
	@echo "SRC_DIR      : $(SRC_DIR)"
	@echo "BUILD_DIR    : $(BUILD_DIR)"
	@echo "SRC          : $(SRC)"

compile:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp -f $(SRC) $(BUILD_DIR)
	$(IVERILOG) -o $(BUILD_DIR)/top_system -I $(BUILD_DIR)\
		$(SRC) $(CUR_DIR)/tb_top_system.v
	$(VVP) $(BUILD_DIR)/top_system > $(BUILD_DIR)/top_system.log
