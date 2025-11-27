#!/bin/bash

TOP_DIR="$(dirname $(readlink -f $0))"
INSTALL_PATH=$TOP_DIR/output/$OSTYPE

function get_vulue() { # do_not_function_help
	local prefix="$1"
	local default_value="$2"
	local value="$3"
	if [ "$value"x = ""x ]; then
		echo "$default_value"
	else
		echo "$prefix$value"
	fi
}

function run_cmd() { # do_not_function_help
	local cmd="$@"

	echo "$cmd"
	eval $cmd
}

function contain_key() { # do_not_function_help
	local key="$1"
	shift
	local keys="$@"

	local k=""
	for k in $keys;
	do
		if [ "$k"x = "$key"x ]; then
			return 0
		fi
	done

	return 1
}

# Compile the gds dependency synthesis command.
OPENROAD_DIR=$TOP_DIR/OpenROAD-flow-scripts
OPENROAD_INSTALL_DIR=$INSTALL_PATH
OPENROAD_EXE=$OPENROAD_INSTALL_DIR/OpenROAD/bin/openroad
YOSYS_EXE=$OPENROAD_INSTALL_DIR/yosys/bin/yosys
DEFAULT_DESIGN=$TOP_DIR/OpenRoad_designs/AZPRcpu/config.mk
KLAYOUT_BIN_DIR=/Applications/klayout.app/Contents/MacOS

function openroad_flow() { # [DESIGN(eg. OpenRoad_designs/AZPRcpu/config.mk)] [ARGS]
	local design=$(get_vulue "" "$DEFAULT_DESIGN" "$1")
	shift
	design=$(realpath $design)
	local default_args=""
	local args=$@

	if [[ "$OSTYPE" == "darwin"* ]]; then
		export QT_QPA_PLATFORM=cocoa
	fi

	default_args+=" OPENROAD_EXE=$OPENROAD_EXE"
	default_args+=" YOSYS_EXE=$YOSYS_EXE"
	default_args+=" KLAYOUT_CMD=$KLAYOUT_BIN_DIR/klayout"
	default_args+=" PROJECT_TOP_DIR=$TOP_DIR"
	default_args+=" DESIGN_CONFIG=$design"

	make -C $OPENROAD_DIR/flow/ $default_args $args
}

function compile_gds() { # [DESIGN(eg. OpenRoad_designs/AZPRcpu/config.mk)]
	openroad_flow $1
}

function gds_gui_final() { # [DESIGN(eg. OpenRoad_designs/AZPRcpu/config.mk)]
	openroad_flow $1 gui_final
}

function gds_clean() { # [DESIGN(eg. OpenRoad_designs/AZPRcpu/config.mk)]
	openroad_flow $1 clean_all
}

default_cmd="help"

function help() {
	local ret=$(get_vulue "" 0 $1)
	echo "$0 CMD [PARAMETER]"
	echo "Optional commands :"
	grep '^function ' $0 | grep -v 'do_not_function_help' | \
		sed -e 's/(//g' -e 's/)//g' -e 's/^function //' -e 's/{/ /' -e 's/#//' | \
		awk '{out=$1; for(i=2;i<=NF;i++){out=out" "$i}; print "\t"out}'
	exit $ret
}

function is_function() { # do_not_function_help
	local type=$(type -t $1 2>/dev/null)
	if [ "function"x = "$type"x ]; then
		return 0
	fi
	return 1
}

if is_function $1; then
	$@
else
	$default_cmd $@
fi
