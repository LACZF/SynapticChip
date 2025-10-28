#!/bin/bash

TOP_DIR="$(dirname $(readlink -f $0))"

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

function make_top() { # [ARGS]
	local args="$@"
	local env=""

	env+=" IVERILOG=/Volumes/work/git/digital_chip_script/output/darwin24/bin/iverilog"
	env+=" VVP=/Volumes/work/git/digital_chip_script/output/darwin24/bin/vvp"
	env+=" YOSYS=/Volumes/work/git/digital_chip_script/output/darwin24/yosys/bin/yosys"
	eval $env make -C $TOP_DIR $args
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
