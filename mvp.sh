#!/bin/bash
#########################################################################
# File Name: mvp.sh
# Author: Edward.Tang
# mail:   @163.com
# Created Time: Thu 24 Oct 2019 10:45:28 AM CST
#########################################################################

# 将源文件或者目录移动到目标目录并保留源文件目录结构
# mvp <file | dir> <target dir>
function mvp()
{
	local src_dir=`dirname ${1}` #源父目录
	local dst_dir="$2/$src_dir" #目标目录
	if [ ! -d "$dst_dir" ]; then
		mkdir -p "$dst_dir"
	fi
	mv "$1" "$dst_dir"
	echo "mv $1 to $dst_dir"
}

export -f mvp

function test()
{
    mkdir -p a/b
    mkdir -p c
    touch a/a.done
    touch a/b/b.done

    find -name "*.done" | while read f ; do
        mvp "$f" "c/"
    done
}

test

