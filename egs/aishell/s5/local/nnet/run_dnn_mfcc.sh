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
start_half_lr=5
momentum=0.9
dropout_schedule="0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2"
# dnn_model=DFSMN_S
dnn_model=DFSMN_L
dir=exp/tri7b_${dnn_model}
feats_gen=0
# feats_type=fbank
feats_type=mfcc
data_fbk=data/${feats_type}
train_set=train
dev_set=dev
test_set=test
data_en=1
acwt=0.08

echo "[run_dnn.sh]           dir: "${dir}
echo "[run_dnn.sh]      cuda_cmd: "${cuda_cmd}
echo "[run_dnn.sh]     feats_gen: "${feats_gen}
echo "[run_dnn.sh]    feats_type: "${feats_type}
echo "[run_dnn.sh]    learn_rate: "${learn_rate}
echo "[run_dnn.sh]     max_iters: "${max_iters}
echo "[run_dnn.sh]     min_iters: "${min_iters}
echo "[run_dnn.sh] start_half_lr: "${start_half_lr}
echo "[run_dnn.sh]      momentum: "${momentum}
echo "[run_dnn.sh]     dnn_model: "${dnn_model}
echo "[run_dnn.sh]      data_fbk: "${data_fbk}
echo "[run_dnn.sh]     train_set: "${train_set}
echo "[run_dnn.sh]       dev_set: "${dev_set}
echo "[run_dnn.sh]      test_set: "${test_set}
echo "[run_dnn.sh]       data_en: "${data_en}
echo "[run_dnn.sh]          acwt: "${acwt}

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
if [ ${feats_type}=="fbank" ]; then
    gen_sctipt="make_fbank.sh"
else
    gen_sctipt="make_mfcc_pitch.sh"
fi
echo "[run_dnn.sh] gen_sctipt: "${gen_sctipt}

if [ ${feats_gen} -ne 0 ]; then
    echo "[run_dnn.sh] Re-generate features data ..."

    rm -rf ${data_fbk} && mkdir -p ${data_fbk} || exit 1;

    if [ ${data_en} -ne 0 ]; then
        # 添加音速扰动
        # DFSMN的输出目录是：data/fbank/train_sp/ ...
        echo "[run_dnn.sh] need train data enhance ..."
        echo "[run_dnn.sh] ============================================ "
        echo "$0: preparing directory for speed-perturbed data"
        utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true data/${train_set} ${data_fbk}/${train_set}_sp || exit 1;
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${train_set}_sp;
        new_train_set=${train_set}_sp
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}

        # 加音量扰动
        echo "[run_dnn.sh] ============================================ "
#        for datadir in ${train_set}_sp ${test_sets}; do
#            utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
#        done
#
#        # do volume-perturbation on the training data prior to extracting hires
#        # features; this helps make trained nnets more invariant to test data volume.
#        utils/data/perturb_data_dir_volume.sh data/${train_set}_sp_hires || exit 1;
#
#        for datadir in ${train_set}_sp ${test_sets}; do
#            steps/make_mfcc_pitch.sh --nj 10 --mfcc-config conf/mfcc_hires.conf \
#              --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
#            steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
#            utils/fix_data_dir.sh data/${datadir}_hires || exit 1;
#            # create MFCC data dir without pitch to extract iVector
#            # utils/data/limit_feature_dim.sh 0:39 data/${datadir}_hires data/${datadir}_hires_nopitch || exit 1;
#            steps/compute_cmvn_stats.sh data/${datadir}_hires_nopitch exp/make_hires/$datadir $mfccdir || exit 1;
#        done
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
    if [ ${data_en} -ne 0 ]; then
        train_set=${train_set}_sp_hires_nopitch
        dev_set=${dev_set}_hires_nopitch
        test_set=${test_set}_hires_nopitch
        alidir="exp/tri5a_sp_ali"
        echo "[run_dnn.sh] new train set : "${train_set}
        echo "[run_dnn.sh] new test set : "${test_set}
        echo "[run_dnn.sh] new dev set : "${dev_set}
        echo "[run_dnn.sh] new alidir : "${alidir}
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
            ${data_fbk}/${train_set} ${data_fbk}/${dev_set} data/lang ${alidir} ${alidir_cv} ${dir} || exit 1;
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
            ${data_fbk}/${train_set} ${data_fbk}/${dev_set} data/lang ${alidir} ${alidir_cv} ${dir} || exit 1;
            # ${data_fbk}/train_sp_hires_nopitch ${data_fbk}/dev_hires_nopitch data/lang exp/tri5a_sp_ali ${alidir_cv} ${dir} || exit 1;
    fi
fi

echo "[run_dnn.sh] 2 =================================="
if [ ${stage} -le 2 ]; then
    # Decode
    echo "[run_dnn.sh][Decode] "
    for set in ${test_set} ${dev_set} ; do
        steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
            ${gmmdir}/graph ${data_fbk}/${set} ${dir}/decode_${set}_word || exit 1;
    done
 	for x in ${dir}/decode_*; do
 	    echo "[run_dnn.sh][best_wer] dir: "${x}
        grep WER ${x}/wer_* | utils/best_wer.sh
 	done
fi

#echo "[run_dnn.sh] 3 =================================="
## gen ali & lat for smbr
#if [ ${stage} -le 3 ]; then
#    steps/nnet/align.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set} data/lang ${dir} ${dir}_ali
#    steps/nnet/make_denlats.sh --nj ${nj} --cmd "${decode_cmd}" --acwt ${acwt} \
#        ${data_fbk}/${train_set} data/lang ${dir} ${dir}_denlats
#fi
#
#echo "[run_dnn.sh] 4 =================================="
#####do smbr
#if [ ${stage} -le 4 ]; then
#    steps/nnet/train_mpe.sh --cmd "${cuda_cmd}" --num-iters 1 --learn-rate 0.0000002 --acwt ${acwt} --do-smbr true \
#        ${data_fbk}/${train_set} data/lang ${dir} ${dir}_ali ${dir}_denlats ${dir}_smbr
#fi
#
####decode
#echo "[run_dnn.sh] 5 =================================="
#dir=${dir}_smbr
#acwt=0.03
#echo "[run_dnn.sh] 5  dir: "${dir}
#echo "[run_dnn.sh] 5 acwt: "${acwt}
#
#if [ $stage -le 5 ]; then
#    # dataset="test dev"
#    for set in ${test_set} ${dev_set} ; do
#        # steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
#        #     ${gmmdir}/graph_word ${data_fbk}/test ${dir}/decode_test_word || exit 1;
#        steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
#            ${gmmdir}/graph ${data_fbk}/${set} ${dir}/decode_${set}_word || exit 1;
#    done
#    for x in ${dir}/decode_*; do
#        echo "[run_dnn.sh] 5 [best_wer] dir: "${x}
#        grep WER ${x}/wer_* | utils/best_wer.sh
#    done
#fi


# ======================================================================================================================
# echo "[run_dnn.sh] 3 =================================="
# #xEnt training
# if [ $stage -le 1 ]; then
#   outdir=exp/tri4b_dnn
#   #NN training
#   (tail --pid=$$ -F $outdir/log/train_nnet.log 2>/dev/null)& # forward log
#   $cuda_cmd $outdir/log/train_nnet.log \
#     steps/nnet/train.sh --copy_feats false --cmvn-opts "--norm-means=true --norm-vars=false" --hid-layers 4 --hid-dim 1024 \
#     --learn-rate 0.008 data/fbank/train data/fbank/dev data/lang $alidir $alidir_cv $outdir || exit 1;
#   #Decode (reuse HCLG graph in gmmdir)
#   (
#     steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --srcdir $outdir --config conf/decode_dnn.config --acwt 0.1 \
#       $gmmdir/graph_word data/fbank/test $outdir/decode_test_word || exit 1;
#   )&
#   (
#    steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --srcdir $outdir --config conf/decode_dnn.config --acwt 0.1 \
#      $gmmdir/graph_phone data/fbank/test_phone $outdir/decode_test_phone || exit 1;
#   )&
#
# fi

# echo "[run_dnn.sh] 4 =================================="
# #MPE training

# srcdir=exp/tri4b_dnn
# acwt=0.1
#
# if [ $stage -le 2 ]; then
#   # generate lattices and alignments
#   steps/nnet/align.sh --nj $nj --cmd "$train_cmd" \
#     data/fbank/train data/lang $srcdir ${srcdir}_ali || exit 1;
#   steps/nnet/make_denlats.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt $acwt \
#     data/fbank/train data/lang $srcdir ${srcdir}_denlats || exit 1;
# fi
#
# echo "[run_dnn.sh] 5 =================================="
# if [ $stage -le 3 ]; then
#   outdir=exp/tri4b_dnn_mpe
#   #Re-train the DNN by 3 iteration of MPE 训练dnn的序列辨别MEP/sMBR。
#   steps/nnet/train_mpe.sh --cmd "$cuda_cmd" --num-iters 3 --acwt $acwt --do-smbr false \
#     data/fbank/train data/lang $srcdir ${srcdir}_ali ${srcdir}_denlats $outdir || exit 1
#   #Decode (reuse HCLG graph)
#   for ITER in 3 2 1; do
#    (
#     steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --nnet $outdir/${ITER}.nnet --config conf/decode_dnn.config --acwt $acwt \
#       $gmmdir/graph_word data/fbank/test $outdir/decode_test_word_it${ITER} || exit 1;
#    )&
#    (
#    steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --nnet $outdir/${ITER}.nnet --config conf/decode_dnn.config --acwt $acwt \
#      $gmmdir/graph_phone data/fbank/test_phone $outdir/decode_test_phone_it${ITER} || exit 1;
#    )&
#   done
# fi