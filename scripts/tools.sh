#!/bin/bash

TOP_DIR="$(dirname $(readlink -f $0))"
REPO_DIR=$(realpath $TOP_DIR/..)

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

    if [ ! "$RUN_DIR"x = ""x ]; then
        cd $RUN_DIR
    fi

	echo "$cmd"
	eval $cmd

    if [ ! "$RUN_DIR"x = ""x ]; then
        cd - 2>/dev/null
    fi
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

function log() { # do_not_function_help
	if [ "$VERBOSE"x = "1"x ]; then
		echo "[$(date +%Y-%m-%d:%H:%M:%S)] $@"
	fi
}

function git_foreach_cmd() { # do_not_function_help
	local cmd="$@"
	local git_run_dir=$(get_vulue "" "$(pwd)" "$GIT_RUN_DIR")
	run_cmd git -C $git_run_dir $cmd
	run_cmd git -C $git_run_dir submodule foreach --recursive "git $cmd"
}

function gen_dir_patch() { # do_not_function_help
	local src_dir=$(pwd)
	local patch_dir=$(echo $src_dir | sed "s,$REPO_DIR,$PATCH_SUBDIR,g")
	local patch_name=$(basename $src_dir)

	log "------------------------"
	log "src_dir    : $src_dir"
	log "patch_dir  : $patch_dir"
	log "patch_name : $patch_name"
	local change_cnt=$(git status --short 2>/dev/null | wc -l)
	if [ "$change_cnt"x = "0"x ]; then
		if [ "$REMOVE_OLD_PATCH"x = "1"x ]; then
			rm -f $patch_dir/$patch_name.patch
		fi
		log "no change!"
		log "------------------------"
		return
	fi

	mkdir -p $patch_dir
	git diff --cached --ignore-submodules > $patch_dir/$patch_name.patch
	log "------------------------"
}

function gen_patch() { # [SRC_DIR(default : $REPO_DIR)] [PATCH_DIR(default : $REPO_DIR/patch)]
	local src_dir=$(get_vulue "" "$REPO_DIR" "$1")
	local patch_dir=$(get_vulue "" "$REPO_DIR/patch" "$2")
	local script=$(realpath $0)

	export REPO_DIR=$REPO_DIR
	export PATCH_SUBDIR=$patch_dir
	export VERBOSE=1
	cd $src_dir
	if [ ! "$SKIP_ROOT"x = "1"x ]; then
		git add -A 1>/dev/null
		$script gen_dir_patch
	fi
	git submodule foreach --recursive 'git add -A' 1>/dev/null
	git submodule foreach --recursive "$script gen_dir_patch"

	git reset 1>/dev/null
	git submodule foreach --recursive 'git reset' 1>/dev/null
	cd - 2>/dev/null
}

function gen_top_patch() { # [PATCH_DIR(default : $REPO_DIR/patch)]
	local src_dir=$REPO_DIR
	local patch_dir=$(get_vulue "" "$REPO_DIR/patch" "$1")
	SKIP_ROOT=1 gen_patch $src_dir $(realpath $patch_dir)
}

function do_git_apply() { # do_not_function_help
	local patch_dir=$1
	local src_dir=$2
	local is_revert=$3
	local apply_param=""
	local sort_param=""
	local f

	if [ ! -d $patch_dir ]; then
		return 0
	fi

	if [ "$is_revert"x = "1"x ]; then
		apply_param+="-R"
		sort_param+="-r"
	fi

	apply_param+=" --whitespace=fix"
	apply_param+=" --whitespace=nowarn"
	patch_dir=$(realpath $patch_dir)
	if [ -f $patch_dir ]; then
		git -C $src_dir apply $apply_param $patch_dir
		return $?
	fi

	for f in $(ls -l $patch_dir 2>/dev/null | grep -v '^total' | awk '{print $NF}' | sort $sort_param);
	do
		if [ -d $patch_dir/$f ]; then
			do_git_apply $patch_dir/$f $src_dir/$f $is_revert
		else
			git -C $src_dir apply $apply_param $patch_dir/$f
		fi
	done
}

function patch_apply() { # PATCH_DIR SRC_DIR
	do_git_apply "$1" "$2" 0
}

function patch_revert() { # PATCH_DIR SRC_DIR
	do_git_apply "$1" "$2" 1
}

function top_patch_apply() {
	patch_apply $REPO_DIR/patch/ $REPO_DIR
}

function top_patch_revert() {
	patch_revert $REPO_DIR/patch/ $REPO_DIR
}

default_cmd="help"

function help() {
	local ret=$(get_vulue "" 0 $1)
	echo -e "Optional env :"
	echo -e "\tRM_SUBMODULE"
	echo -e "\tSKIP_ROOT"
	echo -e "Optional commands :"
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

CMD=$default_cmd
if is_function $1; then
	CMD=$1
	shift
fi

$CMD $@
