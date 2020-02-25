#!/bin/bash
# Description :  generate subset utt data randomly.
# Author :       caiyueliang
# Date :         2020/02/24
# Detail:

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

. utils/parse_options.sh || exit 1;

src_dir=$1
output_dir=$2
echo "[gen_sub_utt]    src_dir: "${src_dir}
echo "[gen_sub_utt] output_dir: "${output_dir}

# start_time=`date +"%Y-%m-%d %H:%M:%S"`
# echo "[gen_sub_utt] start time: "${start_time}

# 按一定规则随机生成utt子集列表
# python ./local/gen_sub_utt.py --src_dir "/home/rd/caiyueliang/kaldi-trunk/egs/aishell_en/s5/data/fbank/train_sp_hires"
python ./local/gen_sub_utt.py --src_dir ${src_dir} || exit 1

# 提取utt子集数据
utils/subset_data_dir.sh --utt-list ${src_dir}/random_utt_list ${src_dir}/ ${output_dir} || exit 1
utils/fix_data_dir.sh ${output_dir} || exit 1

# start_time=`date +"%Y-%m-%d %H:%M:%S"`
# echo "[gen_sub_utt] end time: "${start_time}