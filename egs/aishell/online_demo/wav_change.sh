#!/bin/bash
# Description :  online decode
# Author :       caiyueliang
# Date :         2020/01/12
# Detail:

in_dir="./online-data/audio/qddata"
out_dir="./online-data/audio/qddata_16khz"

if [ -d ${out_dir} ]; then
    rm -rf ${out_dir}
fi
mkdir ${out_dir}

for x in ${in_dir}/*.wav
do
    echo ${in_dir}/${x}
    name=${x##*/}
    sox ${in_dir}/${name} -r 16000 ${out_dir}/${name}
done