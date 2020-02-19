#!/bin/bash

# Copyright 2017 Beijing Shell Shell Tech. Co. Ltd. (Authors: Hui Bu)
#           2017 Jiayu Du
#           2017 Xingyu Na
#           2017 Bengu Wu
#           2017 Hao Zheng
# Apache 2.0

# This is a shell script, but it's recommended that you run the commands one by
# one by copying and pasting into the shell.
# Caution: some of the graph creation steps use quite a bit of memory, so you
# should run this on a machine that has sufficient memory.

# data=/export/a05/xna/data
# data=/data/ASR/ChineseData/AISHELL
data=/home/rd/caiyueliang/data/AISHELL
# data=/home/rd/caiyueliang/data/AISHELL_EN
data_url=www.openslr.org/resources/33

. ./cmd.sh

nj=10

echo "[RUN] data: "${data}
echo "[RUN]   nj: "${nj}

echo "[RUN] 1 =================================="
# local/download_and_untar.sh $data $data_url data_aishell || exit 1;
# local/download_and_untar.sh $data $data_url resource_aishell || exit 1;

echo "[RUN] 2 =================================="
# Lexicon Preparation, 词典准备
local/aishell_prepare_dict.sh $data/resource_aishell || exit 1;

# Data Preparation, 数据准备
local/aishell_data_prep.sh $data/data_aishell/wav $data/data_aishell/transcript || exit 1;

# ======================================================================================================================
# Phone Sets, questions, L compilation
utils/prepare_lang.sh --position-dependent-phones false data/local/dict \
    "<SPOKEN_NOISE>" data/local/lang data/lang || exit 1;

echo "[RUN] 3 =================================="
# LM training
local/aishell_train_lms.sh || exit 1;

echo "[RUN] 4 =================================="
# G compilation, check LG composition
utils/format_lm.sh data/lang data/local/lm/3gram-mincount/lm_unpruned.gz \
    data/local/dict/lexicon.txt data/lang_test || exit 1;

echo "[RUN] 5 =================================="
# Now make MFCC plus pitch features. 生成 MFCC 特征
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
# mfccdir=mfcc/base
mfccdir=fbank/base
for x in train dev test; do
  # steps/make_mfcc_pitch.sh --cmd "${train_cmd}" --nj ${nj} data/${x} exp/make_mfcc/${x} ${mfccdir}_${x} || exit 1;
  # steps/make_fbank.sh --cmd "${train_cmd}" --nj ${nj} data/${x} exp/make_mfcc/${x} ${mfccdir}_${x} || exit 1;
  steps/make_fbank_pitch.sh --cmd "${train_cmd}" --nj ${nj} data/${x} exp/make_mfcc/${x} ${mfccdir}_${x} || exit 1;
  steps/compute_cmvn_stats.sh data/${x} exp/make_mfcc/${x} ${mfccdir}_${x} || exit 1;
  utils/fix_data_dir.sh data/${x}_${x} || exit 1;
done

# ======================================================================================================================
echo "[RUN] 6 =================================="
# 单音素模型训练
steps/train_mono.sh --cmd "${train_cmd}" --nj ${nj} data/train data/lang exp/mono || exit 1;

echo "[RUN] 7 =================================="
# Monophone decoding，解码并生成WER
utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/mono/graph data/dev exp/mono/decode_dev
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/mono/graph data/test exp/mono/decode_test

echo "[RUN] 8 =================================="
# Get alignments from monophone system. 数据对齐
steps/align_si.sh --cmd "$train_cmd" --nj ${nj} \
  data/train data/lang exp/mono exp/mono_ali || exit 1;

echo "[RUN] 9 =================================="
# train tri1 [first triphone pass]，训练三音素模型。用单音素模型的对齐结果（mono_ali）来训练。
steps/train_deltas.sh --cmd "$train_cmd" \
 2500 20000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;

echo "[RUN] 10 =================================="
# decode tri1，解码并生成WER
utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/tri1/graph data/dev exp/tri1/decode_dev
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/tri1/graph data/test exp/tri1/decode_test

echo "[RUN] 11 =================================="
# align tri1，数据对齐
steps/align_si.sh --cmd "$train_cmd" --nj ${nj} \
  data/train data/lang exp/tri1 exp/tri1_ali || exit 1;

echo "[RUN] 12 =================================="
# train tri2 [delta+delta-deltas]，训练三音素模型。用上一步三音素模型的对齐结果（tri1_ali）来训练，其他参数都一样。
steps/train_deltas.sh --cmd "$train_cmd" \
 2500 20000 data/train data/lang exp/tri1_ali exp/tri2 || exit 1;

echo "[RUN] 13 =================================="
# decode tri2，解码并生成WER
utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/tri2/graph data/dev exp/tri2/decode_dev
steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
  exp/tri2/graph data/test exp/tri2/decode_test

echo "[RUN] 14 =================================="
# train and decode tri2b [LDA+MLLT]，数据对齐
steps/align_si.sh --cmd "$train_cmd" --nj ${nj} \
  data/train data/lang exp/tri2 exp/tri2_ali || exit 1;

echo "[RUN] 15 =================================="
# Train tri3a, which is LDA+MLLT，训练三音素模型（LDA+MLLT）
steps/train_lda_mllt.sh --cmd "$train_cmd" \
 2500 20000 data/train data/lang exp/tri2_ali exp/tri3a || exit 1;

echo "[RUN] 16 =================================="
# decode tri3，解码并生成WER
utils/mkgraph.sh data/lang_test exp/tri3a exp/tri3a/graph || exit 1;
steps/decode.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
  exp/tri3a/graph data/dev exp/tri3a/decode_dev
steps/decode.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
  exp/tri3a/graph data/test exp/tri3a/decode_test

echo "[RUN] 17 =================================="
# 数据对齐，使用fMLLR的方式
# From now, we start building a more serious system (with SAT), and we'll
# do the alignment with fMLLR.
steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/train data/lang exp/tri3a exp/tri3a_ali || exit 1;

echo "[RUN] 18 =================================="
# 训练模型（sat自然语言适应）
steps/train_sat.sh --cmd "$train_cmd" 2500 20000 data/train data/lang exp/tri3a_ali exp/tri4a || exit 1;

echo "[RUN] 19 =================================="
# 解码并生成WER，使用fMLLR的方式
utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config exp/tri4a/graph data/dev exp/tri4a/decode_dev || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config exp/tri4a/graph data/test exp/tri4a/decode_test || exit 1;

echo "[RUN] 20 =================================="
# 数据对齐，使用fMLLR的方式
steps/align_fmllr.sh  --cmd "$train_cmd" --nj ${nj} data/train data/lang exp/tri4a exp/tri4a_ali || exit 1;

echo "[RUN] 21 =================================="
# 训练更大的模型（sat自然语言适应）
# Building a larger SAT system.
steps/train_sat.sh --cmd "$train_cmd" \
  3500 100000 data/train data/lang exp/tri4a_ali exp/tri5a || exit 1;

echo "[RUN] 22 =================================="
# 解码并生成WER，使用fMLLR的方式
utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config exp/tri5a/graph data/dev exp/tri5a/decode_dev || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config exp/tri5a/graph data/test exp/tri5a/decode_test || exit 1;

echo "[RUN] 23 =================================="
# 数据对齐，使用fMLLR的方式
steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/train data/lang exp/tri5a exp/tri5a_ali || exit 1;
steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/dev data/lang exp/tri5a exp/tri5a_ali_cv || exit 1;

echo "[RUN] 24 =================================="
CUDA_VISIBLE_DEVICES=2 nohup bash local/nnet/run_dnn.sh --stage 0 --feats_gen 1 --nj 8 exp/tri5a exp/tri5a_ali exp/tri5a_ali_cv > run_dnn.log 2>&1 &

#echo "[RUN] 24 =================================="
## nnet3
#local/nnet3/run_tdnn.sh
#
#echo "[RUN] 25 =================================="
## chain
#local/chain/run_tdnn.sh
#
#echo "[RUN] 26 =================================="
## getting results (see RESULTS file)
#for x in exp/*/decode_test; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null

exit 0;
