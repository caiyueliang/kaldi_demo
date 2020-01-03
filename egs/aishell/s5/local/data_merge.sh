#!/bin/bash
# AISHELL 音频ID格式为: BAC009S0724W0345 = BAC009 S0724 W0345
# THCHS-30音频ID格式为: C4_715
# 两者要保持一致：C4_715 --> BAC009C0004W0715 = BAC009 C0004 W0715
prefix=BAC009

# 格式化音频ID: C4_715 --> BAC009C0004W0715 = BAC009 C0004 W0715
function name_standard {
    prefix=BAC009
    spk_id=`echo ${1} | cut -d '_' -f -1`
    char_id=`echo ${spk_id:0:1}`
    spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
    spk_id=${char_id}${spk_id}
    wav_id=`echo ${1} | cut -d '_' -f 2-`
    wav_id=`echo ${wav_id} | awk '{printf("W%04d\n",$0)}'`
    return ${prefix}${spk_id}${wav_id}
}

# 格式化说话人ID：C4 --> C0004
function get_spk_name_standard {
    spk_id=`echo ${1} | cut -d '_' -f -1`
    char_id=`echo ${spk_id:0:1}`
    spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
    spk_id=${char_id}${spk_id}
    return ${spk_id}
}

echo "[DATA_MERGE] 0 =================================="
src_dir=/home/rd/caiyueliang/data/THCHS-30
tar_dir=/home/rd/caiyueliang/data/AISHELL
echo "[DATA_MERGE] src_dir: "${src_dir}
echo "[DATA_MERGE] tar_dir: "${tar_dir}

echo "[DATA_MERGE] 1 =================================="
# 生成 THCHS-30 的 音频ID和对应的文本标签 的数据
src_trans_dir=${src_dir}/data_thchs30/data
tar_trans_dir=${tar_dir}/data_aishell/transcript_merge
src_trans_file=${tar_dir}/data_aishell/transcript/aishell_transcript_v0.8.txt
temp_trans_file=${tar_trans_dir}/thchs30_transcript_v1.0.txt
tar_trans_file=${tar_trans_dir}/aishell_transcript_v0.8.txt
echo "[DATA_MERGE]   src_trans_dir: "${src_trans_dir}
echo "[DATA_MERGE]   tar_trans_dir: "${tar_trans_dir}
echo "[DATA_MERGE]  src_trans_file: "${src_trans_file}
echo "[DATA_MERGE] temp_trans_file: "${temp_trans_file}
echo "[DATA_MERGE]  tar_trans_file: "${tar_trans_file}

rm -rf ${tar_trans_dir}
mkdir ${tar_trans_dir}

# find "/home/rd/caiyueliang/data/THCHS-30/data_thchs30/data" -name "*.wav.trn" | sort -u
find ${src_trans_dir} -name "*.wav.trn" | sort -u > ${tar_trans_dir}/src_wav.txt
for file in `cat ${tar_trans_dir}/src_wav.txt`; do
    # file_id=`echo /home/rd/caiyueliang/data/THCHS-30/data_thchs30/data/D8_999.wav.trn | cut -d '/' -f 9- | cut -d '.' -f -1`
    # file_id=`echo -n ${file} | cut -d '/' -f 9- | cut -d '.' -f -1`
    file_id=`echo -n ${file##*/} | cut -d '.' -f -1`

    # thchs30音频ID格式转换，要格式化，与aishell一致，否则后面正确性检验过不了
    # =============================================================
    # new_file_id=$(name_standard ${file_id})
    spk_id=`echo ${file_id} | cut -d '_' -f -1`
    char_id=`echo ${spk_id:0:1}`
    spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
    spk_id=${char_id}${spk_id}
    # echo "[name_standard] spk_id: "${spk_id}
    wav_id=`echo ${file_id} | cut -d '_' -f 2-`
    wav_id=`echo ${wav_id} | awk '{printf("W%04d\n",$0)}'`
    # echo "[name_standard] wav_id: "${wav_id}
    # echo "[name_standard] new name: "${prefix}${spk_id}${wav_id}
    new_file_id=${prefix}${spk_id}${wav_id}
    # echo ${new_file_id}

    echo -ne ${new_file_id}'\t' >> ${temp_trans_file}
    cat ${file} | sed -n '1p' >> ${temp_trans_file}
done

cat ${src_trans_file} ${temp_trans_file} | sort -u > ${tar_trans_file} || exit 1;

echo "[DATA_MERGE] 2 =================================="
# 生成 lexicon.txt
# /home/rd/caiyueliang/data/THCHS-30/data_thchs30/lm_word/lexicon.txt
# /home/rd/caiyueliang/data/AISHELL/resource_aishell/lexicon.txt
out_resource_dir=${tar_dir}/resource_aishell_merge
out_lexicon=${out_resource_dir}/lexicon.txt
src_lexicon=${src_dir}/data_thchs30/lm_word/lexicon.txt
tar_lexicon=${tar_dir}/resource_aishell/lexicon.txt
echo "[DATA_MERGE] out_resource_dir: "${out_resource_dir}
echo "[DATA_MERGE]      out_lexicon: "${out_lexicon}
echo "[DATA_MERGE]      src_lexicon: "${src_lexicon}
echo "[DATA_MERGE]      tar_lexicon: "${tar_lexicon}

rm -rf ${out_resource_dir}
mkdir ${out_resource_dir}

# 对字典去重并排序
# cat ${tar_lexicon} ${src_lexicon} | grep -v -a '<s>' | grep -v -a '</s>' | sort -u > ${out_lexicon} || exit 1;
# 对字典去重但不排序，且AISHELL的字典放在前面
cat ${tar_lexicon} ${src_lexicon} | grep -v -a '<s>' | grep -v -a '</s>' | awk '!a[$0]++' > ${out_lexicon} || exit 1;

echo "[DATA_MERGE] 3 =================================="
# 拷贝 音频文件
# /home/rd/caiyueliang/data/THCHS-30/data_thchs30 含 dev/ test/ train/
# /home/rd/caiyueliang/data/AISHELL/data_aishell/wav 含 dev/ test/ train/
src_wav_dir=${src_dir}/data_thchs30
tar_wav_dir=${tar_dir}/data_aishell/wav
echo "[DATA_MERGE] src_wav_dir: "${src_wav_dir}
echo "[DATA_MERGE] tar_wav_dir: "${tar_wav_dir}

for dir in dev test train; do
    # find /home/rd/caiyueliang/data/THCHS-30/data_thchs30/dev -name "*.wav"
    find ${src_wav_dir}/${dir} -name "*.wav" | sort -u > ${src_wav_dir}/${dir}_wav.txt
    for file in `cat ${src_wav_dir}/${dir}_wav.txt`; do
        # file_id=`echo -n /home/rd/caiyueliang/data/THCHS-30/data_thchs30/dev/A13_41.wav | cut -d '/' -f 9- | cut -d '_' -f -1`
        # file_id=`echo -n ${file} | cut -d '/' -f 9- | cut -d '.' -f -1`
        file_id=`echo -n ${file##*/} | cut -d '.' -f -1`

        # thchs30音频ID格式转换，要格式化，与aishell一致，否则后面正确性检验过不了
        # =============================================================
        # new_file_id=$(name_standard ${file_id})
        spk_id=`echo ${file_id} | cut -d '_' -f -1`
        char_id=`echo ${spk_id:0:1}`
        spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
        spk_id=${char_id}${spk_id}
        # echo "[name_standard] spk_id: "${spk_id}
        wav_id=`echo ${file_id} | cut -d '_' -f 2-`
        wav_id=`echo ${wav_id} | awk '{printf("W%04d\n",$0)}'`
        # echo "[name_standard] wav_id: "${wav_id}
        # echo "[name_standard] new name: "${prefix}${spk_id}${wav_id}
        new_file_id=${prefix}${spk_id}${wav_id}

        # =============================================================
        #dir_name=$(get_spk_name_standard ${file_id})
        dir_name=${spk_id}

        if [ ! -d ${tar_wav_dir}/${dir}/${dir_name} ]; then
            echo "[DATA_MERGE] mkdir: "${tar_wav_dir}/${dir}/${dir_name}
            mkdir ${tar_wav_dir}/${dir}/${dir_name}
        fi
        cp -r ${file} ${tar_wav_dir}/${dir}/${dir_name}/${new_file_id}".wav" || exit 1;
    done
    rm -r ${src_wav_dir}/${dir}_wav.txt
done
