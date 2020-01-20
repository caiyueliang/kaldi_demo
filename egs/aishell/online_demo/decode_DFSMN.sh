#!/bin/bash

# data=/export/a05/xna/data
# data=/data/ASR/ChineseData/AISHELL
# data=/home/rd/caiyueliang/data/AISHELL
in_dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell/online_demo/online-data/audio/qddata_16khz"
out_dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell/online_demo/tmp_data"

. ./cmd.sh

nj=1
acwt=0.08
dnn_model=DFSMN_L
dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell_old_0119/s5/exp/tri7b_"${dnn_model}
gmm_dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell_old_0119/s5/exp/tri5a"

echo "[Decode]    in_dir: "${in_dir}
echo "[Decode]   out_dir: "${out_dir}
echo "[Decode]        nj: "${nj}
echo "[Decode]      acwt: "${acwt}
echo "[Decode] dnn_model: "${dnn_model}
echo "[Decode]       dir: "${dir}
echo "[Decode]   gmm_dir: "${gmm_dir}

# ======================================================================================================================
echo "[Decode] 1 =================================="
# 生成 MFCC 特征
rm -rf ${out_dir}/mfcc && mkdir -p ${out_dir}/mfcc || exit 1;
for x in test; do
    echo "[Decode] producing mfcc for ${x}"
    mkdir -p ${out_dir}/mfcc/${x} && cp -R ${in_dir}/{wav.scp,spk2utt,utt2spk} ${out_dir}/mfcc/${x} || exit 1;
    steps/make_mfcc_pitch.sh --cmd "${train_cmd}" --nj ${nj} ${out_dir}/mfcc/${x} ${out_dir}/make_mfcc/${x} ${out_dir}/mfcc/${x} || exit 1;
    steps/compute_cmvn_stats.sh ${out_dir}/mfcc/${x} ${out_dir}/make_mfcc/${x} ${out_dir}/mfcc/${x} || exit 1;
done

## ======================================================================================================================
echo "[Decode] 2 =================================="
# 生成FBank特征，是40维FBank
rm -rf ${out_dir}/fbank && mkdir -p ${out_dir}/fbank || exit 1;
for x in test; do
    echo "[Decode] producing fbank for ${x}"
    mkdir -p ${out_dir}/fbank/${x} && cp -R ${in_dir}/{wav.scp,spk2utt,utt2spk} ${out_dir}/fbank/${x} || exit 1;
    steps/make_fbank.sh --nj ${nj} --cmd "${train_cmd}" ${out_dir}/fbank/${x} ${out_dir}/make_fbank/${x} ${out_dir}/fbank/${x} || exit 1
    steps/compute_cmvn_stats.sh ${out_dir}/fbank/${x} ${out_dir}/make_fbank/${x} ${out_dir}/fbank/${x} || exit 1
done

# ======================================================================================================================
# Decode
echo "[Decode] 3 =================================="
echo "[Decode] dir: "${out_dir}"/decode_test_word"
steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
    ${gmm_dir}/graph ${out_dir}/fbank/test ${out_dir}/decode_test_word || exit 1;

#for x in ${out_dir}/decode_*;
#do
# 	echo "[FSMN][CE-training][best_wer] dir: "${x}
#    grep WER ${x}/wer_* | utils/best_wer.sh
#done

# ======================================================================================================================
#echo "[RUN] 26 =================================="
## getting results (see RESULTS file)
#for x in exp/*/decode_test; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null

exit 0;
