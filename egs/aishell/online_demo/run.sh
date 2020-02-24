#!/bin/bash
# Description :  online decode
# Author :       caiyueliang
# Date :         2020/01/12
# Detail:

# Note: you have to do 'make ext' in ../../../src/ before running this.

# Set the paths to the binaries and scripts needed
KALDI_ROOT=`pwd`/../../..
export PATH=$PWD/../s5/utils/:$KALDI_ROOT/src/onlinebin:$KALDI_ROOT/src/bin:$PATH

data_file="online-data"
data_url="http://sourceforge.net/projects/kaldi/files/online-data.tar.bz2"

# Change this to "tri2a" if you like to test using a ML-trained model
# ac_model_type=tri2b_mmi
# ac_model_type=thchs30_tri1
# ac_model_type=thchs30_tri2b
# ac_model_type=thchs30_tri4b
# ac_model_type=thchs30_tri7b_DFSMN_L

# ac_model_type=aishell_tri1
# ac_model_type=aishell_tri5a
ac_model_type=aishell_chain

# Alignments and decoding results are saved in this directory(simulated decoding only)
decode_dir="./work"

# Change this to "live" either here or using command line switch like:
# --test-mode live
test_mode="simulated"

# max_active=7000
# beam=15.0
max_active=5000
beam=12.0

. parse_options.sh

ac_model=${data_file}/models/${ac_model_type}

# trans_matrix=""
trans_matrix=${ac_model}/final.mat
# trans_matrix=${ac_model}/lda.mat

final_model=${ac_model}/final.mdl
# final_model=${ac_model}/final.alimdl

#audio=${data_file}/audio/thchs30
#audio=${data_file}/audio/aishell
#audio=${data_file}/audio/qddata
audio=${data_file}/audio/qddata_16khz

echo "[online_demo] 1 ============================================"
echo "[online_demo]    [ac_model] : "${ac_model}
echo "[online_demo][trans_matrix] : "${trans_matrix}
echo "[online_demo] [final_model] : "${final_model}
echo "[online_demo]       [audio] : "${audio}

#if [ ! -s ${data_file}.tar.bz2 ]; then
#    echo "Downloading test models and data ..."
#    wget -T 10 -t 3 $data_url;
#
#    if [ ! -s ${data_file}.tar.bz2 ]; then
#        echo "Download of $data_file has failed!"
#        exit 1
#    fi
#fi

if [ ! -d $ac_model ]; then
    echo "Extracting the models and data ..."
    tar xf ${data_file}.tar.bz2
fi

if [ -s $ac_model/matrix ]; then
    trans_matrix=$ac_model/matrix
fi

echo "[online_demo] 2 ============================================"
case $test_mode in
    live)
        echo
        echo -e "  LIVE DEMO MODE - you can use a microphone and say something\n"
        echo "  The (bigram) language model used to build the decoding graph was"
        echo "  estimated on an audio book's text. The text in question is"
        echo "  \"King Solomon's Mines\" (http://www.gutenberg.org/ebooks/2166)."
        echo "  You may want to read some sentences from this book first ..."
        echo

        # ==============================================================================
        #online-gmm-decode-faster --rt-min=0.5 --rt-max=0.7 --max-active=4000 \
        #    --beam=12.0 --acoustic-scale=0.0769 $ac_model/model $ac_model/HCLG.fst \
        #    $ac_model/words.txt '1:2:3:4:5' ${trans_matrix};;

        # ==============================================================================
        online-gmm-decode-faster --rt-min=0.5 --rt-max=0.7 --max-active=4000 \
            --beam=12.0 --acoustic-scale=0.0769 $ac_model/model $ac_model/HCLG.fst \
            $ac_model/words.txt '1:2:3:4:5' ${trans_matrix};;

    simulated)
        echo
        echo -e "  SIMULATED ONLINE DECODING - pre-recorded audio is used\n"
        echo "  The (bigram) language model used to build the decoding graph was"
        echo "  estimated on an audio book's text. The text in question is"
        echo "  \"King Solomon's Mines\" (http://www.gutenberg.org/ebooks/2166)."
        echo "  The audio chunks to be decoded were taken from the audio book read"
        echo "  by John Nicholson(http://librivox.org/king-solomons-mines-by-haggard/)"
        echo
        echo "  NOTE: Using utterances from the book, on which the LM was estimated"
        echo "        is considered to be \"cheating\" and we are doing this only for"
        echo "        the purposes of the demo."
        echo
        echo "  You can type \"./run.sh --test-mode live\" to try it using your"
        echo "  own voice!"
        echo
        mkdir -p $decode_dir
        # make an input .scp file
        > $decode_dir/input.scp
        for f in $audio/*.wav; do
            bf=`basename $f`
            bf=${bf%.wav}
            echo $bf $f >> $decode_dir/input.scp
        done

        # ==============================================================================
        #online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
        #    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
        #    scp:$decode_dir/input.scp $ac_model/model $ac_model/HCLG.fst \
        #    $ac_model/words.txt '1:2:3:4:5' ark,t:$decode_dir/trans.txt \
        #    ark,t:$decode_dir/ali.txt ${trans_matrix};;

        # ==============================================================================
#        # tri1
#        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
#            --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
#            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
#            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
#            ark,t:${decode_dir}/ali.txt ${trans_matrix};;

        # ==============================================================================
        # tri2b
        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
            --max-active=${max_active} --beam=${beam} --acoustic-scale=0.0769 \
            --left-context=3 --right-context=3 \
            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
            ark,t:${decode_dir}/ali.txt ${trans_matrix};;
    *)
    echo "Invalid test mode! Should be either \"live\" or \"simulated\"!";
    exit 1;;
esac

echo "[online_demo] 3 ============================================"
# Estimate the error rate for the simulated decoding
if [ $test_mode == "simulated" ]; then
    # Convert the reference transcripts from symbols to word IDs
    sym2int.pl -f 2- ${ac_model}/words.txt < ${audio}/trans.txt > ${decode_dir}/ref.txt

    #cat $decode_dir/trans.txt |\
    #    sed -e 's/^\(test[0-9]\+\)\([^ ]\+\)\(.*\)/\1 \3/' |\
    #    gawk '{key=$1; $1=""; arr[key]=arr[key] " " $0; } END { for (k in arr) { print k " " arr[k]} }' > $decode_dir/hyp.txt
    cat $decode_dir/trans.txt |\
        sed -e 's/^\([a-zA-Z0-9]\+\)\([^ ]\+\)\(.*\)/\1 \3/' |\
        gawk '{key=$1; $1=""; arr[key]=arr[key] " " $0; } END { for (k in arr) { print k " " arr[k]} }' > $decode_dir/hyp.txt

   # Finally compute WER
   compute-wer --mode=present ark,t:$decode_dir/ref.txt ark,t:$decode_dir/hyp.txt
fi
