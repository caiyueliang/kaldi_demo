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

. utils/parse_options.sh || exit 1;

gmmdir=$1
alidir=$2
alidir_cv=$3
echo "[run_dnn.sh]    gmmdir: "${gmmdir}
echo "[run_dnn.sh]    alidir: "${alidir}
echo "[run_dnn.sh] alidir_cv: "${alidir_cv}
echo "[run_dnn.sh] nnet_init: "${nnet_init}

## ======================================================================================================================
echo "[run_dnn.sh] 2 =================================="
#generate fbanks  生成FBank特征，是40维FBank
if [ $stage -le 0 ]; then
  echo "DNN training: stage 0: feature generation"
  # rm -rf data/fbank && mkdir -p data/fbank &&  cp -R data/{train,dev,test,test_phone} data/fbank || exit 1;
  rm -rf data/fbank && mkdir -p data/fbank &&  cp -R data/{train,dev,test} data/fbank || exit 1;
  for x in train dev test; do
    echo "producing fbank for $x"
    #fbank generation
    steps/make_fbank.sh --nj ${nj} --cmd "${train_cmd}" data/fbank/${x} exp/make_fbank/${x} fbank/${x} || exit 1
    #ompute cmvn
    steps/compute_cmvn_stats.sh data/fbank/$x exp/fbank_cmvn/$x fbank/$x || exit 1
  done

  echo "producing test_fbank_phone"
  cp data/fbank/test/feats.scp data/fbank/test_phone && cp data/fbank/test/cmvn.scp data/fbank/test_phone || exit 1;
fi

# ======================================================================================================================
#####CE-training
echo "[FSMN] 4 =================================="
learn_rate=0.00001
max_iters=20
start_half_lr=10
momentum=0.9
# dnn_model=DFSMN_S
dnn_model=DFSMN_L
dir=exp/tri7b_${dnn_model}
# data_fbk=data_fbank
data_fbk=data/fbank
acwt=0.08

echo "[FSMN][CE-training]           dir: "${dir}
echo "[FSMN][CE-training]      cuda_cmd: "${cuda_cmd}
echo "[FSMN][CE-training]    learn_rate: "${learn_rate}
echo "[FSMN][CE-training]     max_iters: "${max_iters}
echo "[FSMN][CE-training] start_half_lr: "${start_half_lr}
echo "[FSMN][CE-training]      momentum: "${momentum}
echo "[FSMN][CE-training]     dnn_model: "${dnn_model}
echo "[FSMN][CE-training]      data_fbk: "${data_fbk}
echo "[FSMN][CE-training]          acwt: "${acwt}

echo "[FSMN] 5 =================================="
if [ ${stage} -le 3 ]; then
     if [ ! -d "${dir}" ]; then
         mkdir ${dir}
         mkdir ${dir}/decode_test_word
         mkdir ${dir}/decode_test_word/log
         mkdir ${dir}/decode_test_phone
         mkdir ${dir}/decode_test_phone/log
     fi

    proto=local/nnet/${dnn_model}.proto
    echo "[FSMN][CE-training]    proto: "${proto}
    ori_num_pdf=`cat $proto |grep "Softmax" |awk '{print $3}'`
    echo "[FSMN][CE-training] ori_num_pdf: "$ori_num_pdf

    # ======================================================================
    # proto使用默认的
    new_proto=${proto}
    echo "[FSMN][CE-training] new proto: "${new_proto}
    # ======================================================================
    # # proto使用自动获取的
    # new_num_pdf=`gmm-info ${gmmdir}/final.mdl |grep "number of pdfs" |awk '{print $4}'`
    # echo "[FSMN][CE-training] new_num_pdf: "$new_num_pdf
    # new_proto=${proto}.${new_num_pdf}
    # sed -r "s/"${ori_num_pdf}"/"${new_num_pdf}"/g" ${proto} > ${new_proto}
    # ======================================================================

    if [ ! -z ${nnet_init} ]; then
        # 执行脚本train_faster.sh，使用预训练模型进行训练
        echo "[FSMN][CE-training] 使用预训练模型进行训练 : "${nnet_init}
        ${cuda_cmd} ${dir}/train_faster_nnet.log \
            steps/nnet/train_faster.sh --nnet-proto ${new_proto} --learn-rate ${learn_rate} \
            --max_iters ${max_iters} --start_half_lr ${start_half_lr} --momentum ${momentum} \
            --train-tool "nnet-train-fsmn-streams" \
            --feat-type plain --splice 1 \
            --cmvn-opts "--norm-means=true --norm-vars=false" --delta_opts "--delta-order=2" \
            --train-tool-opts "--minibatch-size=4096" \
            --nnet_init ${nnet_init} \
            ${data_fbk}/train ${data_fbk}/dev data/lang ${alidir} ${alidir_cv} ${dir} || exit 1;
    else
        echo "[FSMN][CE-training] 不使用预训练模型进行训练 ... "
        # 执行脚本train_faster.sh
        ${cuda_cmd} ${dir}/train_faster_nnet.log \
            steps/nnet/train_faster.sh --nnet-proto ${new_proto} --learn-rate ${learn_rate} \
            --max_iters ${max_iters} --start_half_lr ${start_half_lr} --momentum ${momentum} \
            --train-tool "nnet-train-fsmn-streams" \
            --feat-type plain --splice 1 \
            --cmvn-opts "--norm-means=true --norm-vars=false" --delta_opts "--delta-order=2" \
            --train-tool-opts "--minibatch-size=4096" \
            ${data_fbk}/train ${data_fbk}/dev data/lang ${alidir} ${alidir_cv} ${dir} || exit 1;
    fi

    # # 执行脚本train.sh
    # ${cuda_cmd} ${dir}/train_nnet.log \
    #     steps/nnet/train.sh --copy_feats false --nnet-proto ${new_proto} --learn-rate ${learn_rate} \
    #     --max_iters ${max_iters} --momentum ${momentum} \
    #     --train-tool "nnet-train-fsmn-streams" \
    #     --feat-type plain --splice 1 \
    #     --cmvn-opts "--norm-means=true --norm-vars=false" --delta_opts "--delta-order=2" \
    #     --train-tool-opts "--minibatch-size=4096" \
    #     ${data_fbk}/train ${data_fbk}/dev data/lang ${alidir} ${alidir_cv} ${dir} || exit 1;

    # Decode
    echo "[FSMN][CE-training][Decode] dir: "${dir}"/decode_test_word"
    steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
        ${gmmdir}/graph ${data_fbk}/test ${dir}/decode_test_word || exit 1;

    # echo "[FSMN][CE-training][Decode] dir: "${dir}"/decode_test_phone"
    # steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
    #     ${gmmdir}/graph_phone ${data_fbk}/test_phone ${dir}/decode_test_phone || exit 1;

 	for x in ${dir}/decode_*;
 	do
 	    echo "[FSMN][CE-training][best_wer] dir: "${x}
        grep WER ${x}/wer_* | utils/best_wer.sh
 	done
fi

####Decode
echo "[FSMN] 6 =================================="
#acwt=0.08
#if [ $stage -le 4 ]; then
#	# gmm=exp/tri6b_cleaned
# 	gmm=${gmmdir}
# 	# dataset="test_clean dev_clean test_other dev_other"
# 	dataset="test dev"
#   for set in ${dataset}
#   do
#       # 解码
#       steps/nnet/decode.sh --nj 16 --cmd "$decode_cmd" --acwt ${acwt} \
#	        ${gmm}/graph_tgsmall ${data_fbk}/${set} ${dir}/decode_tgsmall_${set}
#
#       steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
#           $data_fbk/$set $dir/decode_{tgsmall,tgmed}_${set}
#
#		steps/lmrescore_const_arpa.sh \
#         	--cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#           $data_fbk/$set $dir/decode_{tgsmall,tglarge}_${set}
#
# 		steps/lmrescore_const_arpa.sh \
#         	--cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
#         	$data_fbk/$set $dir/decode_{tgsmall,fglarge}_${set}
#   done
# 	for x in $dir/decode_*;
# 	do
#       grep WER $x/wer_* | utils/best_wer.sh
# 	done
#fi

echo "[FSMN] 7 =================================="
# gen ali & lat for smbr
if [ ${stage} -le 5 ]; then
    steps/nnet/align.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/train data/lang ${dir} ${dir}_ali
    steps/nnet/make_denlats.sh --nj ${nj} --cmd "${decode_cmd}" --acwt ${acwt} \
        ${data_fbk}/train data/lang ${dir} ${dir}_denlats
fi

echo "[FSMN] 8 =================================="
####do smbr
if [ ${stage} -le 5 ]; then
    steps/nnet/train_mpe.sh --cmd "${cuda_cmd}" --num-iters 2 --learn-rate 0.0000002 --acwt ${acwt} --do-smbr true \
        ${data_fbk}/train data/lang ${dir} ${dir}_ali ${dir}_denlats ${dir}_smbr
fi

###decode
echo "[FSMN] 9 =================================="
dir=${dir}_smbr
acwt=0.03
echo "[FSMN] 9  dir: "${dir}
echo "[FSMN] 9 acwt: "${acwt}

if [ $stage -le 6 ]; then
    # gmm=exp/tri6b_cleaned
    # dataset="test_clean dev_clean test_other dev_other"
    dataset="test dev"
    for set in ${dataset}
    do
        # steps/nnet/decode.sh --nj $nj --cmd "${decode_cmd}" --srcdir ${dir} --acwt ${acwt} \
        #     ${gmmdir}/graph_word ${data_fbk}/test ${dir}/decode_test_word || exit 1;
        steps/nnet/decode.sh --nj ${nj} --cmd "${decode_cmd}" --acwt ${acwt} \
            ${gmmdir}/graph ${data_fbk}/${set} ${dir}/decode_${set}_word || exit 1;

        # steps/lmrescore.sh --cmd "${decode_cmd}" data/lang_test_{tgsmall,tgmed} \
        #     ${data_fbk}/${set} ${dir}/decode_{tgsmall,tgmed}_${set}

        # steps/lmrescore_const_arpa.sh \
        #     --cmd "${decode_cmd}" data/lang_test_{tgsmall,tglarge} \
        #     ${data_fbk}/${set} ${dir}/decode_{tgsmall,tglarge}_${set}

        # steps/lmrescore_const_arpa.sh \
        #     --cmd "${decode_cmd}" data/lang_test_{tgsmall,fglarge} \
        #     ${data_fbk}/${set} ${dir}/decode_{tgsmall,fglarge}_${set}
    done

    for x in ${dir}/decode_*;
    do
        echo "[FSMN] 9 [best_wer] dir: "${x}
        grep WER ${x}/wer_* | utils/best_wer.sh
    done
fi


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