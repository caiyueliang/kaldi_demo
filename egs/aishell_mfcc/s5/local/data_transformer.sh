#!/bin/bash
# Description :  data transformer
# Author :       caiyueliang
# Date :         2020/02/26
# Detail:

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

# feats_type=fbank
nj=8

feats_type=mfcc
data_fbk=data/${feats_type}

train_set=train
dev_set=dev
test_set=test
lang=data/lang

speed_perturb=1                         # 音速扰动标志位
volume_perturb=1                        # 音量扰动标志位
reverberate_data=0                      # 混响数据标志位
augment_data=0                          # 加性噪声标志位
align_data=0                            # 对齐数据标志位

num_data_reps=1                         # 混响参数：数据复制的次数，默认为1
sample_frequency=16000                  # 混响参数：

. utils/parse_options.sh || exit 1;

echo "[data_transformer] ===================================="
echo "[data_transformer]    feats_type: "${feats_type}
echo "[data_transformer]      data_fbk: "${data_fbk}
echo "[data_transformer]     train_set: "${train_set}
echo "[data_transformer]       dev_set: "${dev_set}
echo "[data_transformer]      test_set: "${test_set}
echo "[data_transformer]          lang: "${lang}
echo "[data_transformer] ===================================="
echo "[data_transformer] speed_perturb: "${speed_perturb}
echo "[data_transformer]volume_perturb: "${volume_perturb}
echo "[data_transformer]   reverberate: "${reverberate_data}
echo "[data_transformer]  augment_data: "${augment_data}
echo "[data_transformer]    align_data: "${align_data}

 gmmdir=$1                             # 对齐才用到
 alidir=$2                             # 对齐才用到
 echo "[data_transformer] ===================================="
 echo "[data_transformer]        gmmdir: "${gmmdir}
 echo "[data_transformer]        alidir: "${alidir}

echo "[data_transformer] 0 =================================="
# 根据使用的特征类型，选择对应的生成脚本
if [ "${feats_type}" == "fbank" ]; then
    gen_sctipt="make_fbank_pitch.sh"
else
    gen_sctipt="make_mfcc_pitch.sh"
fi
echo "[data_transformer] gen_sctipt: "${gen_sctipt}

echo "[data_transformer] 1 =================================="
# 生成train和dev和test的原始特征
echo "$0: creating train、dev、test base data ..."
echo "[data_transformer] ============================================ "
cp -R data/${train_set} ${data_fbk} || exit 1;
cp -R data/${dev_set} ${data_fbk} || exit 1;
cp -R data/${test_set} ${data_fbk} || exit 1;
for x in ${train_set} ${dev_set} ${test_set} ; do
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] creating base "${feats_type}" for "${x}
    steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
    steps/compute_cmvn_stats.sh ${data_fbk}/${x} exp/make_${feats_type}_log/${x} ${feats_type}/${x} || exit 1
done

echo "[data_transformer] 2 =================================="
# 添加音速扰动
if [ "${speed_perturb}" -ne "0" ]; then
    # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
    # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
    echo "$0: creating speed-perturbed data ..."
    echo "[data_transformer] ============================================ "
    utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true data/${train_set} ${data_fbk}/${train_set}_sp || exit 1
    steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
    steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_sp exp/make_${feats_type}_log/${train_set}_sp ${feats_type}/${train_set}_sp || exit 1
    utils/fix_data_dir.sh ${data_fbk}/${train_set}_sp || exit 1
    new_train_set=${train_set}_sp
    train_set=${new_train_set}
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] new train set : "${data_fbk}/${train_set}
    echo "[data_transformer] ============================================ "
fi

echo "[data_transformer] 3 =================================="
# 进行数据对齐的
if [ "${align_data}" -ne "0" ]; then
    # 数据对齐: ${gmmdir}，输出目录${alidir}是：s5/exp/tri5a_sp_ali ...
    # alidir=${gmmdir}_sp_ali
    echo "$0: aligning with the perturbed low-resolution data"
    steps/align_fmllr.sh --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set} ${lang} ${gmmdir} ${alidir} || exit 1
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] output alidir set : "${alidir}
    echo "[data_transformer] ============================================ "
fi

echo "[data_transformer] 4 =================================="
# 添加音量扰动
if [ "${volume_perturb}" -ne "0" ]; then
    # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp_hires ...
    # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp_hires ...
    echo "$0: creating volume-perturbed data ..."
    echo "[data_transformer] ============================================ "
    utils/copy_data_dir.sh ${data_fbk}/${train_set} ${data_fbk}/${train_set}_hires || exit 1
    utils/data/perturb_data_dir_volume.sh ${data_fbk}/${train_set}_hires || exit 1
    steps/${gen_sctipt} --nj ${nj} --cmd "${train_cmd}" ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
    steps/compute_cmvn_stats.sh ${data_fbk}/${train_set}_hires exp/make_${feats_type}_log/${train_set}_hires ${feats_type}/${train_set}_hires || exit 1
    utils/fix_data_dir.sh ${data_fbk}/${train_set}_hires || exit 1

    new_train_set=${train_set}_hires
    train_set=${new_train_set}
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] new train set : "${data_fbk}/${train_set}
    echo "[data_transformer] ============================================ "
fi

echo "[data_transformer] 5 =================================="
# 添加混响
if [ "${reverberate_data}" -ne "0" ]; then
    # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
    # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
    echo "$0: creating reverberated data ..."
    echo "[data_transformer] ============================================ "
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
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] new train set : "${data_fbk}/${train_set}
    echo "[data_transformer] ============================================ "
fi

echo "[data_transformer] 6 =================================="
# 添加加性噪声标
if [ "${augment_data}" -ne "0" ]; then
    # 路径文件的输出目录是：s5/data/{fbank|mfcc}/train_sp ...
    # 特征文件的输出目录是：s5/{fbank|mfcc}/train_sp ...
    echo "$0: creating augment data ..."
    echo "[data_transformer] ============================================ "
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
    echo "[data_transformer] start time: "${start_time}
    utils/subset_data_dir.sh ${data_fbk}/train_aug 100000 ${data_fbk}/train_aug_sub || exit 1
    utils/fix_data_dir.sh ${data_fbk}/train_aug_sub || exit 1
    start_time=`date +"%Y-%m-%d %H:%M:%S"`
    echo "[data_transformer] end time: "${start_time}

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
    echo "[data_transformer] ============================================ "
    echo "[data_transformer] new train set : "${data_fbk}/${train_set}
    echo "[data_transformer] ============================================ "
fi