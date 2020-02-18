#!/bin/bash
#Copyright 2016  Tsinghua University (Author: Dong Wang, Xuewei Zhang).  Apache 2.0.

#run from ../..
#DNN training, both xent and MPE

echo "[run_dnn.sh] 1 =================================="
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

stage=0
nj=8
nnet_init=
learn_rate=0.00001
max_iters=20
min_iters=0
start_half_lr=3
momentum=0.9
dropout_schedule="0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3"
# dnn_model=DFSMN_S
dnn_model=DFSMN_L
dir=exp/tri7b_${dnn_model}
feats_gen=0
feats_type=fbank
# feats_type=mfcc
data_fbk=data/${feats_type}
train_set=train
dev_set=dev
test_set=test
speed_perturb=1
volume_perturb=1
acwt=0.08
lang=data/lang

echo "[run_dnn.sh]           dir: "${dir}
echo "[run_dnn.sh]      cuda_cmd: "${cuda_cmd}
echo "[run_dnn.sh]     feats_gen: "${feats_gen}
echo "[run_dnn.sh]    feats_type: "${feats_type}
echo "[run_dnn.sh]    learn_rate: "${learn_rate}
echo "[run_dnn.sh]     max_iters: "${max_iters}
echo "[run_dnn.sh]     min_iters: "${min_iters}
echo "[run_dnn.sh] start_half_lr: "${start_half_lr}
echo "[run_dnn.sh]      momentum: "${momentum}
echo "[run_dnn.sh]       dropout: "${dropout_schedule}
echo "[run_dnn.sh]     dnn_model: "${dnn_model}
echo "[run_dnn.sh]      data_fbk: "${data_fbk}
echo "[run_dnn.sh]     train_set: "${train_set}
echo "[run_dnn.sh]       dev_set: "${dev_set}
echo "[run_dnn.sh]      test_set: "${test_set}
echo "[run_dnn.sh] speed_perturb: "${speed_perturb}
echo "[run_dnn.sh]volume_perturb: "${volume_perturb}
echo "[run_dnn.sh]          acwt: "${acwt}
echo "[run_dnn.sh]          lang: "${lang}

. utils/parse_options.sh || exit 1;

gmmdir=$1
alidir=$2
alidir_cv=$3
echo "[run_dnn.sh]     gmmdir: "${gmmdir}
echo "[run_dnn.sh]     alidir: "${alidir}
echo "[run_dnn.sh]  alidir_cv: "${alidir_cv}
echo "[run_dnn.sh]  nnet_init: "${nnet_init}

### ======================================================================================================================
echo "[run_dnn.sh] 0 =================================="
# 根据使用的特征类型，选择对应的生成脚本
if [ ${feats_type} == "fbank" ]; then
    gen_sctipt="make_fbank.sh"
else
    gen_sctipt="make_mfcc_pitch.sh"
fi
echo "[run_dnn.sh] gen_sctipt: "${gen_sctipt}

if [ ${feats_gen} -ne 0 ]; then
    echo "[run_dnn.sh] Re-generate features data ..."

    # 添加音速扰动
    if [ ${speed_perturb} -ne 0 ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: preparing directory for speed-perturbed data"
        echo "[run_dnn.sh] ============================================ "
        utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true data/${train_set} ${data_fbk}/${train_set}_sp || exit 1;
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${train_set}_sp;
        new_train_set=${train_set}_sp
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "

        # 数据对齐: ${gmmdir}，输出目录${alidir}是：s5/exp/tri5a_sp_ali ...
        alidir=${gmmdir}_sp_ali
        echo "$0: aligning with the perturbed low-resolution data"
        steps/align_fmllr.sh --nj ${nj} --cmd "$train_cmd" ${data_fbk}/${train_set} ${lang} ${gmmdir} ${alidir} || exit 1
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new alidir set : "${alidir}
        echo "[run_dnn.sh] ============================================ "
    fi

    # 添加音量扰动
    if [ ${volume_perturb} -ne 0 ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp_hires ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp_hires ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: preparing directory for volume-perturbed data"
        echo "[run_dnn.sh] ============================================ "
        utils/copy_data_dir.sh ${data_fbk}/${train_set} ${data_fbk}/${train_set}_hires || exit 1;
        utils/data/perturb_data_dir_volume.sh ${data_fbk}/${train_set}_hires || exit 1;
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${train_set}_hires;

        new_train_set=${train_set}_hires
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi

    # 生成FBank特征，是40维FBank
    echo "[run_dnn.sh] use fbank ..."
    # cp -R data/{train,dev,test} ${data_fbk} || exit 1;
    # cp -R data/${train_set} ${data_fbk} || exit 1;
    cp -R data/${dev_set} ${data_fbk} || exit 1;
    cp -R data/${test_set} ${data_fbk} || exit 1;
    # ==========================================================================================================
    # data_fbk=data/fbank
    # train_dir=data/fbank/train
    # train_dir=data/fbank/train_sp_hires
    # dev_dir=data/fbank/dev
    # test_dir=data/fbank/test
    # for x in train dev test; do
    #     echo "[run_dnn.sh] producing fbank for ${x}"
    #     # steps/make_fbank.sh --cmd "${train_cmd}" --nj ${nj} ${data} ${logdir} ${fbankdir}
    #     steps/make_fbank.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${x} exp/make_fbank_log/${x} fbank/${x} || exit 1
    #     steps/compute_cmvn_stats.sh ${data_fbk}/${x} exp/make_fbank_log/${x} fbank/${x} || exit 1
    # done
    for x in ${dev_set} ${test_set}; do
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] producing "${feats_type}" for "${x}
        # steps/make_fbank.sh --cmd "${train_cmd}" --nj ${nj} ${data} ${logdir} ${fbankdir}
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
    done
else
    # 有加音速扰动
    if [ ${speed_perturb} -ne 0 ]; then
        new_train_set=${train_set}_sp
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
        alidir=${gmmdir}_sp_ali
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new alidir set : "${alidir}
        echo "[run_dnn.sh] ============================================ "
    fi
    # 有加音量扰动
    if [ ${volume_perturb} -ne 0 ]; then
        new_train_set=${train_set}_hires
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi
fi


# ======================================================================================================================
# CE-training
echo "[run_dnn.sh] 1 =================================="
if [ ${stage} -le 1 ]; then
    # proto=local/nnet/${dnn_model}.proto
    proto=local/nnet/${dnn_model}"_"${feats_type}.proto
    echo "[run_dnn.sh]    proto: "${proto}
    ori_num_pdf=`cat $proto |grep "Softmax" |awk '{print $3}'`
    echo "[run_dnn.sh] ori_num_pdf: "$ori_num_pdf

    # # ======================================================================
    # # proto使用默认的
    # new_proto=${proto}
    # echo "[run_dnn.sh] new proto: "${new_proto}
    # ======================================================================
    # proto使用自动获取的
    new_num_pdf=`gmm-info ${gmmdir}/final.mdl |grep "number of pdfs" |awk '{print $4}'`
    echo "[run_dnn.sh] new_num_pdf: "$new_num_pdf
    new_proto=${proto}.${new_num_pdf}
    sed -r "s/"${ori_num_pdf}"/"${new_num_pdf}"/g" ${proto} > ${new_proto}
    # ======================================================================

    if [ ! -z ${nnet_init} ]; then
        # 执行脚本train_faster.sh，使用预训练模型进行训练
        echo "[run_dnn.sh] 使用预训练模型进行训练 : "${nnet_init}
        ${cuda_cmd} ${dir}/train_faster_nnet.log \
            steps/nnet/train_faster.sh --nnet-proto ${new_proto} --learn-rate ${learn_rate} \
            --max_iters ${max_iters} --start_half_lr ${start_half_lr} --momentum ${momentum} \
            --min_iters ${min_iters} \
            --dropout_schedule ${dropout_schedule} \
            --train-tool "nnet-train-fsmn-streams" \
            --feat-type plain --splice 1 \
            --cmvn-opts "--norm-means=true --norm-vars=false" --delta_opts "--delta-order=2" \
            --train-tool-opts "--minibatch-size=4096" \
            --nnet_init ${nnet_init} \
            --skip_phoneset_check "true" \
            ${data_fbk}/${train_set} ${data_fbk}/${dev_set} ${lang} ${alidir} ${alidir_cv} ${dir} || exit 1;
    else
        echo "[run_dnn.sh] 不使用预训练模型进行训练 ... "
        # 执行脚本train_faster.sh
        ${cuda_cmd} ${dir}/train_faster_nnet.log \
            steps/nnet/train_faster.sh --nnet-proto ${new_proto} --learn-rate ${learn_rate} \
            --max_iters ${max_iters} --start_half_lr ${start_half_lr} --momentum ${momentum} \
            --min_iters ${min_iters} \
            --dropout_schedule ${dropout_schedule} \
            --train-tool "nnet-train-fsmn-streams" \
            --feat-type plain --splice 1 \
            --cmvn-opts "--norm-means=true --norm-vars=false" --delta_opts "--delta-order=2" \
            --train-tool-opts "--minibatch-size=4096" \
            ${data_fbk}/${train_set} ${data_fbk}/${dev_set} ${lang} ${alidir} ${alidir_cv} ${dir} || exit 1;
    fi
fi

echo "[run_dnn.sh] 2 =================================="
if [ ${stage} -le 2 ]; then
    # Decode
    echo "[run_dnn.sh][Decode] "
    # steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
    #     ${gmmdir}/graph ${data_fbk}/test ${dir}/decode_test_word || exit 1;
    # dataset="test dev"
    for set in ${test_set} ${dev_set} ; do
        steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
            ${gmmdir}/graph ${data_fbk}/${set} ${dir}/decode_${set}_word || exit 1;
    done
 	for x in ${dir}/decode_*; do
 	    echo "[run_dnn.sh][best_wer] dir: "${x}
        grep WER ${x}/wer_* | utils/best_wer.sh
 	done
fi

echo "[run_dnn.sh] 3 =================================="
# gen ali & lat for smbr
if [ ${stage} -le 3 ]; then
    steps/nnet/align.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set} ${lang} ${dir} ${dir}_ali
    steps/nnet/make_denlats.sh --nj ${nj} --cmd "${decode_cmd}" --acwt ${acwt} \
        ${data_fbk}/${train_set} ${lang} ${dir} ${dir}_denlats
fi

echo "[run_dnn.sh] 4 =================================="
####do smbr
if [ ${stage} -le 4 ]; then
    steps/nnet/train_mpe.sh --cmd "${cuda_cmd}" --num-iters 1 --learn-rate 0.0000002 --acwt ${acwt} --do-smbr true \
        ${data_fbk}/${train_set} ${lang} ${dir} ${dir}_ali ${dir}_denlats ${dir}_smbr
fi

###decode
echo "[run_dnn.sh] 5 =================================="
dir=${dir}_smbr
acwt=0.03
echo "[run_dnn.sh] 5  dir: "${dir}
echo "[run_dnn.sh] 5 acwt: "${acwt}

if [ $stage -le 5 ]; then
    # dataset="test dev"
    for set in ${test_set} ${dev_set} ; do
        # steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
        #     ${gmmdir}/graph_word ${data_fbk}/test ${dir}/decode_test_word || exit 1;
        steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
            ${gmmdir}/graph ${data_fbk}/${set} ${dir}/decode_${set}_word || exit 1;
    done
    for x in ${dir}/decode_*; do
        echo "[run_dnn.sh] 5 [best_wer] dir: "${x}
        grep WER ${x}/wer_* | utils/best_wer.sh
    done
fi
