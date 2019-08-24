#!/bin/bash
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

SCRIPT_PATH=$(readlink -f "$BASH_SOURCE")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
# SCRIPT_DIR="$(cd "$( dirname "$SCRIPT_PATH")" && pwd)"
# CONFIG_PATH=${SCRIPT_DIR%/*}/config.ini
git config --global core.quotepath false
# git config --global user.email "edaplayer@163.com"
# git config --global user.name "Edward.Tang"
# TOP="$PWD"

ROOT=$PWD/..
TIME=$(date +%Y-%m-%d-%H-%M)
BRANCH=$(git branch | awk '$1=="*"{print $2}')

ALIAS=
# DEST_PATH，目标路径，默认值Patch/分支/commit id，可通过出传参-a指定后缀路径Commit-$ALIAS
DEST_PATH="$ROOT/Patch/$BRANCH/Commit-$1"
LOG_PATH="$ROOT/Patch/$BRANCH/Commit-$1/Readme.txt"

# 以下模式三选一
DIFF_CURRENT=0 # DIFF_CURRENT=1时，比较当前unstage的文件
DIFF_COMMIT=0 #按commit id比较，通过传参$1确定
DIFF_BRANCH=0 #按branch比较，通过传参$1确定

# 是否比较未跟踪文件，默认不比较未跟踪文件
UNTRACK=uno
# UNTRACK=unormal
# UNTRACK=uall

MODIFIED_TAG="Mod:"
DELETED_TAG="Del:"
ADDED_TAG="Add:"

function git_stash()
{
    while true; do
        read -p "Run git stash? Please enter y or n: " answer
        case $answer in
            [yY]*)
                git stash | grep Saved
                [ $? == 0  ] && GIT_STASH=1
                break;
                ;;
            [nN]*)
                GIT_STASH=0
                break;
                ;;
            *)
                echo -e "\nDude, just enter Y or N, please."
                ;;
        esac
    done
}

# --------------------------------------------------------------------------#
# @brief fetch_list ，copy diff_list 列表中的所有文件到$1路径(通过git checkout方式)
# param1 目标路径
# param2 log路径
# ----------------------------------------------------------------------------#
function fetch_list()
{
    local target_path="$1"
    local target_log="$2"
    if [ -n "$target_log" ]; then
        local separation="========================================================================================"
        {
            echo "$separation"
            echo "Patch Time : $TIME"
            echo "Branch : $BRANCH"
        } >> "$target_log"
        echo -e "Save log message to $target_log:\n "
        git log -1 | tee -a "$target_log"
        echo
    fi

    local f
    local FILE
    local dir
    local file_list

    echo "$diff_list" > tmp.tmp
    local n=0
    while read f
    do
        file_list[n]="$f"
        let n++
    done < tmp.tmp
    rm tmp.tmp

    for f in "${file_list[@]}"
    do
        [ -z "$f" ] && continue
        TAG=${f:0:1} #第1个字符
        FILE=${f:1}  #第2个字符到末尾
        if [ "$TAG" == "M" ];then
            TAG=$MODIFIED_TAG
            GREEN  "$TAG  $FILE"
        elif [ "$TAG" == "D" ];then
            TAG=$DELETED_TAG
            RED "$TAG  $FILE"
        elif [ "$TAG" == "A" ];then
            TAG=$ADDED_TAG
            YELLOW "$TAG  $FILE"
        else
            error "Error: invaild TAG $TAG"
        fi

        # 保存文件列表到readme.txt，如Mod: code.c
        if [ -n "$target_log" ]; then
            echo "$TAG: $FILE" >> "$target_log"
        fi

        # 检查是否需要创建父目录
        dir=$(dirname "$FILE")
        [ -d "$dir" ] && mkdir -p "$target_path"/"$dir"

        # 目标是文件，直接copy 文件
        if [ -f  "$FILE" ]; then
            cp -rfa "$FILE" "$target_path"/"$FILE"
        elif [ -d  "$FILE" ]; then
            # 如果目标是目录(这种情况只有fetch_current模式才会出现)，拷贝到目标父目录
            cp  -rfa "$FILE" "$target_path"/"$dir"
        else
            RED "Error: $FILE couldn't be found."
        fi
    done
}

# --------------------------------------------------------------------------#
# @function fetch_list_by_id
# @brief copy差异列表中的所有文件到目标路径(通过git show方式)
# param1 commmit id
# param2 目标路径
# param3 log路径
# ----------------------------------------------------------------------------#
function fetch_list_by_id()
{
    local commit_id="$1"
    local target_path="$2"
    local target_log="$3"
    if [ -n "$target_log" ]; then
        local separation="================================================================================"
        {
            echo "$separation"
            echo "Patch Time : $TIME"
            echo "Branch : $BRANCH"
        } >> "$target_log"
        echo -e "Save log message to $target_log:\n "
        git log "${commit_id}" -1 | tee -a "$target_log"
        echo
    fi

    local f
    local FILE
    local dir
    local file_list
    GREEN "fetch_list_by_id"
    GREEN "diff_list=$diff_list"
    echo "$diff_list" > tmp.tmp
    local n=0
    while read f
    do
        file_list[n]="$f"
        let n++
    done < tmp.tmp
    rm tmp.tmp

    for f in "${file_list[@]}"
    do
        [ -z "$f" ] && continue
        TAG=${f:0:1} #第1个字符
        FILE=${f:1}  #第2个字符到末尾
        if [ "$TAG" == "M" ];then
            TAG=$MODIFIED_TAG
            GREEN  "$TAG  $FILE"
        elif [ "$TAG" == "D" ];then
            TAG=$DELETED_TAG
            RED "$TAG  $FILE"
        elif [ "$TAG" == "A" ];then
            TAG=$ADDED_TAG
            YELLOW "$TAG  $FILE"
        else
            error "Error: invaild TAG $TAG"
        fi

        # 保存差异列表到readme.txt，如Mod: code.c
        if [ -n "$target_log" ]; then
            echo "$TAG: $FILE" >> "$target_log"
        fi

        # 创建父目录
        dir=$(dirname "$FILE")
        [ -d "$target_path"/"$dir" ] || mkdir -p "$target_path"/"$dir"

        # git show得到的一定是文件路径，直接copy 文件
        git show "${commit_id}":"$FILE" 1>"${target_path}"/"$FILE" || rm "${target_path}"/"$FILE"
    done
}

# func fetch_commit_by_id
# param1 commit-old
# param2 commit-new
# return none
function fetch_commit_by_id()
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
    GREEN "Run fetch_commit_by_id now."

    mkdir -p "$DEST_PATH"
    git diff "$BEFORE_COMMIT" "$AFTER_COMMIT" > "$DEST_PATH"/commit.diff

    # 取出目标新节点中有改动的文件
    GREEN "Step1: get after $AFTER_COMMIT files.\n"
    diff_list=$(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
        sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    echo -e "after diff_list=\n$diff_list\n"
    mkdir -p "$DEST_PATH"/after
    fetch_list_by_id "$AFTER_COMMIT" "$DEST_PATH"/after "$LOG_PATH"

    # 取出旧节点（before文件）
    GREEN "Step2: get before $BEFORE_COMMIT files.\n"

    diff_list=$(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
        sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g' -e 's/^A.*//')
    echo -e "before diff_list=\n$diff_list\n"

    mkdir -p "$DEST_PATH"/before
    fetch_list_by_id "$BEFORE_COMMIT" "$DEST_PATH"/before
    GREEN "fetch_commit_by_id success."
}

# func fetch_commit
# param1 commit-old
# param2 commit-new
# return none
function fetch_commit()
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

    echo "Current mode is diff commit mode, git stash may need to be executed."
    git_stash

    if [ $# == 0 ]; then
        error "Error: missing commit id."
    fi

    # 取出目标新节点中有改动的文件
    diff_list=$(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
            sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    echo -e "\nafter diff_list=\n$diff_list\n"
    git checkout "$AFTER_COMMIT" 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step1: Checkout after $AFTER_COMMIT success." ||
            error "Checkout after id failed. Maybe you should run git stash."
    mkdir -p "$DEST_PATH"/after
    fetch_list "$DEST_PATH"/after "$LOG_PATH"

    # 取出旧节点（before文件）
    diff_list=$(git diff --name-status "$BEFORE_COMMIT" "$AFTER_COMMIT" |\
            sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    echo -e "\nbefore diff_list=\n$diff_list\n"
    git checkout "$BEFORE_COMMIT" 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step2: Checkout before $BEFORE_COMMIT success." ||
            error "Checkout before id failed. Maybe you should run git stash"
    mkdir -p "$DEST_PATH"/before
    fetch_list "$DEST_PATH"/before

    # 恢复初始状态
    echo
    git checkout "$BRANCH" 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step3: Checkout branch $BRANCH success." ||
            error "Checkout branch $BRANCH failed."

    [ $GIT_STASH == 1 ] && git stash pop > /dev/null
}

# func fetch_current_diff_by_id
#  取出当前状态差异文件
# param none
# return none
function fetch_current_diff_by_id()
{
    mkdir -p "$DEST_PATH"
    git diff > "$DEST_PATH"/current.diff
    # 取出已修改的文件（默认不包含未跟踪的文件）
    # git status相当于git status -unormal，而git status -u相当于git status -uall，子目录文件也会被显示
    diff_list=$(git status -s$UNTRACK | sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')

    GREEN "Step1: fetch_list\n"
    GREEN "diff_list=\n$diff_list"
    mkdir -p "$DEST_PATH"/after
    fetch_list "$DEST_PATH"/after "$LOG_PATH"

    # 保存现场，取出原始文件（排除未跟踪的文件）
    GREEN "Step2: fetch_list_by_id\n"
    diff_list=$(git status -suno | sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    GREEN "diff_list=\n$diff_list"
    mkdir -p "$DEST_PATH"/before
    fetch_list_by_id HEAD "$DEST_PATH"/before
    GREEN "fetch_current_diff_by_id success."
}

# func fetch_current
#  取出当前状态差异文件
# param none
# return none
function fetch_current()
{
    mkdir -p "$DEST_PATH"
    git diff > "$DEST_PATH"/current.diff
    # 取出已修改的文件（默认不包含未跟踪的文件）
    # git status相当于git status -unormal，而git status -u相当于git status -uall，子目录文件也会被显示
    diff_list=$(git status -s$UNTRACK | sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')

    GREEN "\nStep1: fetch_list after"
    GREEN "diff_list=\n$diff_list"
    mkdir -p "$DEST_PATH"/after
    fetch_list "$DEST_PATH"/after "$LOG_PATH"

    # 保存现场，取出原始文件（排除未跟踪的文件）
    GREEN "\nStep2: fetch_list before"
    diff_list=$(git status -suno | sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    echo -e "\ncurrent diff_list=\n$diff_list\n"
    git stash > /dev/null
    git checkout .
    mkdir -p "$DEST_PATH"/before
    fetch_list "$DEST_PATH"/before
    git stash pop > /dev/null
}

# func fetch_branch
#      提取当前分支与目标branch的差异
# param1 branch
# return none
function fetch_branch()
{
    DEST_PATH="$ROOT/Patch/$BRANCH/Diff-($BRANCH)_($1)"
    LOG_PATH="$ROOT/Patch/$BRANCH/Diff-($BRANCH)_($1)/Readme.txt"

    mkdir -p "$DEST_PATH/after"
    # 比较当前分支和目标分支的差异
    diff_list=$(git diff --name-status "$1" | sed -re 's/^\s*(\S+)\s+/\1/' -e 's/^\?\?/A/g')
    fetch_list "$DEST_PATH/after" "$LOG_PATH"
    # 切换到目标分支
    git checkout "$1"
    [ $? == 0 ] && GREEN "Checkout branch $1 success." || error "Checkout branch $1 failed."

    mkdir -p "$DEST_PATH/before"
    fetch_list "$DEST_PATH/before"
    git checkout "$BRANCH"
}

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

       -t
           For current mode, time as log path instead of commite id.

       -u
           The status mode parameter is used to specify the handling of untracked files. It is optional: it defaults to no.
           Please see git status --help for more details.

NOTE
       If no options are specified, default mode is current mode.
EOF
}

function checkout_files()
{
    echo
    GREEN "Checking the code, please wait..."
    if [ $# != 0 ];then
        if [ "$DIFF_COMMIT" = 1 ];then
            echo -e "\nCommit mode"
            fetch_commit_by_id "$@"
        elif [ "$DIFF_BRANCH" = 1 ];then
            echo -e "\nBranch mode"
            fetch_branch "$@"
        fi
    else
        echo -e "\nCurrent mode"
        fetch_current_diff_by_id
    fi
    GREEN "\n###### Generate diff files success. ######"
}

function parse_arg()
{
    if ARGS=$(getopt -o a:cdhtu: -- "$@") ; then
        echo ARGS="$ARGS"
        eval set -- "${ARGS}"
    else
        usage
        exit 1
    fi

    while [ "$1" ];
    do
        opt=$1
        case "$opt" in
            -a)
                shift
                ALIAS=$1
                ;;
            -b)
                DIFF_BRANCH=1
                ;;
            -c)
                DIFF_CURRENT=1
                ;;
            -d)
                DIFF_COMMIT=1
                ;;
            -t)
                ALIAS=$TIME
                ;;
            -u)
                shift
                UNTRACK=u$1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                usage
                error "Error: invaild argument: $opt"
                ;;
        esac
        shift
    done
    # echo "Final OPTIND = $OPTIND"
    # shift $(( OPTIND-1 ))
    GREEN "After getopts, all args: $*"

    if [ $# != 0 ];then
        # 根据$1对比log和branch，判断是commit模式还是branch模式
        RETSUT_1=$(git log --pretty=format:"%H" | grep "$1")
        RETSUT_2=$(git branch |  grep "$1")
        if [ -n "$RETSUT_1" ] || [ "$1" == "HEAD" ];then
            DIFF_COMMIT=1
        fi

        if [ -n "$RETSUT_2" ];then
            DIFF_BRANCH=1
        fi

        if [ "$DIFF_COMMIT" = 0 ] && [ "$DIFF_BRANCH" = 0 ];then
            error "No found this commit id or branch!"
        fi
    else
        DIFF_CURRENT=1
    fi

    GREEN ALIAS="$ALIAS"
    GREEN DIFF_COMMIT="$DIFF_COMMIT"
    GREEN DIFF_BRANCH="$DIFF_BRANCH"
    GREEN DIFF_CURRENT="$DIFF_CURRENT"

    if [ -n "$ALIAS" ];then
        DEST_PATH="$ROOT/Patch/$BRANCH/Commit-$ALIAS"
    elif [ -n "$2" ];then
        DEST_PATH="$ROOT/Patch/$BRANCH/Commit-$1-$2"
    elif [ -n "$1" ];then
        DEST_PATH="$ROOT/Patch/$BRANCH/Commit-$1"
    else
        DEST_PATH="$ROOT/Patch/$BRANCH/Commit-$TIME"
    fi
    LOG_PATH="$DEST_PATH/Readme.txt"

    checkout_files "$@"
}

function main()
{
    if [ ! -e .git ];then
        error "fatal: Not a git repository!!!"
    fi
    parse_arg "$@"
}

main "$@"
