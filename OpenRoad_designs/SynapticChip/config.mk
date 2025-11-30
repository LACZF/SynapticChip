export PLATFORM               = sky130hd

export DESIGN_NICKNAME        = SynapticChip
export DESIGN_NAME            = SynapticChip

# PROJECT_TOP_DIR is a manually set environment variable.
export PROJECT_DESIGNS_DIR    = $(PROJECT_TOP_DIR)/OpenRoad_designs/$(DESIGN_NICKNAME)/
export PROJECT_VERILOG_SRC   ?= $(PROJECT_TOP_DIR)/build/$(DESIGN_NICKNAME)/src
export VERILOG_FILES          = $(sort $(wildcard $(PROJECT_VERILOG_SRC)/*.v)) $(sort $(wildcard $(PROJECT_VERILOG_SRC)/*.sv))

export VERILOG_INCLUDE_DIRS   = $(PROJECT_VERILOG_SRC)

export SYNTH_HDL_FRONTEND     = slang

export SDC_FILE               = $(PROJECT_DESIGNS_DIR)/constraint.sdc

export CORE_UTILIZATION = 45
export PLACE_DENSITY_LB_ADDON = 0.25
export TNS_END_PERCENT = 100

export REMOVE_ABC_BUFFERS = 1

export CTS_CLUSTER_SIZE = 20
export CTS_CLUSTER_DIAMETER = 50

export SYNTH_MEMORY_MAX_BITS  = 26214400
