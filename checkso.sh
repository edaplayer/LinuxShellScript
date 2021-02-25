#!/bin/bash

array=(
libcairo.a
libcairo-gobject.a
libcairo-script-interpreter.a
libcharset.a
libcpufeatures.a
libffi.a
libfreetype.a
libgettextpo.a
libgio-2.0.a
libglib-2.0.a
libgmodule-2.0.a
libgobject-2.0.a
libgthread-2.0.a
libharfbuzz.a
libharfbuzz-icu.a
libharfbuzz-subset.a
libicuuc67.so
libintl.a
libpcre.a
libpcrecpp.a
libpcreposix.a
libpixman-1.a
libpng16.a
libtextstyle.a
libz.a
)

# https://blog.csdn.net/guojin08/article/details/38704823
# 代码：
# file="thisfile.txt"
# echo "filename: ${file%.*}"
# echo "extension: ${file##*.}"
# 输出：
# filename: thisfile
# extension: txt

cd /home/lzz/n0/SC806-Android7.0/out/target/product/la0920
i=1
for so in ${array[@]}; do
	echo $i. ${so%.*}.so
	fd ${so%.*}
	((i++))
done