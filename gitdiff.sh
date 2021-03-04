#!/bin/bash
#########################################################################
# File Name: gitdiff.sh
# Author: Edward.Tang
# mail:   @163.com
# Created Time: Fri 11 Jan 2019 20:03:39 PM CST
#########################################################################
function usage()
{
cat <<EOF
NAME
       $SCRIPT_NAME - fetch changes between commits, commit and working tree, etc

SYNOPSIS
       $SCRIPT_NAME [options] [<commit>]
       $SCRIPT_NAME [options] <commmit> [<commit>]
       $SCRIPT_NAME [options] <branch>

OPTIONS
       -a
           assign ALIAS var to log path.

       -b
           branch mode.

       -c
           current mode.

       -d
           commit mode.

       -g
           generate diff file.

       -t
           For current mode, time as log path instead of commite id.

       -u
           The status mode parameter is used to specify the handling of untracked files. It is optional: it defaults to no.
           Please see git status --help for more details.

       -h, --help
           See usage.

NOTE
       If no options are specified, default mode is current mode.
EOF
}

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
END='\e[0m'

RED()
{
	echo -e  "${RED}$*${END}"
}

GREEN()
{
	echo -e  "${GREEN}$*${END}"
}

YELLOW()
{
    echo -e  "${YELLOW}$*${END}"
}

error()
{
	echo -e  "${RED}$*${END}"
    exit 1
}

setenv()
{
	SCRIPT_PATH=$(readlink -f "$BASH_SOURCE")
	SCRIPT_NAME=$(basename "$SCRIPT_PATH")
	# SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
	git config --global core.editor vim
	git config --global core.quotepath false
	git config --global color.ui true
	# git config --global user.email "edaplayer@163.com"
	# git config --global user.name "Edward.Tang"

	GITTOP=$(git rev-parse --show-toplevel)
	ROOT=$(readlink -f "$GITTOP"/..)
	TIME=$(date +%Y-%m-%d-%H-%M)
	BRANCH=$(git branch | awk '$1=="*"{print $2}')

	ALIAS=
	# TARGET_PATH，目标路径，默认值Patch/分支/commit id，
	# 通过parse_arg设置
	# 可通过出传参-a指定后缀Commit-$ALIAS
	TARGET_PATH=
	LOG_PATH=
	DIFF_MODE=

    # 以下模式三选一，可根据参数$1判断，或者使用-b -c -d选项
    # DIFF_MODE="current" # DIFF_MODE="current"时，比较当前未暂存的文件
    # DIFF_MODE="commit"时，按commit id比较，通过传参$1确定
    # DIFF_MODE="branch"时，按branch比较，通过传参$1确定

	# 是否比较未跟踪文件，默认不比较未跟踪文件，通过-u选项设定
	UNTRACK=no
	# UNTRACK=normal
	# UNTRACK=all
	separation="================================================================================"
}
# --------------------------------------------------------------------------#
# @brief save_log，保存log到$2路径
# param1 log内容
# param2 log路径
# ----------------------------------------------------------------------------#
function save_log()
{
    if [ $# = 2 ]; then
        local LOGS="$1"
        local target_log="$2"
        {
            echo "$separation"
            echo "Patch Time : $TIME"
            echo "Branch : $BRANCH"
            echo "$separation"
        } >> "$target_log"
        echo "$separation"
        echo -e "Save log message to $target_log:\n "
        echo -e "$LOGS\n" | tee -a "$target_log"
        echo "${diff_list[*]}" >> "$target_log"
        echo "$separation"
    fi
}

# --------------------------------------------------------------------------#
# @function copy_files
# @brief copy差异列表中的所有文件到目标路径(通过git show方式)
# param1 commmit id
# param2 目标路径
# or
# param1 目标路径
# ----------------------------------------------------------------------------#
function copy_files()
{
    if [ $# == 1 ]; then
        local target_path="$1"
    else
        local commit_id="$1"
        local target_path="$2"
    fi

    local f
    local TAG
    local FILE
    local dir

    GREEN "copy_files:"
    for f in ${diff_list[@]}; do
        [ -z "$f" ] && continue
        TAG=${f:0:1} #第1个字符
        FILE=${f:2}  #第3个字符到末尾
        if [ "$TAG" == "M" ];then
            GREEN  "$TAG    $FILE"
        elif [ "$TAG" == "D" ];then
            RED "$TAG    $FILE"
        elif [ "$TAG" == "A" ];then
            YELLOW "$TAG    $FILE"
        else
            error "Error: invaild TAG $TAG"
        fi

        # 创建父目录
        dir=$(dirname "$FILE")
        [ -d "$target_path/$dir" ] || mkdir -p "$target_path/$dir"

        # 如果未指定id，直接拷贝当前文件
        if [ $# == 1 ];then
            # 目标是文件，直接copy 文件
            if [ -f "$FILE" ]; then
                cp -rfa "$FILE" "$target_path/$FILE"
            elif [ -d "$FILE" ]; then
                # 如果目标是目录(这种情况只有fetch_current模式才会出现)，拷贝到目标父目录
                cp -rfa "$FILE" "$target_path/$dir"
            else
                error "Error: $FILE couldn't be found."
            fi
        # 指定id，则使用git show重定向方式拷贝文件
        else
            git show "${commit_id}":"$FILE" 1>"${target_path}/$FILE" || rm "${target_path}/$FILE"
        fi
    done
    echo "$separation"
}

# func fetch_commit_diff_by_id
# param1 commit-old
# param2 commit-new
# return none
function fetch_commit_diff_by_id()
{
    if [ -n "$2" ];then
        # 有2个参数，指定两个commit节点比较
        AFTER_COMMIT=$2
        BEFORE_COMMIT=$1
    else
        # 1个参数，只对该节点前后比较
        AFTER_COMMIT=$1
        BEFORE_COMMIT=$1^
    fi

    GREEN "AFTER_COMMIT=$AFTER_COMMIT"
    GREEN "BEFORE_COMMIT=$BEFORE_COMMIT\n"
    GREEN "Run fetch_commit_diff_by_id now."

    mkdir -p "$TARGET_PATH"
    [ "$GENERATE_DIFF" = 1 ] && git diff --binary "$BEFORE_COMMIT" "$AFTER_COMMIT" > "$TARGET_PATH/commit.diff"

    # 取出目标新节点中有改动的文件
    local IFS=$'\n'
    diff_list=($(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
        sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g'))
    mkdir -p "$TARGET_PATH"/after
    LOGS=$(git log "$BEFORE_COMMIT".."$AFTER_COMMIT")
    save_log "$LOGS" "$LOG_PATH"
    GREEN "Step1: get commit $AFTER_COMMIT files.\n"
    echo -e "last diff_list=\n${diff_list[*]}\n"
    copy_files "$AFTER_COMMIT" "$TARGET_PATH"/after

    # 取出旧节点（before文件）
    GREEN "Step2: get commit $BEFORE_COMMIT files.\n"

    diff_list=($(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
        sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g' -e 's/^A.*//'))
    echo -e "previous diff_list=\n${diff_list[*]}\n"

    mkdir -p "$TARGET_PATH"/before
    copy_files "$BEFORE_COMMIT" "$TARGET_PATH"/before
    GREEN "fetch_commit_diff_by_id success."
}

# func fetch_current_diff_by_id
#  取出当前状态差异文件
# param none
# return none
function fetch_current_diff_by_id()
{
    mkdir -p "$TARGET_PATH"
    [ "$GENERATE_DIFF" = 1 ] && git diff --binary > "$TARGET_PATH/current.diff"
    # 取出已修改的文件（默认不包含未跟踪的文件）
    # git status相当于git status -unormal，而git status -u相当于git status -uall，子目录文件也会被显示
    local IFS=$'\n'
    diff_list=($(git status -su$UNTRACK | sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g' -e 's/^D.*//'))

    mkdir -p "$TARGET_PATH"/after
    LOGS=$(git log -1)
    save_log "$LOGS" "$LOG_PATH"

    GREEN "Step1: get current files.\n"
    echo -e "current diff_list=\n$diff_list\n"
    copy_files "$TARGET_PATH"/after

    # 保存现场，取出原始文件（排除未跟踪的文件）
    GREEN "Step2: get original files\n"
    diff_list=($(git status -suno | sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g' -e 's/^A.*//'))
    echo -e "previous diff_list=\n$diff_list\n"
    mkdir -p "$TARGET_PATH"/before
    copy_files HEAD "$TARGET_PATH"/before
    GREEN "fetch_current_diff_by_id success."
}

# func fetch_branch_diff_by_id
#      提取当前分支与目标branch的差异
# param1 branch
# return none
function fetch_branch_diff_by_id()
{
    TARGET_PATH="$ROOT/patch/$BRANCH/Diff-($BRANCH)_($1)"
    LOG_PATH="$ROOT/patch/$BRANCH/Diff-($BRANCH)_($1)/readme.txt"

    mkdir -p "$TARGET_PATH"
    [ "$GENERATE_DIFF" = 1 ] && git diff --binary "$1" > "$TARGET_PATH/branch.diff"

    local IFS=$'\n'
    diff_list=($(git diff --name-status "$1" | \
        sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g' -e 's/^D.*//'))
    mkdir -p "$TARGET_PATH"/after
    LOGS=$(git log -1)
    save_log "$LOGS" "$LOG_PATH"
    GREEN "Step1: get current $BRANCH files.\n"
    echo -e "current branch diff_list=\n${diff_list[*]}\n"
    copy_files "$TARGET_PATH"/after

    # 取出旧节点（before文件）
    GREEN "Step2: get branch $1 files.\n"
    diff_list=($(git diff --name-status "$1" | \
        sed -re 's/^\s*(\S+)\s+/\1 /' -e 's/^\?\?/A/g' -e 's/^A.*//'))

    echo -e "branch $1 diff_list=\n${diff_list[*]}\n"

    mkdir -p "$TARGET_PATH"/before
    copy_files "$1" "$TARGET_PATH"/before
    GREEN "fetch_branch_diff_by_id success."
}

function do_start()
{
    echo
    GREEN "Checking the code, please wait...\n"

    case "$DIFF_MODE" in
        current)
            fetch_current_diff_by_id ;;
        commit)
            fetch_commit_diff_by_id "$@" ;;
        branch)
            fetch_branch_diff_by_id "$@" ;;
    esac

    GREEN "\n###### Generate diff files success. ######\n"
}

function parse_arg()
{
    if ARGS=$(getopt -o a:bcdghtu: -l "help" -- "$@") ; then
        echo ARGS="$ARGS"
        eval set -- "${ARGS}"
    else
        usage
        error "Error: invaild argument"
    fi

    while [ "$1" ]; do
        opt=$1
        case "$opt" in
            -a) shift; ALIAS=$1;;
            -b) DIFF_MODE="branch";;
            -c) DIFF_MODE="current";;
            -d) DIFF_MODE="commit";;
            -g) GENERATE_DIFF=1;;
            -t) ALIAS=$TIME;;
            -u) shift; UNTRACK=$1;;
            -h|--help) usage; exit 0;;
            --) shift; break;;
            *) usage; error "Error: invaild argument: $opt";;
        esac
        shift
    done

    GREEN "After getopt, all args is: $*"

    if [ $# != 0 ];then
        # 根据$1对比log和branch，判断是commit模式还是branch模式
        TARGET_COMMIT=$(git log --all --pretty=format:"%H" | grep "$1")
        TARGET_BRANCH=$(git branch | grep "$1")
        if [ -n "$TARGET_COMMIT" ] || [ "$1" == "HEAD" ];then
            DIFF_MODE="commit"
        elif [ -n "$TARGET_BRANCH" ];then
            DIFF_MODE="branch"
        else
            error "Error: No such commit id or branch: $1"
        fi
    else
        DIFF_MODE="current"
    fi

    GREEN ALIAS="$ALIAS"
    GREEN DIFF_MODE="$DIFF_MODE"
    GREEN GENERATE_DIFF="$GENERATE_DIFF"

    if [ -n "$ALIAS" ];then
        TARGET_PATH="$ROOT/patch/$BRANCH/commit-$ALIAS"
    elif [ -n "$2" ];then
        TARGET_PATH="$ROOT/patch/$BRANCH/commit-$1-$2"
    elif [ -n "$1" ];then
        TARGET_PATH="$ROOT/patch/$BRANCH/commit-$1"
    else
        TARGET_PATH="$ROOT/patch/$BRANCH/commit-$TIME"
    fi
    LOG_PATH="$TARGET_PATH/readme.txt"

    do_start "$@"
}

function main()
{
	setenv

    if [[ "$GITTOP" = "" ]];then
        error "fatal: Not a git repository!!!"
    fi

    parse_arg "$@"
}

main "$@"
