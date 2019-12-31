#!/bin/bash

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
    # echo /home/rd/caiyueliang/data/THCHS-30/data_thchs30/data/D8_999.wav.trn | cut -d '/' -f 9- | cut -d '.' -f -1
    file_id=`echo -n ${file} | cut -d '/' -f 9- | cut -d '.' -f -1`
    echo -ne ${file_id}'\t' >> ${temp_trans_file}
    cat ${file} | sed -n '1p' >> ${temp_trans_file}
done

cat ${src_trans_file} ${temp_trans_file} | sort -u > ${tar_trans_file} || exit 1;
#cp -r ${tar_dir}/data_aishell/transcript/aishell_transcript_v0.8.txt ${tar_trans_dir}/aishell_temp.txt || exit 1;
#cat ${temp_trans_file} >> ${tar_trans_dir}/aishell_temp.txt
#cat ${tar_trans_dir}/aishell_temp.txt | sort -u > ${tar_trans_file}
#rm -r ${tar_trans_dir}/aishell_temp.txt

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

cat ${src_lexicon} ${tar_lexicon} | grep -v -a '<s>' | grep -v -a '</s>' | sort -u > ${out_lexicon} || exit 1;
#cp -r ${src_lexicon} ${out_resource_dir}/lexicon_temp.txt || exit 1;
#cat ${tar_lexicon} >> ${out_resource_dir}/lexicon_temp.txt || exit 1;
#cat ${out_resource_dir}/lexicon_temp.txt | sort -u > ${out_lexicon}
#rm -r ${out_resource_dir}/lexicon_temp.txt

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
    mkdir ${tar_wav_dir}/${dir}/thchs30
    for file in `cat ${src_wav_dir}/${dir}_wav.txt`; do
        cp -r ${file} ${tar_wav_dir}/${dir}/thchs30 || exit 1;
    done
    rm -r ${src_wav_dir}/${dir}_wav.txt
done