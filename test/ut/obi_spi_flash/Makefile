# SPI OBI Core Test Makefile

CUR_DIR := $(shell pwd)

# Test target
TEST_TARGET := spi_obi_core_tb

# Test arguments
TEST_ARGS := -g2005-sv

# Source files
TEST_SRC := \
	spi_obi_core_tb.sv \
	spi_obi_core.sv \
	spi_obi_if.sv \
	w25q128jvxim.sv

# Include directories
TEST_INCLUDE_DIR := \
	-I../../../ \
	-I../../../clusterip/spi/rtl \
	-I../../../clusterip/spi/model

# Source file paths
TEST_SRC_FILES := \
	spi_obi_core_tb.sv \
	../../../rtl/io/spi_flash/spi_obi_core.sv \
	../../../rtl/io/spi_flash/spi_obi_if.sv \
	../../../clusterip/spi/model/w25q128jvxim.sv

# Additional source files from SPI module
SPI_SRC_FILES := \
	../../../clusterip/spi/rtl/spi_fifo.sv \
	../../../clusterip/spi/rtl/spi_ctrl.sv \
	../../../clusterip/spi/rtl/spi_tx.sv \
	../../../clusterip/spi/rtl/spi_rx.sv \
	../../../clusterip/spi/rtl/spi_clkgen.sv

# Flash model initialization files
POST_COPY_FILES := \
	$(CUR_DIR)/MEM.TXT \
	$(CUR_DIR)/SECSI.TXT \
	$(CUR_DIR)/SFDP.TXT \
	$(CUR_DIR)/SREG.TXT

# Default target
all: compile run

# Compile the test
compile:
	@echo "Compiling SPI OBI Core test..."
	@mkdir -p $(CUR_DIR)/build
	@cp $(POST_COPY_FILES) $(CUR_DIR)/build/ 2>/dev/null || true
	/Volumes/work/git/digital_chip_script/output/darwin24/bin/iverilog $(TEST_ARGS) $(TEST_INCLUDE_DIR) $(TEST_SRC_FILES) $(SPI_SRC_FILES) -o $(CUR_DIR)/build/$(TEST_TARGET).vvp

# Run the test
run:
	@echo "Running SPI OBI Core test..."
	cd $(CUR_DIR)/build && \
	vvp $(TEST_TARGET).vvp

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(CUR_DIR)/build

# Help target
help:
	@echo "Available targets:"
	@echo "  all     - Compile and run the test (default)"
	@echo "  compile - Compile the test only"
	@echo "  run     - Run the compiled test"
	@echo "  clean   - Clean build artifacts"
	@echo "  help    - Show this help message"

.PHONY: all compile run clean help