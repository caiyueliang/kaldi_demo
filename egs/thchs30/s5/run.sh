#!/bin/bash

echo " 1 =================================="
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh

H=`pwd`  #exp home
n=8      #parallel jobs

#corpus and trans directory
# thchs=/nfs/public/materials/data/thchs30-openslr
# thchs=/home/rd/caiyueliang/kaldi-trunk/data
thchs=/home/rd/caiyueliang/data/THCHS-30

#you can obtain the database by uncommting the following lines
[ -d $thchs ] || mkdir -p $thchs  || exit 1
echo "downloading THCHS30 at $thchs ..."
local/download_and_untar.sh $thchs  http://www.openslr.org/resources/18 data_thchs30  || exit 1
local/download_and_untar.sh $thchs  http://www.openslr.org/resources/18 resource      || exit 1
local/download_and_untar.sh $thchs  http://www.openslr.org/resources/18 test-noise    || exit 1

echo " 2 =================================="
#data preparation, 数据准备
#generate text, wav.scp, utt2pk, spk2utt
local/thchs-30_data_prep.sh $H $thchs/data_thchs30 || exit 1;

# ======================================================================================================================
echo " 3 =================================="
#produce MFCC features, 生成 MFCC 特征
rm -rf data/mfcc && mkdir -p data/mfcc &&  cp -R data/{train,dev,test,test_phone} data/mfcc || exit 1;
for x in train dev test; do
   #make  mfcc
   steps/make_mfcc.sh --nj $n --cmd "$train_cmd" data/mfcc/$x exp/make_mfcc/$x mfcc/$x || exit 1;
   #compute cmvn
   steps/compute_cmvn_stats.sh data/mfcc/$x exp/mfcc_cmvn/$x mfcc/$x || exit 1;
done
#copy feats and cmvn to test.ph, avoid duplicated mfcc & cmvn
cp data/mfcc/test/feats.scp data/mfcc/test_phone && cp data/mfcc/test/cmvn.scp data/mfcc/test_phone || exit 1;


echo " 4 =================================="
#prepare language stuff, 准备语言材料
#build a large lexicon that invovles words in both the training and decoding.
(
  echo "make word graph ..."
  cd $H; mkdir -p data/{dict,lang,graph} && \
  cp $thchs/resource/dict/{extra_questions.txt,nonsilence_phones.txt,optional_silence.txt,silence_phones.txt} data/dict && \
  cat $thchs/resource/dict/lexicon.txt $thchs/data_thchs30/lm_word/lexicon.txt | \
      grep -v -a '<s>' | grep -v -a '</s>' | sort -u > data/dict/lexicon.txt || exit 1;
  utils/prepare_lang.sh --position_dependent_phones false data/dict "<SPOKEN_NOISE>" data/local/lang data/lang || exit 1;
  gzip -c $thchs/data_thchs30/lm_word/word.3gram.lm > data/graph/word.3gram.lm.gz || exit 1;
  utils/format_lm.sh data/lang data/graph/word.3gram.lm.gz $thchs/data_thchs30/lm_word/lexicon.txt data/graph/lang || exit 1;
)

echo " 5 =================================="
#make_phone_graph, 生成音素图
(
  echo "make phone graph ..."
  cd $H; mkdir -p data/{dict_phone,graph_phone,lang_phone} && \
  cp $thchs/resource/dict/{extra_questions.txt,nonsilence_phones.txt,optional_silence.txt,silence_phones.txt} data/dict_phone  && \
  cat $thchs/data_thchs30/lm_phone/lexicon.txt | grep -v '<eps>' | sort -u > data/dict_phone/lexicon.txt  && \
  echo "<SPOKEN_NOISE> sil " >> data/dict_phone/lexicon.txt  || exit 1;
  utils/prepare_lang.sh --position_dependent_phones false data/dict_phone "<SPOKEN_NOISE>" data/local/lang_phone data/lang_phone || exit 1;
  gzip -c $thchs/data_thchs30/lm_phone/phone.3gram.lm > data/graph_phone/phone.3gram.lm.gz  || exit 1;
  utils/format_lm.sh data/lang_phone data/graph_phone/phone.3gram.lm.gz $thchs/data_thchs30/lm_phone/lexicon.txt \
    data/graph_phone/lang  || exit 1;
)

# ======================================================================================================================
echo " 6 =================================="
#monophone, 用来训练单音素隐马尔科夫模型，一共进行40次迭代，每两次迭代进行一次对齐操作
steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/mono || exit 1;
#test monophone model, 解码并生成WER
local/thchs-30_decode.sh --mono true --nj $n "steps/decode.sh" exp/mono data/mfcc &

echo " 7 =================================="
#monophone_ali, 单音素隐马尔科夫模型对齐
steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/mono exp/mono_ali || exit 1;

echo " 8 =================================="
#triphone, 用来训练与上下文相关的三音素模型
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 2000 10000 data/mfcc/train data/lang exp/mono_ali exp/tri1 || exit 1;
#test tri1 model, 解码并生成WER
local/thchs-30_decode.sh --nj $n "steps/decode.sh" exp/tri1 data/mfcc &

echo " 9 =================================="
#triphone_ali, 三音素隐马尔科夫模型对齐
steps/align_si.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri1 exp/tri1_ali || exit 1;

echo "10 =================================="
#lda_mllt, 进行线性判别分析和最大似然线性转换
steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 data/mfcc/train data/lang exp/tri1_ali exp/tri2b || exit 1;
#test tri2b model, 解码并生成WER
local/thchs-30_decode.sh --nj $n "steps/decode.sh" exp/tri2b data/mfcc &

echo "11 =================================="
#lda_mllt_ali, 对齐
steps/align_si.sh  --nj $n --cmd "$train_cmd" --use-graphs true data/mfcc/train data/lang exp/tri2b exp/tri2b_ali || exit 1;

echo "12 =================================="
#sat 训练发音人自适应，基于特征空间最大似然线性回归
steps/train_sat.sh --cmd "$train_cmd" 2500 15000 data/mfcc/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
#test tri3b model, 解码并生成WER
local/thchs-30_decode.sh --nj $n "steps/decode_fmllr.sh" exp/tri3b data/mfcc &

echo "13 =================================="
#sat_ali, 数据对齐，使用fMLLR的方式
steps/align_fmllr.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri3b exp/tri3b_ali || exit 1;

echo "14 =================================="
#quick 在现有特征上训练模型。对于当前模型中在树构建之后的每个状态，它基于树统计中的计数的重叠判断的相似性来选择旧模型中最接近的状态。
steps/train_quick.sh --cmd "$train_cmd" 4200 40000 data/mfcc/train data/lang exp/tri3b_ali exp/tri4b || exit 1;
#test tri4b model, 解码并生成WER
local/thchs-30_decode.sh --nj $n "steps/decode_fmllr.sh" exp/tri4b data/mfcc &

echo "15 =================================="
#quick_ali, 训练集数据对齐，使用fMLLR的方式
steps/align_fmllr.sh --nj $n --cmd "$train_cmd" data/mfcc/train data/lang exp/tri4b exp/tri4b_ali || exit 1;
#quick_ali_cv, 测试集数据对齐，使用fMLLR的方式
steps/align_fmllr.sh --nj $n --cmd "$train_cmd" data/mfcc/dev data/lang exp/tri4b exp/tri4b_ali_cv || exit 1;

echo "16 =================================="
# train dnn model, 训练DNN，包括xent和MPE
# run_dnn.sh里有train_mpe.sh 用来训练dnn的序列辨别MEP/sMBR。
local/nnet/run_dnn.sh --stage 0 --nj $n  exp/tri4b exp/tri4b_ali exp/tri4b_ali_cv || exit 1;

echo "17 =================================="
# train dae model 用来实验基于dae的去噪效果
# python2.6 or above is required for noisy data generation.
# To speed up the process, pyximport for python is recommeded.
local/dae/run_dae.sh $thchs || exit 1;