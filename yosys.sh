#!/bin/bash

TOP_DIR="$(dirname $(readlink -f $0))"
RTL_SRC=""
MODULE_NAME=""
BUILD_DIR=$TOP_DIR/build/$MODULE_NAME
SRC_DIR=$BUILD_DIR/src
LOG_DIR=$BUILD_DIR/log
YOSYS=${YOSYS:-$(which yosys)}

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

function log() { # do_not_function_help
	local level=$1
	shift
	echo -e "[$(date "+%Y-%m-%d %H:%M:%S.%3N")][$level] $@" >> $(tty)
}

function run_cmd() { # do_not_function_help
	local cmd="$@"

	log DEBUG "run : $cmd."
	eval $cmd
	log DEBUG "run cmd($cmd) done, ret : $?."
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

function env_log() { # do_not_function_help
	local args=""

	rm -rf $BUILD_DIR/*
	mkdir -p $LOG_DIR

	args+="ENV list:\n"
	args+="\t export EXCEPT_LIST=\"$EXCEPT_LIST\"\n"
	args+="\t export TOP_MODULE=\"$TOP_MODULE\"\n"
	args+="\t export READ_RTL_ARGS=\"$READ_RTL_ARGS\"\n"
	args+="\t export OUTPUT_PNG=$OUTPUT_PNG\n"
	args+="\t export OUTPUT_SVG=$OUTPUT_SVG\n"
	args+="\t export OUTPUT_PS=$OUTPUT_PS\n"
	args+="\t export NETLIST2SVG=$NETLIST2SVG\n"
	args+="Parse result:\n"
	args+="\t RTL_SRC     : $RTL_SRC.\n"
	args+="\t MODULE_NAME : $MODULE_NAME.\n"
	args+="\t BUILD_DIR   : $BUILD_DIR.\n"
	args+="\t SRC_DIR     : $SRC_DIR.\n"
	args+="\t LOG_DIR     : $LOG_DIR."
	echo -e "$args"
	echo -e "$args" >> $LOG_DIR/env.log
}

function parse_rtl_src() { # do_not_function_help
	local src=$1
	RTL_SRC="$(realpath $src)"
	src=$(basename $src)
	MODULE_NAME="${src%.v*}"
	BUILD_DIR=$TOP_DIR/build/$MODULE_NAME
	SRC_DIR=$BUILD_DIR/src
	LOG_DIR=$BUILD_DIR/log

	env_log
}

function prepare() { # RTL_SRC
	local src=$1
	local f=""

	if [ "$src"x = ""x ]; then
		echo "Input RTL_SRC, please."
		help 1
	fi

	if [ ! -f $src -a ! -d $src ]; then
		echo "RTL_SRC($src) is not file or dir."
		help 1
	fi

	log DEBUG "Parse rtl src start."
	parse_rtl_src $src

	if [ "$MODULE_NAME"x = ""x ]; then
		echo "Known MODULE_NAME."
		help 1
	fi

	mkdir -p $SRC_DIR

	if [ -f $RTL_SRC ]; then
		cp -f $RTL_SRC $SRC_DIR
		return
	fi

	for f in $(find $RTL_SRC/ -name "*.v" -o -name "*.h");
	do
		if contain_key $(basename $f) $EXCEPT_LIST; then
			continue
		fi
		cp -f $f $SRC_DIR
	done
}

function gen_read_verilog_ys() { # do_not_function_help
	local script=$1
	local f=""
	rm -f $script
	local args=""

	if [ "$READ_RTL_ARGS"x != ""x ]; then
		args+=" $READ_RTL_ARGS"
	fi

	args+=" -I$SRC_DIR"
	for f in $(ls $SRC_DIR/*.v);
	do
		echo "read_verilog $args $f" >> $script
	done
}

function dot2png() { # do_not_function_help
	local input=$1
	local output=$2

	if [ "$OUTPUT_PNG"x = "1"x ]; then
		run_cmd dot -Tpng -o $output $input
	fi
}

function dot2svg() { # do_not_function_help
	local input=$1
	local output=$2

	if [ "$OUTPUT_SVG"x = "1"x ]; then
		run_cmd dot -Tsvg -o $output $input
	fi
}

function do_netlistsvg() { # do_not_function_help
	if [ ! "$NETLIST2SVG"x = "0"x ]; then
		run_cmd netlistsvg $@ 2>/dev/null 1>/dev/null
	fi
}

function do_synth_behave() {
	local sub_prefix=${MODULE_NAME}_behave
	local prefix=$BUILD_DIR/$sub_prefix
	local script=$prefix.ys
	local top=$(get_vulue "-top " "" "$TOP_MODULE")

	gen_read_verilog_ys $script

	cat >> $script << EOF
# synth $top
hierarchy -check $top

# Convert high-level behavioral parts to DFFs and muxes
proc

# Perform some simple optimizations
opt

# Convert design to gate-level netlists from an internal library
techmap

# Perform some simple optimizations
opt

# Use ABC to map cells to the target technology
abc

# Cleanup
opt

stat $top

# Write results to output file
write_verilog $prefix.v
# write_spice $prefix.sp
show -format dot -prefix $prefix
write_json $prefix.json
EOF
	if [ "$OUTPUT_PS"x = "1"x ]; then
		echo "show -format ps -prefix $prefix" >> $script
	fi

	log DEBUG "do_synth_behave for $RTL_SRC start."
	run_cmd $YOSYS $script 2>$LOG_DIR/$sub_prefix.yosys.err.log 1>$LOG_DIR/$sub_prefix.yosys.output.log
	dot2png "$prefix.dot" "$prefix.png" 2>$LOG_DIR/$sub_prefix.dot2png.err.log 1>$LOG_DIR/$sub_prefix.dot2png.output.log
	dot2svg "$prefix.dot" "$prefix.svg" 2>$LOG_DIR/$sub_prefix.dot2svg.err.log 1>$LOG_DIR/$sub_prefix.dot2svg.output.log
	do_netlistsvg $prefix.json -o $prefix.netlist2svg.svg 2>$LOG_DIR/$sub_prefix.netlist2svg.err.log 1>$LOG_DIR/$sub_prefix.netlist2svg.output.log
	log DEBUG "do_synth_behave for $RTL_SRC done."
}

function do_synth_rtl() {
	local sub_prefix=${MODULE_NAME}_rtl
	local prefix=$BUILD_DIR/$sub_prefix
	local script=$prefix.ys
	local top=$(get_vulue "-top " "" "$TOP_MODULE")

	gen_read_verilog_ys $script

	cat >> $script << EOF
read_verilog -lib $TOP_DIR/lib/cells.v

synth $top
dfflibmap -liberty $TOP_DIR/lib/cells.lib
abc -liberty $TOP_DIR/lib/cells.lib
opt_clean

stat -liberty $TOP_DIR/lib/cells.lib

# http://vlsiarch.ecen.okstate.edu/flows/MOSIS_SCMOS/latest/cadence/lib/tsmc025/signalstorm/osu025_stdcells.lib
# dfflibmap -liberty osu025_stdcells.lib
# abc -liberty osu025_stdcells.lib;;

stat $top

write_verilog $prefix.v
write_spice $top $prefix.sp
show -format dot -prefix $prefix
write_json $prefix.json
EOF
	if [ "$OUTPUT_PS"x = "1"x ]; then
		echo "show -format ps -prefix $prefix" >> $script
	fi

	log DEBUG "do_synth_rtl for $RTL_SRC start."
	run_cmd $YOSYS $script 2>$LOG_DIR/$sub_prefix.yosys.err.log 1>$LOG_DIR/$sub_prefix.yosys.output.log
	dot2png "$prefix.dot" "$prefix.png" 2>$LOG_DIR/$sub_prefix.dot2png.err.log 1>$LOG_DIR/$sub_prefix.dot2png.output.log
	dot2svg "$prefix.dot" "$prefix.svg" 2>$LOG_DIR/$sub_prefix.dot2svg.err.log 1>$LOG_DIR/$sub_prefix.dot2svg.output.log
	do_netlistsvg $prefix.json -o $prefix.netlist2svg.svg 2>$LOG_DIR/$sub_prefix.netlist2svg.err.log 1>$LOG_DIR/$sub_prefix.netlist2svg.output.log
	log DEBUG "do_synth_rtl for $RTL_SRC done."
}

function synth_behave() { # RTL_SRC
	prepare $@
	do_synth_behave
}

function synth_rtl() { # RTL_SRC
	prepare $@
	do_synth_rtl
}

function synth() { # RTL_SRC
	prepare $@
	do_synth_behave
	do_synth_rtl
}

function env_list { # do_not_function_help
	echo -e "ENV list:"
	echo -e "\t export EXCEPT_LIST=\"chip_top_test.v\""
	echo -e "\t export TOP_MODULE=\"chip_top\""
	echo -e "\t export READ_RTL_ARGS=\"-I$TOP_DIR/rtl/\""
	echo -e "\t export OUTPUT_PNG=0|1"
	echo -e "\t export OUTPUT_SVG=0|1"
	echo -e "\t export OUTPUT_PS=0|1"
	echo -e "\t export NETLIST2SVG=0|1"
}

default_cmd="help"

function help() {
	local ret=$(get_vulue 0 $1)
	echo "$0 CMD [PARAMETER]"
	echo "Optional commands :"
	grep '^function ' $0 | grep -v 'do_not_function_help' | \
		sed -e 's/(//g' -e 's/)//g' -e 's/^function //' -e 's/{/ /' -e 's/#//' | \
		awk '{out=$1; for(i=2;i<=NF;i++){out=out" "$i}; print "\t"out}'
	env_list
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
