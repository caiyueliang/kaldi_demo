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

speed_perturb=1                         # 音速扰动标志位
volume_perturb=1                        # 音量扰动标志位
reverberate_data=1                      # 混响数据标志位
augment_data=1                          # 加性噪声标志位

num_data_reps=1                         # 混响参数：数据复制的次数，默认为1
sample_frequency=16000                  # 混响参数：

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
echo "[run_dnn.sh]   reverberate: "${reverberate_data}
echo "[run_dnn.sh] num_data_reps: "${num_data_reps}
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
if [ "${feats_type}" == "fbank" ]; then
    # gen_sctipt="make_fbank.sh"
    gen_sctipt="make_fbank_pitch.sh"
else
    gen_sctipt="make_mfcc_pitch.sh"
fi
echo "[run_dnn.sh] gen_sctipt: "${gen_sctipt}

if [ "${feats_gen}" -ne "0" ]; then
    echo "[run_dnn.sh] Re-generate features data ..."

    # 添加音速扰动
    if [ "${speed_perturb}" -ne "0" ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: creating speed-perturbed data ..."
        echo "[run_dnn.sh] ============================================ "
        utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true data/${train_set} ${data_fbk}/${train_set}_sp || exit 1
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${train_set}_sp || exit 1
        new_train_set=${train_set}_sp
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "

        # # 数据对齐应该是在最后做吧
        # # 数据对齐: ${gmmdir}，输出目录${alidir}是：s5/exp/tri5a_sp_ali ...
        # alidir=${gmmdir}_sp_ali
        # echo "$0: aligning with the perturbed low-resolution data"
        # steps/align_fmllr.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set} ${lang} ${gmmdir} ${alidir} || exit 1
        # echo "[run_dnn.sh] ============================================ "
        # echo "[run_dnn.sh] new alidir set : "${alidir}
        # echo "[run_dnn.sh] ============================================ "
    fi

    # 添加音量扰动
    if [ "${volume_perturb}" -ne "0" ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp_hires ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp_hires ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: creating volume-perturbed data ..."
        echo "[run_dnn.sh] ============================================ "
        utils/copy_data_dir.sh ${data_fbk}/${train_set} ${data_fbk}/${train_set}_hires || exit 1
        utils/data/perturb_data_dir_volume.sh ${data_fbk}/${train_set}_hires || exit 1
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${train_set}_hires || exit 1

        new_train_set=${train_set}_hires
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi

    # 添加混响
    if [ "${reverberate_data}" -ne "0" ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: creating reverberated data ..."
        echo "[run_dnn.sh] ============================================ "
        # 输入目录应该时加了音速扰动后的输出目录，如s5/data/{fbank|mfcc}/train_sp
        # datadir=data/ihm/train_cleaned_sp
        if [ ! -d "RIRS_NOISES" ]; then
            # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
            wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
            unzip rirs_noises.zip
        fi

        src_dir=train_sp
        rvb_opts=()
        rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
        rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")
        rvb_opts+=(--noise-set-parameters RIRS_NOISES/pointsource_noises/noise_list)

        # 输入目录是s5/data/ihm/train_cleaned_sp(上面的音量扰动后的输出)，输出目录是s5/data/ihm/train_cleaned_sp_rvb1
        python steps/data/reverberate_data_dir.py \
          "${rvb_opts[@]}" \
          --prefix "rev" \
          --foreground-snrs "20:10:15:5:0" \
          --background-snrs "20:10:15:5:0" \
          --speech-rvb-probability 1 \
          --pointsource-noise-addition-probability 1 \
          --isotropic-noise-addition-probability 1 \
          --num-replications ${num_data_reps} \
          --max-noises-per-minute 1 \
          --source-sampling-rate ${sample_frequency} \
          ${data_fbk}/${src_dir} ${data_fbk}/${src_dir}_rvb${num_data_reps} || exit 1

        utils/copy_data_dir.sh ${data_fbk}/${src_dir}_rvb${num_data_reps} \
            ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires || exit 1
        # 在完混响后，再加音量扰动，输入|输出目录是s5/data/ihm/train_cleaned_sp_rvb1_hires || exit 1
        utils/data/perturb_data_dir_volume.sh ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires || exit 1

        # steps/${gen_sctipt} --nj ${nj} --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" \
        #   ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires \
            exp/make_${feats_type}_log/${src_dir}_rvb${num_data_reps}_hires ${feats_type}/${src_dir}_rvb${num_data_reps}_hires || exit 1
        # steps/compute_cmvn_stats.sh ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires
        steps/compute_cmvn_stats.sh ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires \
            exp/make_${feats_type}_log/${src_dir}_rvb${num_data_reps}_hires ${feats_type}/${src_dir}_rvb${num_data_reps}_hires || exit 1
        utils/fix_data_dir.sh ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires || exit 1

        # combine_short_segments.sh 先不做
        # # 输出目录是s5/data/ihm/train_cleaned_sp_rvb1_hires_comb
        # utils/data/combine_short_segments.sh \
        #     ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires $min_seg_len ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires_comb
        #
        # # just copy over the CMVN to avoid having to recompute it.只需复制CMVN以避免重新计算它。
        # cp ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires/cmvn.scp ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires_comb/
        # utils/fix_data_dir.sh ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires_comb/

        # 合并数据，第一个目录是目标目录，后面可跟多个源目录。
        # 输出目录是：s5/data/ihm/train_cleaned_sp_rvb_hires，输入是s5/data/ihm/train_cleaned_sp_hires和s5/data/ihm/train_cleaned_sp_rvb1_hires
        utils/combine_data.sh ${data_fbk}/${train_set}_rvb ${data_fbk}/${train_set} ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires || exit 1

        new_train_set=${train_set}_rvb
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi

    # 添加加性噪声标
    if [ "${augment_data}" -ne "0" ]; then
        # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
        # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
        echo "[run_dnn.sh] ============================================ "
        echo "$0: creating augment data ..."
        echo "[run_dnn.sh] ============================================ "
        # 输入目录应该时加了音速扰动后的输出目录，如s5/data/{fbank|mfcc}/train_sp
        src_dir=train_sp

        # 准备MUSAN语料库，包括适合增强的音乐、语音和噪声。
        local/make_musan.sh /export/corpora/JHU/musan data || exit 1
        # 获取MUSAN录制的持续时间。这将由脚本augment_data_dir.py使用。
        for name in speech noise music; do
            utils/data/get_utt2dur.sh data/musan_${name} || exit 1
            mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur || exit 1
        done

        python steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" \
            --fg-noise-dir "data/musan_noise" ${data_fbk}/${src_dir} ${data_fbk}/train_noise || exit 1
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/train_noise \
            exp/make_${feats_type}_log/train_noise ${feats_type}/train_noise || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/train_noise exp/make_${feats_type}_log/train_noise \
            ${feats_type}/train_noise || exit 1
        utils/fix_data_dir.sh ${feats_type}/train_noise || exit 1

        # python steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" \
        #   --bg-noise-dir "data/musan_music" ${data_fbk}/${src_dir} ${data_fbk}/train_music || exit 1

        python steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7"\
            --bg-noise-dir "data/musan_speech" ${data_fbk}/${src_dir} ${data_fbk}/train_babble || exit 1
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/train_babble \
            exp/make_${feats_type}_log/train_babble ${feats_type}/train_babble || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/train_babble exp/make_${feats_type}_log/train_babble \
            ${feats_type}/train_babble || exit 1
        utils/fix_data_dir.sh ${feats_type}/train_babble || exit 1

        # 合并添加了加性噪声的多个数据集。输出目录是data/{fbank|mfcc}/train_aug，剩下的都是源目录（包括混响的目录）
        utils/combine_data.sh ${data_fbk}/train_aug ${data_fbk}/train_noise ${data_fbk}/train_babble \
            ${data_fbk}/${src_dir}_rvb${num_data_reps}_hires || exit 1

        # 这里会随机获取扩充数据集的子集，所以是只用了部分的数据来生成mfcc，随机生成的数据和原始数据大概1:1的比例。
        start_time=`date +"%Y-%m-%d %H:%M:%S"`
        echo "[run_dnn.sh] start time: "${start_time}
        utils/subset_data_dir.sh ${data_fbk}/train_aug 100000 ${data_fbk}/train_aug_sub || exit 1
        utils/fix_data_dir.sh ${data_fbk}/train_aug_sub || exit 1
        start_time=`date +"%Y-%m-%d %H:%M:%S"`
        echo "[run_dnn.sh] end time: "${start_time}

        # # 生成mfcc特征，改成在上面生成
        # # steps/make_mfcc.sh  --nj 40 --cmd "$train_cmd" data/train_aug_sub exp/make_mfcc $mfccdir
        # steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/train_aug_sub \
        #     exp/make_${feats_type}_log/train_aug_sub ${feats_type}/train_aug_sub || exit 1
        # steps/compute_cmvn_stats.sh ${data_fbk}/train_aug_sub exp/make_${feats_type}_log/train_aug_sub \
        #     ${feats_type}/train_aug_sub || exit 1
        # utils/fix_data_dir.sh ${feats_type}/train_aug_sub || exit 1

        # 合并音量扰动后的数据和加了噪声后的数据子集（包括混响）。最终生成的数据名称是${data_fbk}/train_aug_combined
        utils/combine_data.sh ${data_fbk}/train_aug_combined ${data_fbk}/train_aug_sub ${data_fbk}/${train_set} || exit 1

        train_set=train_aug_combined
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi

    # ==========================================================================================================
    # 数据对齐: ${gmmdir}，输出目录${alidir}是：s5/exp/tri5a_sp_ali ...
    alidir=${gmmdir}_sp_ali
    echo "[run_dnn.sh] ============================================ "
    echo "$0: aligning data ..."
    echo "[run_dnn.sh] ============================================ "
    steps/align_fmllr.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set} ${lang} ${gmmdir} ${alidir} || exit 1
    echo "[run_dnn.sh] ============================================ "
    echo "[run_dnn.sh] new alidir set : "${alidir}
    echo "[run_dnn.sh] ============================================ "

    # ==========================================================================================================
    # 生成train和dev特征
    echo "[run_dnn.sh] ============================================ "
    echo "$0: creating dev and test data ..."
    echo "[run_dnn.sh] ============================================ "
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
        echo "[run_dnn.sh] creating "${feats_type}" for "${x}
        # steps/make_fbank.sh --cmd "${train_cmd}" --nj ${nj} ${data} ${logdir} ${fbankdir}
        steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
        steps/compute_cmvn_stats.sh ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
    done
else
    # 有加音速扰动
    if [ "${speed_perturb}" -ne "0" ]; then
        new_train_set=${train_set}_sp
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi
    # 有加音量扰动
    if [ "${volume_perturb}" -ne "0" ]; then
        new_train_set=${train_set}_hires
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi
    # 添加混响
    if [ "${reverberate_data}" -ne "0" ]; then
        new_train_set=${train_set}_rvb
        train_set=${new_train_set}
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi
    # 添加加性噪声标
    if [ "${augment_data}" -ne "0" ]; then
        train_set=train_aug_combined
        echo "[run_dnn.sh] ============================================ "
        echo "[run_dnn.sh] new train set : "${data_fbk}/${train_set}
        echo "[run_dnn.sh] ============================================ "
    fi

    # 数据对齐的文档
    alidir=${gmmdir}_sp_ali
    echo "[run_dnn.sh] ============================================ "
    echo "[run_dnn.sh] new alidir set : "${alidir}
    echo "[run_dnn.sh] ============================================ "
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
    steps/nnet/train_mpe.sh --cmd "${cuda_cmd}" --num-iters 2 --learn-rate 0.0000002 --acwt ${acwt} --do-smbr true \
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
