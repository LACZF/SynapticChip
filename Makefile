
INSTALL_PATH ?= /Volumes/work/git/digital_chip_script/output/darwin24
IVERILOG ?= $(INSTALL_PATH)/bin/iverilog
VVP ?= $(INSTALL_PATH)/bin/vvp
TOP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifeq ($(V),1)
QUITE :=
else
QUITE := @
endif

ifneq (,$(filter test,$(MAKECMDGOALS)))
ifeq ($(M),)
$(error M is not set.)
else
include $(M)/makefile.txt
TEST_BUILD_DIR := $(TOP_DIR)/build/$(M)
UT_TARGET := $(TEST_BUILD_DIR)/$(TEST_TARGET)
endif
endif

.PHONY: test $(UT_TARGET)

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

test: $(UT_TARGET).vvp

yosys_synthesis:
	TOP_MODULE=top_system $(TOP_DIR)/yosys.sh synth rtl

help:
	@echo "Usage: make [target] [options]"
	@echo "\t Targets:"
	@grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":"}; {printf "\t\t %s\n", $$1}'
