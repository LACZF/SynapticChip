
INSTALL_PATH ?= /Volumes/work/git/digital_chip_script/output/darwin24
IVERILOG ?= $(INSTALL_PATH)/bin/iverilog
VVP ?= $(INSTALL_PATH)/bin/vvp
TOP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifeq ($(V),1)
QUITE :=
else
QUITE := @
endif

.PHONY: test $(UT_TARGET) yosys_synthesis top_yosys_synthesis

default: help

all_ut:
	$(QUIET)cd $(TOP_DIR) && for M in $(shell find test/ut -name makefile.txt | xargs dirname); do \
		make test M=$$M; \
	done

$(UT_TARGET):
	$(QUIET)echo "test : $(M)"
	$(QUIET)mkdir -p $(TEST_BUILD_DIR)
	$(QUIET)cp -rf $(M)/* $(TEST_BUILD_DIR)
	$(QUIET)cd $(TEST_BUILD_DIR) && $(IVERILOG) -o $(UT_TARGET) $(TEST_ARGS) \
		$(TEST_INCLUDE_DIR) $(TEST_SRC)

$(UT_TARGET).vvp: $(UT_TARGET)
	$(QUIET)cd $(TEST_BUILD_DIR) && ($(VVP) $(UT_TARGET) > $(UT_TARGET).log)

ifneq (,$(filter test,$(MAKECMDGOALS)))
ifeq ($(M),)
$(error "M is not set.")
else
include $(M)/makefile.txt
TEST_BUILD_DIR := $(TOP_DIR)/build/$(M)
UT_TARGET := $(TEST_BUILD_DIR)/$(TEST_TARGET)
endif
endif

test: $(UT_TARGET).vvp

ifneq (,$(filter yosys_synthesis,$(MAKECMDGOALS)))
ifeq ($(M),)
M=$(TOP_DIR)/rtl
TOP_MODULE_ARG := TOP_MODULE=top_system
$(warning "M is not set, synth for $(M).")
endif
ifeq ($(TOP_MODULE),)
$(warning "TOP_MODULE is not set.")
TOP_MODULE_ARG :=
else
TOP_MODULE_ARG := TOP_MODULE=$(TOP_MODULE)
endif
endif
yosys_synthesis:
	READ_RTL_ARGS="$(READ_RTL_ARGS) -I$(shell realpath $$(dirname $(M)))" \
		$(TOP_MODULE_ARG) $(TOP_DIR)/yosys.sh synth $(M)

help:
	@echo "Usage: make [target] [options]"
	@echo "\t Targets:"
	@grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":"}; {printf "\t\t %s\n", $$1}'
