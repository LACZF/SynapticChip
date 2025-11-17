#!/bin/bash

TOP_DIR="$(realpath $(dirname $(readlink -f $0))/../)"
WORK_DIR="."
MODULE_NAME=""
BUILD_DIR=$WORK_DIR/build/$MODULE_NAME
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
	local start_time=$(date +%s%N)
	eval $cmd
	local ret_code=$?
	local end_time=$(date +%s%N)
	local duration=$(( ($end_time - $start_time) / 1000000 ))  # 转换为毫秒
	log DEBUG "run cmd($cmd) done, ret : $ret_code, duration: ${duration}ms."
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
	args+="\t RTL_SRC_DIR : $RTL_SRC_DIR.\n"
	args+="\t MODULE_NAME : $MODULE_NAME.\n"
	args+="\t BUILD_DIR   : $BUILD_DIR.\n"
	args+="\t SRC_DIR     : $SRC_DIR.\n"
	args+="\t LOG_DIR     : $LOG_DIR."
	echo -e "$args"
	echo -e "$args" >> $LOG_DIR/env.log
}

function parse_rtl_src() { # do_not_function_help
	local src=$1
	if [ "$RTL_SRC"x = ""x ]; then
		RTL_SRC_DIR="$(realpath $src)"
		src=$(basename $src)
		MODULE_NAME="${src%.v*}"
	fi

	if [[ -z "${MODULE_NAME}" ]]; then
		MODULE_NAME=${TOP_MODULE:-$(basename "${RTL_SRC_DIR}")}
	fi

	BUILD_DIR=$WORK_DIR/build/$MODULE_NAME
	SRC_DIR=$BUILD_DIR/src
	LOG_DIR=$BUILD_DIR/log

	env_log
}

function prepare() { # RTL_SRC_DIR
	local src=$1
	local f=""

	log DEBUG "Parse rtl src start."
	parse_rtl_src $src

	if [ ! "$RTL_SRC"x = ""x ]; then
		mkdir -p $SRC_DIR
		cp -f $RTL_SRC $SRC_DIR
		echo -e "RTL_SRC : $RTL_SRC" >> $LOG_DIR/filelist.log
		return
	fi

	if [ "$src"x = ""x ]; then
		echo "Input RTL_SRC_DIR, please."
		help 1
	fi

	if [ ! -f $src -a ! -d $src ]; then
		echo "RTL_SRC_DIR($src) is not file or dir."
		help 1
	fi

	if [ "$MODULE_NAME"x = ""x ]; then
		echo "Known MODULE_NAME."
		help 1
	fi

	mkdir -p $SRC_DIR

	if [ -f $RTL_SRC_DIR ]; then
		cp -f $RTL_SRC_DIR $SRC_DIR
		return
	fi

	for f in $(find $RTL_SRC_DIR/ -name "*.v" -o -name "*.sv" -o -name "*.h");
	do
		if contain_key $(basename $f) $EXCEPT_LIST;
		then
			continue
		fi
		cp -f $f $SRC_DIR
	done
}

function process_rtl_all_file() {
	local rtl_all=$1
	if [ -f $rtl_all ]; then
		local temp_non_module="$SRC_DIR/../temp_non_module.sv"
		local temp_module="$SRC_DIR/../temp_module.sv"
		local temp_rtl_all="$SRC_DIR/../temp_rtl_all.sv"
		> $temp_non_module
		> $temp_module
		> $temp_rtl_all
		local in_module=0
		local block_comment=0
		while IFS= read -r line || [ -n "$line" ]; do
			if [[ -z "$line" ]]; then
				continue
			fi
			if [ $block_comment -eq 1 ]; then
				if [[ $line == *"*/"* ]]; then
					block_comment=0
					line=${line#*"*/"}
				else
					continue
				fi
			fi
			if [[ $line == *"/*"* ]]; then
				block_comment=1
				before_comment=${line%%"/*"*}
				if [[ $line == *"*/"* ]]; then
					block_comment=0
					after_comment=${line#*"*/"}
					line="$before_comment$after_comment"
				else
					line="$before_comment"
				fi
			fi
			if [[ $line == *"//"* ]]; then
				line=${line%%"//"*}
			fi
			if [[ -z "$line" ]]; then
				continue
			fi
			if [[ $line == *"module"* && $line != *"endmodule"* ]]; then
				in_module=1
				echo "$line" >> $temp_module
			elif [[ $line == *"endmodule"* ]]; then
				echo "$line" >> $temp_module
				in_module=0
			else
				if [ $in_module -eq 0 ]; then
					echo "$line" >> $temp_non_module
				else
					echo "$line" >> $temp_module
				fi
			fi
		done < $rtl_all
		cat $temp_non_module >> $temp_rtl_all
		cat $temp_module >> $temp_rtl_all
		mv $temp_rtl_all $rtl_all
		rm -f $temp_non_module $temp_module
	fi
}

function gen_read_verilog_ys() {
	local script=$1
	local f=""
	rm -f $script
	local args=""
	local filelist="$SRC_DIR/filelist.f"
	local rtl_all="$SRC_DIR/../rtl_all.sv"
	if [ "$READ_RTL_ARGS"x != ""x ]; then
		args+=" $READ_RTL_ARGS"
	fi
	> $filelist
	> $rtl_all
	args+=" -I$SRC_DIR"
	args+=" --top $TOP_MODULE"
	# args+=" -keep-hierarchy --compat=vcs --ignore-assertions --no-implicit-memories"

	# 使用slang命令读取SystemVerilog文件
	local sv_files=""
	local v_files=""

	echo "plugin -i slang" >> $script
	# 分离.sv和.v文件
	for f in $(ls $SRC_DIR/*.sv 2>/dev/null); do
		sv_files+=" $SRC_DIR/$(basename $f)"
		echo "$(basename $f)" >> $filelist
	done

	for f in $(ls $SRC_DIR/*.v 2>/dev/null); do
		v_files+=" $SRC_DIR/$(basename $f)"
		echo "$(basename $f)" >> $filelist
	done

	echo "read_slang $args $sv_files $v_files" >> $script

	# 合并所有文件用于后续处理
	for f in $(ls $SRC_DIR/*.v $SRC_DIR/*.sv 2>/dev/null);
	do
		grep -v "include" $f >> $rtl_all
	done
	process_rtl_all_file $rtl_all
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
	if [ "$NETLIST2SVG"x = "1"x ]; then
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

	log DEBUG "do_synth_behave for $RTL_SRC_DIR start."
	run_cmd $YOSYS $script 2>$LOG_DIR/$sub_prefix.yosys.err.log 1>$LOG_DIR/$sub_prefix.yosys.output.log
	dot2png "$prefix.dot" "$prefix.png" 2>$LOG_DIR/$sub_prefix.dot2png.err.log 1>$LOG_DIR/$sub_prefix.dot2png.output.log
	dot2svg "$prefix.dot" "$prefix.svg" 2>$LOG_DIR/$sub_prefix.dot2svg.err.log 1>$LOG_DIR/$sub_prefix.dot2svg.output.log
	do_netlistsvg $prefix.json -o $prefix.netlist2svg.svg 2>$LOG_DIR/$sub_prefix.netlist2svg.err.log 1>$LOG_DIR/$sub_prefix.netlist2svg.output.log
	log DEBUG "do_synth_behave for $RTL_SRC_DIR done."
}

function do_synth_rtl() {
	local sub_prefix=${MODULE_NAME}_rtl
	local prefix=$BUILD_DIR/$sub_prefix
	local script=$prefix.ys
	local top=$(get_vulue "-top " "" "$TOP_MODULE")

	gen_read_verilog_ys $script

	cat >> $script << EOF
read_verilog -lib $WORK_DIR/lib/cells.v

synth $top
dfflibmap -liberty $WORK_DIR/lib/cells.lib
abc -liberty $WORK_DIR/lib/cells.lib
opt_clean

stat -liberty $WORK_DIR/lib/cells.lib

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

	log DEBUG "do_synth_rtl for $RTL_SRC_DIR start."
	run_cmd $YOSYS $script 2>$LOG_DIR/$sub_prefix.yosys.err.log 1>$LOG_DIR/$sub_prefix.yosys.output.log
	dot2png "$prefix.dot" "$prefix.png" 2>$LOG_DIR/$sub_prefix.dot2png.err.log 1>$LOG_DIR/$sub_prefix.dot2png.output.log
	dot2svg "$prefix.dot" "$prefix.svg" 2>$LOG_DIR/$sub_prefix.dot2svg.err.log 1>$LOG_DIR/$sub_prefix.dot2svg.output.log
	do_netlistsvg $prefix.json -o $prefix.netlist2svg.svg 2>$LOG_DIR/$sub_prefix.netlist2svg.err.log 1>$LOG_DIR/$sub_prefix.netlist2svg.output.log
	log DEBUG "do_synth_rtl for $RTL_SRC_DIR done."
}

function synth_behave() { # RTL_SRC_DIR
	prepare $@
	do_synth_behave
}

function synth_rtl() { # RTL_SRC_DIR
	prepare $@
	do_synth_rtl
}

function synth() { # RTL_SRC_DIR
	prepare $@
	do_synth_behave
	do_synth_rtl
}

function env_list { # do_not_function_help
	echo -e "ENV list:"
	echo -e "\t export EXCEPT_LIST=\"chip_top_test.v\""
	echo -e "\t export TOP_MODULE=\"chip_top\""
	echo -e "\t export READ_RTL_ARGS=\"-I$WORK_DIR/rtl/\""
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