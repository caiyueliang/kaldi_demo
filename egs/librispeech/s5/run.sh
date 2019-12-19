#!/bin/bash

echo " 1 =================================="
# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
# data=/export/a15/vpanayotov/data
data=/home/rd/caiyueliang/data/vpanayotov

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

echo " 2 =================================="
# you might not want to do this for interactive shells.
set -e

echo "17 =================================="
# align train_clean_100 using the tri4b model
# 使用tri4b模型对齐
steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train_clean_100 data/lang exp/tri4b exp/tri4b_ali_clean_100

# if you want at this point you can train and test NN model(s) on the 100 hour
# subset
# 是一个p-norm神经网络"fast"训练和测试脚本，适应40维特征
local/nnet2/run_5a_clean_100.sh

# 下载解压train-clean-360语料
local/download_and_untar.sh $data $data_url train-clean-360

# now add the "clean-360" subset to the mix ...
# 增加clean-360子集，进行数据准备，mfcc，cmvn过程
local/data_prep.sh \
  $data/LibriSpeech/train-clean-360 data/train_clean_360
steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/train_clean_360 \
  exp/make_mfcc/train_clean_360 $mfccdir
steps/compute_cmvn_stats.sh \
  data/train_clean_360 exp/make_mfcc/train_clean_360 $mfccdir

# ... and then combine the two sets into a 460 hour one
# 结合两个集合：100h+360h
utils/combine_data.sh \
  data/train_clean_460 data/train_clean_100 data/train_clean_360

echo "18 =================================="
# align the new, combined set, using the tri4b model
# 使用tri4b模型对齐和结合新数据集
steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
  data/train_clean_460 data/lang exp/tri4b exp/tri4b_ali_clean_460

# create a larger SAT model, trained on the 460 hours of data.
# 创建一个更大的说话人自适应模型，训练460小时数据生成tri5b
steps/train_sat.sh  --cmd "$train_cmd" 5000 100000 \
  data/train_clean_460 data/lang exp/tri4b_ali_clean_460 exp/tri5b

echo "19 =================================="
# decode using the tri5b model
# 使用tri5b模型生成HCLG图
(
  utils/mkgraph.sh data/lang_test_tgsmall \
    exp/tri5b exp/tri5b/graph_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
      exp/tri5b/graph_tgsmall data/$test \
      exp/tri5b/decode_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      data/$test exp/tri5b/decode_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/$test exp/tri5b/decode_{tgsmall,tglarge}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
      data/$test exp/tri5b/decode_{tgsmall,fglarge}_$test
  done
)&

echo "20 =================================="
# train a NN model on the 460 hour set
# 用460小时数据训练神经网络模型
local/nnet2/run_6a_clean_460.sh

# 下载train-other-500语料
local/download_and_untar.sh $data $data_url train-other-500

# prepare the 500 hour subset.
# 再次增加clean-500子集，进行数据准备，mfcc，cmvn过程
local/data_prep.sh \
  $data/LibriSpeech/train-other-500 data/train_other_500
steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/train_other_500 \
  exp/make_mfcc/train_other_500 $mfccdir
steps/compute_cmvn_stats.sh \
  data/train_other_500 exp/make_mfcc/train_other_500 $mfccdir

# combine all the data
# 结合所有数据，共960小时
utils/combine_data.sh \
  data/train_960 data/train_clean_460 data/train_other_500

steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
  data/train_960 data/lang exp/tri5b exp/tri5b_ali_960

echo "21 =================================="
# train a SAT model on the 960 hour mixed data.  Use the train_quick.sh script
# as it is faster.
# 使用960小时混合数据训练说话人自适应模型
steps/train_quick.sh --cmd "$train_cmd" \
  7000 150000 data/train_960 data/lang exp/tri5b_ali_960 exp/tri6b

# decode using the tri6b model
# 生成HCLG图
(
  utils/mkgraph.sh data/lang_test_tgsmall \
    exp/tri6b exp/tri6b/graph_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
      exp/tri6b/graph_tgsmall data/$test exp/tri6b/decode_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      data/$test exp/tri6b/decode_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/$test exp/tri6b/decode_{tgsmall,tglarge}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
      data/$test exp/tri6b/decode_{tgsmall,fglarge}_$test
  done
)&

# this does some data-cleaning. The cleaned data should be useful when we add
# the neural net and chain systems.
# 清理数据
local/run_cleanup_segmentation.sh

# steps/cleanup/debug_lexicon.sh --remove-stress true  --nj 200 --cmd "$train_cmd" data/train_clean_100 \
#    data/lang exp/tri6b data/local/dict/lexicon.txt exp/debug_lexicon_100h

# #Perform rescoring of tri6b be means of faster-rnnlm
# #Attention: with default settings requires 4 GB of memory per rescoring job, so commenting this out by default
# wait && local/run_rnnlm.sh \
#     --rnnlm-ver "faster-rnnlm" \
#     --rnnlm-options "-hidden 150 -direct 1000 -direct-order 5" \
#     --rnnlm-tag "h150-me5-1000" $data data/local/lm

# #Perform rescoring of tri6b be means of faster-rnnlm using Noise contrastive estimation
# #Note, that could be extremely slow without CUDA
# #We use smaller direct layer size so that it could be stored in GPU memory (~2Gb)
# #Suprisingly, bottleneck here is validation rather then learning
# #Therefore you can use smaller validation dataset to speed up training
# wait && local/run_rnnlm.sh \
#     --rnnlm-ver "faster-rnnlm" \
#     --rnnlm-options "-hidden 150 -direct 400 -direct-order 3 --nce 20" \
#     --rnnlm-tag "h150-me3-400-nce20" $data data/local/lm


# train nnet3 tdnn models on the entire data with data-cleaning (xent and chain)
# 训练TDNN（时延神经网络）模型
#local/chain/run_tdnn.sh # set "--stage 11" if you have already run local/nnet3/run_tdnn.sh

# The nnet3 TDNN recipe:
# local/nnet3/run_tdnn.sh # set "--stage 11" if you have already run local/chain/run_tdnn.sh

# # train models on cleaned-up data
# # we've found that this isn't helpful-- see the comments in local/run_data_cleaning.sh
# local/run_data_cleaning.sh

# # The following is the current online-nnet2 recipe, with "multi-splice".
# local/online/run_nnet2_ms.sh

# # The following is the discriminative-training continuation of the above.
# local/online/run_nnet2_ms_disc.sh

# ## The following is an older version of the online-nnet2 recipe, without "multi-splice".  It's faster
# ## to train but slightly worse.
# # local/online/run_nnet2.sh


echo "22 =================================="
# ## Traing FSMN models on the cleaned-up data
# ## Three configurations of DFSMN with different model size: DFSMN_S, DFSMN_M, DFSMN_L
bash local/nnet/run_fsmn_ivector.sh DFSMN_S
# local/nnet/run_fsmn_ivector.sh DFSMN_M
# local/nnet/run_fsmn_ivector.sh DFSMN_L

# Wait for decodings in the background


# Wait for decodings in the background
wait
