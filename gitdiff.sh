#!/bin/bash
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
END='\e[0m'
RED()
{
	echo -e  "${RED}$@${END}"
}

GREEN()
{
	echo -e  "${GREEN}$@${END}"
}

YELLOW()
{
    echo -e  "${YELLOW}$@${END}"
}

error()
{
	echo -e  "${RED}$@${END}"
    exit 1
}

SCRIPT_PATH=$(readlink -f "$BASH_SOURCE")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
SCRIPT_DIR="$(cd "$( dirname "$SCRIPT_PATH")" && pwd)"
# CONFIG_PATH=${SCRIPT_DIR%/*}/config.ini
git config --global core.quotepath false
# git config --global user.email "edaplayer@163.com"
# git config --global user.name "Edward.Tang"
# TOP="$PWD"

ROOT=$PWD/..
TIME=`date +%Y-%m-%d-%H-%M`
BRANCH=`git branch | awk '$1=="*"{print $2}'`

ALIAS=
# DEST_PATH，目标路径，默认值Patch/分支/commit id，可通过出传参-a指定后缀路径Commit-$ALIAS
DEST_PATH=$ROOT/Patch/$BRANCH/Commit-$1
LOG_PATH=$ROOT/Patch/$BRANCH/Commit-$1/Readme.txt

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
    if [ ! -z $2 ]; then
        local separation="========================================================================================"
        echo $separation >> $2
        echo $Patch Time : $TIME >> $2
        echo $Git Branch : $BRANCH >> $2
        echo -e "\nSave log message to $2:\n "
        git log -1 | tee -a $2
    fi

    echo

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

        # 检查是否需要创建父目录
        dir=`dirname "$FILE"`
        [ -d "$dir" ] && mkdir -p $1/"$dir"

        # 目标是文件，直接copy 文件
        if [ -f  "$FILE" ]; then
            cp -rfa "$FILE" "$1"/"$FILE"
        elif [ -d  "$FILE" ]; then
            # 如果目标是目录(这种情况只有fetch_current模式才会出现)，拷贝到目标父目录
            cp  -rfa "$FILE" "$1"/"$dir"
        else
            RED "Error: $FILE couldn't be found."
        fi

        # 保存文件列表到readme.txt，如Mod: code.c
        if [ ! -z $2 ]; then
            echo "$TAG: $FILE" >> $2
        fi
    done
}

# --------------------------------------------------------------------------#
# @function get_commit_files
# @brief copy差异列表中的所有文件到目标路径(通过git show方式)
# param1 commmit id
# param2 目标路径
# param3 log路径
# ----------------------------------------------------------------------------#
function get_commit_files()
{
    local commit_id="$1"
    local target_path="$2"
    local target_log="$3"
    if [ ! -z "$target_log" ]; then
        local separation="================================================================================"
        echo $separation >> "$target_log"
        echo $Patch Time : $TIME >> "$target_log"
        echo $Git Branch : $BRANCH >> "$target_log"
        echo -e "\nSave log message to $target_log:\n "
        git log -1 | tee -a "$target_log"
    fi

    echo

    local f
    local FILE
    local dir
    local file_list
    GREEN "get_commit_files"
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

        # 创建父目录
        dir=`dirname "$FILE"`
        mkdir -p "$target_path"/"$dir"

        # git show得到的一定是文件路径，直接copy 文件
        git show ${commit_id}:"$FILE" > "${target_path}"/"$FILE"

        # 保存差异列表到readme.txt，如Mod: code.c
        if [ ! -z $target_log ]; then
            echo "$TAG: $FILE" >> "$target_log"
        fi
    done
}

# func fetch_commit_show
# param1 commit-old
# param2 commit-new
# return none
function fetch_commit_show()
{
    if [ ! -z $2 ];then
        # 有2个参数，指定两个commit节点比较
        AFTER_COMMIT=$2
        BEFORE_COMMIT=$1
    else
        # 1个参数，只对该节点前后比较
        AFTER_COMMIT=$1
        BEFORE_COMMIT=$1^
    fi

    GREEN AFTER_COMMIT=$AFTER_COMMIT
    GREEN BEFORE_COMMIT=$BEFORE_COMMIT
    GREEN "Run fetch_commit_show now."

    mkdir -p $DEST_PATH
    git diff $BEFORE_COMMIT $AFTER_COMMIT > $DEST_PATH/commit.diff

    diff_list=`git diff --name-status $BEFORE_COMMIT $AFTER_COMMIT |\
            sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    echo -e "\nafter diff_list=\n$diff_list\n"
    # 取出目标新节点中有改动的文件
    GREEN "Step1: get after $AFTER_COMMIT files."
    mkdir -p $DEST_PATH/after
    get_commit_files $AFTER_COMMIT "$DEST_PATH"/after $LOG_PATH

    # 取出旧节点（before文件）
    GREEN "Step2: get before $BEFORE_COMMIT files."

    diff_list=`git diff --name-status $BEFORE_COMMIT $AFTER_COMMIT |\
            sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g' -e 's/^A.*//'`
    echo -e "\nbefore diff_list=\n$diff_list\n"

    mkdir -p $DEST_PATH/before
    get_commit_files $BEFORE_COMMIT "$DEST_PATH"/before
    GREEN "fetch_commit_show success."
}

# func fetch_commit
# param1 commit-old
# param2 commit-new
# return none
function fetch_commit()
{
    if [ ! -z $2 ];then
        # 有2个参数，指定两个commit节点比较
        AFTER_COMMIT=$2
        BEFORE_COMMIT=$1
    else
        # 1个参数，只对该节点前后比较
        AFTER_COMMIT=$1
        BEFORE_COMMIT=$1^
    fi

    GREEN AFTER_COMMIT=$AFTER_COMMIT
    GREEN BEFORE_COMMIT=$BEFORE_COMMIT

    echo "Current mode is diff commit mode, git stash may need to be executed."
    git_stash

    if [ $# == 0 ]; then
        error "Error: missing commit id."
    fi

    # 取出目标新节点中有改动的文件
    diff_list=`git diff --name-status $BEFORE_COMMIT $AFTER_COMMIT |
            sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    echo -e "\nafter diff_list=\n$diff_list\n"
    git checkout $AFTER_COMMIT 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step1: Checkout after $AFTER_COMMIT success." ||
            error "Checkout after id failed. Maybe you should run git stash."
    mkdir -p $DEST_PATH/after
    fetch_list "$DEST_PATH"/after $LOG_PATH

    # 取出旧节点（before文件）
    diff_list=`git diff --name-status $BEFORE_COMMIT $AFTER_COMMIT |
            sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    echo -e "\nbefore diff_list=\n$diff_list\n"
    git checkout $BEFORE_COMMIT 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step2: Checkout before $BEFORE_COMMIT success." ||
            error "Checkout before id failed. Maybe you should run git stash"
    mkdir -p $DEST_PATH/before
    fetch_list "$DEST_PATH"/before

    # 恢复初始状态
    echo
    git checkout $BRANCH 1>/dev/null 2>&1
    [ $? == 0 ] && GREEN "Step3: Checkout branch $BRANCH success." ||
            error "Checkout branch $BRANCH failed."

    [ $GIT_STASH == 1 ] && git stash pop > /dev/null
}

# func fetch_current_show
#  取出当前状态差异文件
# param none
# return none
function fetch_current_show()
{
    mkdir -p $DEST_PATH
    git diff > $DEST_PATH/current.diff
    # 取出已修改的文件（默认不包含未跟踪的文件）
    # git status相当于git status -unormal，而git status -u相当于git status -uall，子目录文件也会被显示
    diff_list=`git status -s$UNTRACK | sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`

    # if [ "$UNTRACK" == "no" ]; then
        # diff_list=`git diff --name-status HEAD | sed -e 's/[ \t]\+//g' -e 's/^??/A/g'`
    # else
        # diff_list=`git status -s | sed -e 's/[ \t]\+//g' -e 's/^??/A/g'`
    # fi

    GREEN "\nStep1: fetch_list"
    GREEN "diff_list=\n$diff_list"
    mkdir -p $DEST_PATH/after
    fetch_list "$DEST_PATH"/after $LOG_PATH

    # 保存现场，取出原始文件（排除未跟踪的文件）
    GREEN "\nStep2: get_commit_files"
    diff_list=`git status -suno | sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    # diff_list=`git diff --name-status HEAD | sed -e 's/[ \t]\+//g' -e 's/^??/A/g'`
    GREEN "diff_list=\n$diff_list"
    mkdir -p $DEST_PATH/before
    get_commit_files HEAD "$DEST_PATH"/before
}

# func fetch_current
#  取出当前状态差异文件
# param none
# return none
function fetch_current()
{
    mkdir -p $DEST_PATH
    git diff > $DEST_PATH/current.diff
    # 取出已修改的文件（默认不包含未跟踪的文件）
    # git status相当于git status -unormal，而git status -u相当于git status -uall，子目录文件也会被显示
    diff_list=`git status -s$UNTRACK | sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`

    GREEN "\nStep1: fetch_list after"
    GREEN "diff_list=\n$diff_list"
    mkdir -p $DEST_PATH/after
    fetch_list "$DEST_PATH"/after $LOG_PATH

    # 保存现场，取出原始文件（排除未跟踪的文件）
    GREEN "\nStep2: fetch_list before"
    diff_list=`git status -suno | sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    echo -e "\ncurrent diff_list=\n$diff_list\n"
    git stash > /dev/null
    git checkout .
    mkdir -p $DEST_PATH/before
    fetch_list "$DEST_PATH"/before
    git stash pop > /dev/null
}

# func fetch_branch
#      提取当前分支与目标branch的差异
# param1 branch
# return none
function fetch_branch()
{
    DEST_PATH="$ROOT/Patch/$BRANCH/Diff-("$BRANCH")_($1)"
    LOG_PATH="$ROOT/Patch/$BRANCH/Diff-("$BRANCH")_($1)/Readme.txt"

    mkdir -p $DEST_PATH/after
    # 比较当前分支和目标分支的差异
    diff_list=`git diff --name-status $1 | sed -e 's/^\s\+//' -e 's/\s\+//' -e 's/^??/A/g'`
    fetch_list $DEST_PATH/after $LOG_PATH
    # 切换到目标分支
    git checkout $1
    [ $? == 0 ] && GREEN "Checkout branch $1 success." || error "Checkout branch $1 failed."

    mkdir -p $DEST_PATH/before
    fetch_list $DEST_PATH/before
    git checkout $BRANCH
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
            fetch_commit_show $@
        elif [ "$DIFF_BRANCH" = 1 ];then
            echo -e "\nBranch mode"
            fetch_branch $@
        fi
    else
        echo -e "\nCurrent mode"
        fetch_current_show
    fi
}

function parse_arg()
{
    ARGS=`getopt -o a:cdhtu: -- "$@"`
    echo ARGS="$ARGS"
    eval set -- ${ARGS}
    while getopts "a:cdhtu:" opt
    do
        case $opt in
            a)
                ALIAS=$OPTARG
                ;;
            b)
                DIFF_BRANCH=1
                ;;
            c)
                DIFF_CURRENT=1
                ;;
            d)
                DIFF_COMMIT=1
                ;;
            t)
                ALIAS=$TIME
                ;;
            u)
                UNTRACK=u$OPTARG
                ;;
            h)
                usage
                exit 0
                ;;
            \?)
                usage
                error "Error: invaild argument: $opt"
                ;;
        esac
    done
    # echo "Final OPTIND = $OPTIND"
    shift $(( $OPTIND-1 ))
    GREEN "After getopts, all args: $@"

    if [ $# != 0 ];then
        # 根据$1对比log和branch，判断是commit模式还是branch模式
        RETSUT_1=`git log --pretty=format:"%H" | grep $1`
        RETSUT_2=`git branch |  grep $1`
        if [ ! -z "$RETSUT_1" -o "$1" == "HEAD" ];then
            DIFF_COMMIT=1
        fi

        if [ ! -z "$RETSUT_2" ];then
            DIFF_BRANCH=1
        fi

        if [ "$DIFF_COMMIT" = 0 -a "$DIFF_BRANCH" = 0 ];then
            error "No found this commit id or branch!"
        fi
    else
        DIFF_CURRENT=1
    fi

    GREEN ALIAS=$ALIAS
    GREEN DIFF_COMMIT=$DIFF_COMMIT
    GREEN DIFF_BRANCH=$DIFF_BRANCH
    GREEN DIFF_CURRENT=$DIFF_CURRENT

    if [ ! -z $ALIAS ];then
        DEST_PATH=$ROOT/Patch/$BRANCH/Commit-$ALIAS
    elif [ ! -z $2 ];then
        DEST_PATH=$ROOT/Patch/$BRANCH/Commit-$1-$2
    elif [ ! -z $1 ];then
        DEST_PATH=$ROOT/Patch/$BRANCH/Commit-$1
    else
        DEST_PATH=$ROOT/Patch/$BRANCH/Commit-$TIME
    fi
    LOG_PATH=$DEST_PATH/Readme.txt

    checkout_files $@
}

function main()
{
    if [ ! -e .git ];then
        error "fatal: Not a git repository!!!"
    fi
    parse_arg $@
}

main $@
