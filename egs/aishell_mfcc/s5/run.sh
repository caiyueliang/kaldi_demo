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

. ./cmd.sh

# data=/export/a05/xna/data
# data=/data/ASR/ChineseData/AISHELL
data=/home/rd/caiyueliang/data/AISHELL
data_url=www.openslr.org/resources/33

stage=0
nj=10

gpu_id=2                    # 默认使用的GPU ID
dfsmn_stage=0
dfsmn_feats_gen=0           # 0表示不生成

# feats_type=fbank
feats_type=mfcc
feats_dir=${feats_type}/base

#train_set=train
#dev_set=dev
#test_set=test
train_set=${feats_type}/train_sp_hires_rvb
dev_set=${feats_type}/dev
test_set=${feats_type}/test

. utils/parse_options.sh || exit 1;

echo "[RUN]            data: "${data}
echo "[RUN]           stage: "${stage}
echo "[RUN]              nj: "${nj}
echo "[RUN]          gpu_id: "${gpu_id}
echo "[RUN]     dfsmn_stage: "${dfsmn_stage}
echo "[RUN] dfsmn_feats_gen: "${dfsmn_feats_gen}
echo "[RUN]      feats_type: "${feats_type}
echo "[RUN]       feats_dir: "${feats_dir}
echo "[RUN]       train_set: data/"${train_set}
echo "[RUN]         dev_set: data/"${dev_set}
echo "[RUN]        test_set: data/"${test_set}

## ======================================================================================================================
#if [ ${stage} -le 0 ]; then
#    echo "[RUN] 1 =================================="
#    # local/download_and_untar.sh $data $data_url data_aishell || exit 1;
#    # local/download_and_untar.sh $data $data_url resource_aishell || exit 1;
#
#    echo "[RUN] 2 =================================="
#    # Lexicon Preparation, 词典准备
#    local/aishell_prepare_dict.sh $data/resource_aishell || exit 1;
#
#    # Data Preparation, 数据准备
#    local/aishell_data_prep.sh $data/data_aishell/wav $data/data_aishell/transcript || exit 1;
#fi
#
## ======================================================================================================================
## Phone Sets, questions, L compilation
#if [ ${stage} -le 1 ]; then
#    echo "[RUN] 3 =================================="
#    utils/prepare_lang.sh --position-dependent-phones false data/local/dict \
#        "<SPOKEN_NOISE>" data/local/lang data/lang || exit 1;
#
#    # LM training
#    local/aishell_train_lms.sh || exit 1;
#
#    echo "[RUN] 4 =================================="
#    # G compilation, check LG composition
#    utils/format_lm.sh data/lang data/local/lm/3gram-mincount/lm_unpruned.gz \
#        data/local/dict/lexicon.txt data/lang_test || exit 1;
#fi
#
## ======================================================================================================================
#if [ ${stage} -le 2 ]; then
#    echo "[RUN] 5 =================================="
#    # Now make MFCC plus pitch features.
#    # mfccdir should be some place with a largish disk where you
#    # want to store MFCC features.
#    if [ "${feats_type}" == "fbank" ]; then
#        gen_sctipt="make_fbank_pitch.sh"
#    else
#        gen_sctipt="make_mfcc_pitch.sh"
#    fi
#    echo "[run_dnn.sh] gen_sctipt: "${gen_sctipt}
#
#    for x in ${train_set} ${dev_set} ${test_set}; do
#        steps/${gen_sctipt} --cmd "${train_cmd}" --nj ${nj} \
#            data/${x} exp/make_${feats_type}_log/${x} ${feats_dir}_${x} || exit 1;
#        steps/compute_cmvn_stats.sh data/${x} exp/make_mfcc/${x} ${feats_dir}_${x} || exit 1;
#        utils/fix_data_dir.sh data/${x} || exit 1;
#    done
#fi

# ======================================================================================================================
if [ ${stage} -le 3 ]; then
echo "[RUN] 6 =================================="
    # 单音素模型训练
    steps/train_mono.sh --cmd "${train_cmd}" --nj ${nj} data/${train_set} data/lang exp/mono || exit 1;

    echo "[RUN] 7 =================================="
    # Monophone decoding，解码并生成WER
    utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/mono/graph data/${dev_set} exp/mono/decode_dev
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/mono/graph data/${test_set} exp/mono/decode_test
fi

# ======================================================================================================================
if [ ${stage} -le 4 ]; then
    echo "[RUN] 8 =================================="
    # Get alignments from monophone system. 数据对齐
    steps/align_si.sh --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/mono exp/mono_ali || exit 1;

    echo "[RUN] 9 =================================="
    # train tri1 [first triphone pass]，训练三音素模型。用单音素模型的对齐结果（mono_ali）来训练。
    steps/train_deltas.sh --cmd "$train_cmd" 2500 20000 data/${train_set} data/lang exp/mono_ali exp/tri1 || exit 1;

    echo "[RUN] 10 =================================="
    # decode tri1，解码并生成WER
    utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/tri1/graph data/${dev_set} exp/tri1/decode_dev
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/tri1/graph data/${test_set} exp/tri1/decode_test
fi

# ======================================================================================================================
if [ ${stage} -le 5 ]; then
    echo "[RUN] 11 =================================="
    # align tri1，数据对齐
    steps/align_si.sh --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/tri1 exp/tri1_ali || exit 1;

    echo "[RUN] 12 =================================="
    # train tri2 [delta+delta-deltas]，训练三音素模型。用上一步三音素模型的对齐结果（tri1_ali）来训练，其他参数都一样。
    steps/train_deltas.sh --cmd "$train_cmd" 2500 20000 data/${train_set} data/lang exp/tri1_ali exp/tri2 || exit 1;

    echo "[RUN] 13 =================================="
    # decode tri2，解码并生成WER
    utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/tri2/graph data/${dev_set} exp/tri2/decode_dev
    steps/decode.sh --cmd "$decode_cmd" --config conf/decode.config --nj ${nj} \
        exp/tri2/graph data/${test_set} exp/tri2/decode_test
fi

# ======================================================================================================================
if [ ${stage} -le 6 ]; then
    echo "[RUN] 14 =================================="
    # train and decode tri2b [LDA+MLLT]，数据对齐
    steps/align_si.sh --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/tri2 exp/tri2_ali || exit 1;

    echo "[RUN] 15 =================================="
    # Train tri3a, which is LDA+MLLT，训练三音素模型（LDA+MLLT）
    steps/train_lda_mllt.sh --cmd "$train_cmd" 2500 20000 data/${train_set} data/lang exp/tri2_ali exp/tri3a || exit 1;

    echo "[RUN] 16 =================================="
    # decode tri3，解码并生成WER
    utils/mkgraph.sh data/lang_test exp/tri3a exp/tri3a/graph || exit 1;
    steps/decode.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
        exp/tri3a/graph data/${dev_set} exp/tri3a/decode_dev
    steps/decode.sh --cmd "$decode_cmd" --nj $nj --config conf/decode.config \
        exp/tri3a/graph data/${test_set} exp/tri3a/decode_test
fi

# ======================================================================================================================
if [ ${stage} -le 7 ]; then
    echo "[RUN] 17 =================================="
    # 数据对齐，使用fMLLR的方式
    # From now, we start building a more serious system (with SAT), and we'll
    # do the alignment with fMLLR.
    steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/tri3a exp/tri3a_ali || exit 1;

    echo "[RUN] 18 =================================="
    # 训练模型（sat自然语言适应）
    steps/train_sat.sh --cmd "$train_cmd" 2500 20000 data/${train_set} data/lang exp/tri3a_ali exp/tri4a || exit 1;

    echo "[RUN] 19 =================================="
    # 解码并生成WER，使用fMLLR的方式
    utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
        exp/tri4a/graph data/${dev_set} exp/tri4a/decode_dev || exit 1;
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
        exp/tri4a/graph data/${test_set} exp/tri4a/decode_test || exit 1;
fi

# ======================================================================================================================
if [ ${stage} -le 8 ]; then
    echo "[RUN] 20 =================================="
    # 数据对齐，使用fMLLR的方式
    steps/align_fmllr.sh  --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/tri4a exp/tri4a_ali || exit 1;

    echo "[RUN] 21 =================================="
    # 训练更大的模型（sat自然语言适应）
    # Building a larger SAT system.
    steps/train_sat.sh --cmd "$train_cmd" 3500 100000 data/${train_set} data/lang exp/tri4a_ali exp/tri5a || exit 1;

    echo "[RUN] 22 =================================="
    # 解码并生成WER，使用fMLLR的方式
    utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph || exit 1;
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
        exp/tri5a/graph data/${dev_set} exp/tri5a/decode_dev || exit 1;
    steps/decode_fmllr.sh --cmd "$decode_cmd" --nj ${nj} --config conf/decode.config \
        exp/tri5a/graph data/${test_set} exp/tri5a/decode_test || exit 1;
fi

# ======================================================================================================================
if [ ${stage} -le 9 ]; then
    echo "[RUN] 23 =================================="
    # 数据对齐，使用fMLLR的方式
    steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/${train_set} data/lang exp/tri5a exp/tri5a_ali || exit 1;
    steps/align_fmllr.sh --cmd "$train_cmd" --nj ${nj} data/${dev_set} data/lang exp/tri5a exp/tri5a_ali_cv || exit 1;
fi

# ======================================================================================================================
if [ ${stage} -le 10 ]; then
    echo "[RUN] 24 =================================="
    CUDA_VISIBLE_DEVICES=${gpu_id} nohup bash local/nnet/run_dnn.sh --stage ${dfsmn_stage} \
        --feats_gen ${dfsmn_feats_gen} --nj ${nj} \
        exp/tri5a exp/tri5a_ali exp/tri5a_ali_cv > run_dnn.log 2>&1 &
fi

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
echo "[RUN] 25 =================================="
for x in exp/*/decode_test; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null

exit 0;
