
IVERILOG ?= $(shell which iverilog)
VVP ?= $(shell which vvp)
TOP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
SCRIPT_DIR := $(TOP_DIR)/scripts

ifeq ($(V),1)
QUITE :=
else
QUITE := @
endif

ifneq (,$(filter test,$(MAKECMDGOALS)))
include $(TOP_DIR)/rtl/filelist.txt
ifeq ($(M),)
$(error "M is not set.")
else
ABS_M := $(abspath $(M))
ifneq (,$(wildcard $(M)/makefile.txt))
include $(M)/makefile.txt
else ifeq ($(shell test -f $(M) && echo yes),yes)
include $(M)
else
TEST_TARGET := $(shell basename $(M))
TEST_ARGS ?= -g2012
ifeq ($(shell test -d $(M) && echo "directory" || echo "not-directory"),directory)
TEST_SRC += $(wildcard $(ABS_M)/*.v)
TEST_INCLUDE_DIR += -I$(ABS_M)
else
TEST_SRC += $(ABS_M)
TEST_INCLUDE_DIR += -I$(shell dirname $(ABS_M))
endif
endif
TEST_BUILD_DIR := $(TOP_DIR)/build/$(patsubst %/,%,$(M)).build
COMPLETE_TEST_TARGET := $(TEST_BUILD_DIR)/$(TEST_TARGET)
endif
endif

ifneq (,$(filter yosys_synthesis,$(MAKECMDGOALS)))
ifeq ($(M),)
M=$(TOP_DIR)/rtl
include $(TOP_DIR)/rtl/filelist.txt
TOP_MODULE_ARG := TOP_MODULE=chip_top
$(warning "M is not set, synth for $(M).")
else ifeq ($(TOP_MODULE),)
$(warning "TOP_MODULE is not set.")
TOP_MODULE_ARG :=
else
TOP_MODULE_ARG := TOP_MODULE=$(TOP_MODULE)
endif
endif

ifeq ($(DEBUG),1)
TEST_ARGS += -D DEBUG=1
endif

.PHONY: test $(COMPLETE_TEST_TARGET) yosys_synthesis top_yosys_synthesis

default: help

TEST_ARGS += $(APPEND_ARGS)
$(COMPLETE_TEST_TARGET):
	$(QUITE)echo "test : $(M)"
	$(QUITE)mkdir -p $(TEST_BUILD_DIR)
	$(QUITE)if [ -d $(ABS_M) ]; then \
			cp -rf $(ABS_M)/* $(TEST_BUILD_DIR); \
		else \
			cp -rf $(shell dirname $(ABS_M))/* $(TEST_BUILD_DIR); \
		fi
	$(QUITE)cd $(TEST_BUILD_DIR) && $(IVERILOG) -o $(COMPLETE_TEST_TARGET) \
		$(TEST_ARGS) $(TEST_INCLUDE_DIR) $(TEST_SRC)

$(COMPLETE_TEST_TARGET).vvp: $(COMPLETE_TEST_TARGET)
	$(QUITE)cd $(TEST_BUILD_DIR) && \
		$(VVP) $(COMPLETE_TEST_TARGET) -l $(COMPLETE_TEST_TARGET).log

test: $(COMPLETE_TEST_TARGET).vvp

it_list:
	$(QUITE)cd $(TOP_DIR) && for M in $(shell grep -r 'TEST_TARGET := ' test/it | awk -F: '{print $$1}'); do \
		echo "make test M=$$M"; \
	done

all_it:
	$(QUITE)cd $(TOP_DIR) && for M in $(shell grep -r 'TEST_TARGET := ' test/it | awk -F: '{print $$1}'); do \
		make test M=$$M || exit 1; \
	done

ut_list:
	$(QUITE)cd $(TOP_DIR) && for M in $(shell grep -r 'TEST_TARGET := ' test/ut | awk -F: '{print $$1}'); do \
		echo "make test M=$$M"; \
	done

test_list: ut_list it_list

all_ut:
	$(QUITE)cd $(TOP_DIR) && for M in $(shell grep -r 'TEST_TARGET := ' test/ut | awk -F: '{print $$1}'); do \
		make test M=$$M || exit 1; \
	done

all_test: all_ut all_it
	$(QUITE)echo "All tests done."

# YOSYS_ENV ?= OUTPUT_SVG=1
yosys_synthesis:
	$(QUITE)READ_RTL_ARGS="$(READ_RTL_ARGS) -I$(shell realpath $$(dirname $(M)))" \
		RTL_SRC_DIR="$(RTL_SRC_DIR)" MODULE_NAME="$(MODULE_NAME)" RTL_SRC="$(RTL_SRC)" \
		$(YOSYS_ENV) $(TOP_MODULE_ARG) $(SCRIPT_DIR)/yosys.sh synth $(M)

patch_save:
	$(QUITE)cd $(TOP_DIR) && $(SCRIPT_DIR)/tools.sh gen_top_patch

patch_apply:
	$(QUITE)cd $(TOP_DIR) && $(SCRIPT_DIR)/tools.sh top_patch_apply

patch_revert:
	$(QUITE)cd $(TOP_DIR) && $(SCRIPT_DIR)/tools.sh top_patch_revert

all:
	$(QUITE)echo "Start ut."
	make -C $(TOP_DIR) all_ut
	$(QUITE)echo "ut done."
	$(QUITE)echo "Start it."
	make -C $(TOP_DIR) all_it
	$(QUITE)echo "it done."
	$(QUITE)echo "Start yosys synthesis."
	make -C $(TOP_DIR) yosys_synthesis
	$(QUITE)echo "yosys synthesis done."
	$(QUITE)echo "All done."

help:
	@echo "Usage: make [target] [options]"
	@echo "\t Targets:"
	@grep -E '^[a-zA-Z_-]+:' $(THIS_MAKEFILE) | \
		awk 'BEGIN {FS = ":"}; {printf "\t\t %s\n", $$1}'
