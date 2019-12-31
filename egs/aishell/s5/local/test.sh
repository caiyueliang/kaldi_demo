#!/bin/bash

#    prefix=BAC009
#    echo "[name_standard] old name: "${1}
#    # spk_id=`echo C32_500 | cut -d '_' -f -1`
#    spk_id=`echo ${1} | cut -d '_' -f -1`
#    char_id=`echo ${spk_id:0:1}`
#    spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
#    spk_id=${char_id}${spk_id}
#    echo "[name_standard] spk_id: "${spk_id}
#    wav_id=`echo ${1} | cut -d '_' -f 2-`
#    wav_id=`echo ${wav_id} | awk '{printf("W%04d\n",$0)}'`
#    echo "[name_standard] wav_id: "${wav_id}
#    echo "[name_standard] new name: "${prefix}${spk_id}${wav_id}

    echo "[name_standard] old name: "${1}
    spk_id=`echo ${1} | cut -d '_' -f -1`
    char_id=`echo ${spk_id:0:1}`
    spk_id=`echo ${spk_id:1} | awk '{printf("%04d\n",$0)}'`
    spk_id=${char_id}${spk_id}
    echo "[name_standard] spk_id: "${spk_id}