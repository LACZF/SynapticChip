export PLATFORM               = sky130hd
# export PLATFORM               = asap7

export DESIGN_NICKNAME        = SynapticChip
export DESIGN_NAME            = SynapticChip

# PROJECT_TOP_DIR is a manually set environment variable.
export PROJECT_DESIGNS_DIR    = $(PROJECT_TOP_DIR)/OpenRoad_designs/$(DESIGN_NICKNAME)/
export PROJECT_VERILOG_SRC   ?= $(PROJECT_TOP_DIR)/build/$(DESIGN_NICKNAME)/src
export VERILOG_FILES          = $(sort $(wildcard $(PROJECT_VERILOG_SRC)/*.v)) $(sort $(wildcard $(PROJECT_VERILOG_SRC)/*.sv))

export VERILOG_INCLUDE_DIRS   = $(PROJECT_VERILOG_SRC)

export SYNTH_HDL_FRONTEND     = slang

export SDC_FILE               = $(PROJECT_DESIGNS_DIR)/constraint.sdc

export CORE_UTILIZATION       = 40
export CORE_ASPECT_RATIO      = 1
export CORE_MARGIN            = 2
export PLACE_DENSITY_LB_ADDON = 0.20

export ENABLE_DPO             = 0

export TNS_END_PERCENT        = 100
export SYNTH_MEMORY_MAX_BITS  = 26214400
