#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# Note: you have to do 'make ext' in ../../../src/ before running this.

# Set the paths to the binaries and scripts needed
[ -f ./path.sh ] && . ./path.sh; # source the path.

KALDI_ROOT=`pwd`/../../..
export PATH=$PWD/../s5/utils/:${KALDI_ROOT}/src/onlinebin:${KALDI_ROOT}/src/online2bin:${KALDI_ROOT}/src/bin:${KALDI_ROOT}/src/featbin:${KALDI_ROOT}/src/latbin:$PATH

data_file="online-data"
data_url="http://sourceforge.net/projects/kaldi/files/online-data.tar.bz2"

# Change this to "tri2a" if you like to test using a ML-trained model
# ===================================================================
# ac_model_type=thchs30_tri1
# ac_model_type=thchs30_tri2b
# ac_model_type=thchs30_tri4b
# ac_model_type=thchs30_tri7b_DFSMN_L
# ac_model_type=aishell_tri1
# ac_model_type=aishell_tri5a
# ac_model_type=aishell_tri5a_back
# ac_model_type=aishell_chain
ac_model_type=aishell_tri7b_DFSMN_L

# ===================================================================
# decode audio path
#audio=${data_file}/audio/thchs30
#audio=${data_file}/audio/aishell
#audio=${data_file}/audio/qddata
audio=${data_file}/audio/qddata_16khz

# ===================================================================
# Change this to "live" either here or using command line switch like:
# --test-mode live
test_mode="simulated"

# Alignments and decoding results are saved in this directory(simulated decoding only)
decode_dir="./work"

. ./parse_options.sh

ac_model=${data_file}/models/${ac_model_type}

echo "[Online_Decode] 1 ============================================"
echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
echo "[Online_Decode] [ac_model_path] : "${ac_model}
echo "[Online_Decode]    [audio_path] : "${audio}
echo "[Online_Decode]    [decode_dir] : "${decode_dir}
echo "[Online_Decode]     [test_mode] : "${test_mode}

echo "[Online_Decode] 2 ============================================"
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

        echo "[Online_Decode] 3 ============================================"
        case ${ac_model_type} in
            thchs30_tri1)
                trans_matrix=""
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
                    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            thchs30_tri2b)
                trans_matrix=${ac_model}/final.mat
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
                    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
                    --left-context=3 --right-context=3 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            thchs30_tri4b)
                trans_matrix=${ac_model}/final.mat
                final_model=${ac_model}/final.alimdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
                    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
                    --left-context=3 --right-context=3 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            thchs30_tri7b_DFSMN_L)
                trans_matrix=${ac_model}/final.mat
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
                    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
                    --left-context=3 --right-context=3 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            aishell_tri1)
                trans_matrix=""
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
                    --max-active=7000 --beam=15.0 --acoustic-scale=0.0769 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            aishell_tri5a_back)
                trans_matrix=${ac_model}/final.mat
                final_model=${ac_model}/final.alimdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
                    --max-active=7000 --beam=15.0 --acoustic-scale=0.0769 \
                    --left-context=3 --right-context=3 \
                    scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
                    ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
                    ark,t:${decode_dir}/ali.txt ${trans_matrix};;
            aishell_tri5a)
                trans_matrix=""
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online2-wav-nnet3-latgen-faster --do-endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 \
                    --online=true --frame-subsampling-factor=3 --config=${ac_model}/conf/online.conf \
                    --min-active=200 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 \
                    --word-symbol-table=${ac_model}/words.txt ${final_model} ${ac_model}/HCLG.fst ark:${audio}/spk2utt \
                    'ark,s,cs:wav-copy scp,p:'${audio}'/wav.scp ark:- |' 'ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >./work/lat.1.gz';;
            aishell_chain)
                trans_matrix=""
                final_model=${ac_model}/final.mdl
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}
                online2-wav-nnet3-latgen-faster --do-endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 \
                    --online=true --frame-subsampling-factor=3 --config=${ac_model}/conf/online.conf \
                    --min-active=200 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 \
                    --word-symbol-table=${ac_model}/words.txt ${final_model} ${ac_model}/HCLG.fst ark:${audio}/spk2utt \
                    'ark,s,cs:wav-copy scp,p:'${audio}'/wav.scp ark:- |' 'ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >./work/lat.1.gz';;
            aishell_tri7b_DFSMN_L)
                num_threads=1
                trans_matrix=""
                final_model=${ac_model}/final.mdl
                model_dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell_old_0119/s5/exp/tri7b_DFSMN_L"
                graph_dir="/home/rd/caiyueliang/kaldi-trunk/egs/aishell_old_0119/s5/exp/tri5a/graph"
                echo "[Online_Decode] [ac_model_type] : "${ac_model_type}
                echo "[Online_Decode]  [trans_matrix] : "${trans_matrix}
                echo "[Online_Decode]   [final_model] : "${final_model}

                echo "[Online_Decode] 0 ============================================"
                run.pl --num-threads ${num_threads} JOB=1:1 ./work/log/decode.JOB.log \
                    nnet-forward --no-softmax=true --prior-scale=1.0 --feature-transform=${model_dir}/final.feature_transform \
                    --class-frame-counts=${model_dir}/ali_train_pdf.counts --use-gpu="no" "${model_dir}/final.nnet" \
                    'ark,s,cs:copy-feats scp:/home/rd/caiyueliang/kaldi-trunk/egs/aishell/online_demo/tmp_data/fbank/test/feats.scp ark:- | apply-cmvn --norm-means=true --norm-vars=false --utt2spk=ark:/home/rd/caiyueliang/kaldi-trunk/egs/aishell/online_demo/tmp_data/fbank/test/utt2spk scp:/home/rd/caiyueliang/kaldi-trunk/egs/aishell/online_demo/tmp_data/fbank/test/cmvn.scp ark:- ark:- | add-deltas --delta-order=2 ark:- ark:- |' ark:- \| \
                    latgen-faster-mapped --min-active=200 --max-active=7000 --max-mem=50000000 \
                    --beam=13.0 --lattice-beam=8.0 --acoustic-scale=0.08 --allow-partial=true \
                    --word-symbol-table=${graph_dir}/words.txt \
                    ${model_dir}/final.mdl ${graph_dir}/HCLG.fst ark:- "ark:|gzip -c > ./work/lat.gz"; exit 1;;
            *)
                echo "[ERROR] Invalid ac_model_type ..."; exit 1;;
        esac;;
        # ==============================================================================
        # online1:
        #online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
        #    --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
        #    scp:$decode_dir/input.scp $ac_model/model $ac_model/HCLG.fst \
        #    $ac_model/words.txt '1:2:3:4:5' ark,t:$decode_dir/trans.txt \
        #    ark,t:$decode_dir/ali.txt ${trans_matrix};;

        # ==============================================================================
#        # online1: thchs30_tri1, work
#        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
#            --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
#            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
#            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
#            ark,t:${decode_dir}/ali.txt ${trans_matrix};;

        # ==============================================================================
#        # online1: thchs30_tri2b, thchs30_tri4b work
#        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85 \
#            --max-active=4000 --beam=12.0 --acoustic-scale=0.0769 \
#            --left-context=3 --right-context=3 \
#            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
#            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
#            ark,t:${decode_dir}/ali.txt ${trans_matrix};;

        # ==============================================================================
#        # online1: aishell_tri1, not work
#        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
#            --max-active=7000 --beam=15.0 --acoustic-scale=0.0769 \
#            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
#            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
#            ark,t:${decode_dir}/ali.txt ${trans_matrix};;

        # ==============================================================================
#        # online2: aishell_chain, work
#        online2-wav-nnet3-latgen-faster --do-endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 \
#            --online=true --frame-subsampling-factor=3 --config=${ac_model}/conf/online.conf \
#            --min-active=200 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 \
#            --word-symbol-table=${ac_model}/words.txt ${final_model} ${ac_model}/HCLG.fst ark:${audio}/spk2utt \
#            'ark,s,cs:wav-copy scp,p:'${audio}'/wav.scp ark:- |' 'ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >./work/lat.1.gz';;

        # ==============================================================================
#        # online2: aishell_tri5a, not work
#        online2-wav-nnet3-latgen-faster --do-endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 \
#            --online=true --frame-subsampling-factor=3 --config=${ac_model}/conf/online.conf \
#            --min-active=200 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 \
#            --word-symbol-table=/home/rd/caiyueliang/kaldi-trunk/egs/aishell/s5/exp/tri5a/graph/words.txt \
#            /home/rd/caiyueliang/kaldi-trunk/egs/aishell/s5/exp/tri5a/final.mdl \
#            /home/rd/caiyueliang/kaldi-trunk/egs/aishell/s5/exp/tri5a/graph/HCLG.fst ark:${audio}/spk2utt \
#            'ark,s,cs:wav-copy scp,p:'${audio}'/wav.scp ark:- |' 'ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >./work/lat.1.gz';;

#        online2-wav-nnet3-latgen-faster --do-endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 \
#            --online=true --frame-subsampling-factor=3 --config=${ac_model}/conf/online.conf \
#            --min-active=200 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 \
#            --word-symbol-table=${ac_model}/words.txt ${final_model} ${ac_model}/HCLG.fst ark:${audio}/spk2utt \
#            'ark,s,cs:wav-copy scp,p:'${audio}'/wav.scp ark:- |' 'ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >./work/lat.1.gz';;

#        online-wav-gmm-decode-faster --verbose=1 --rt-min=0.8 --rt-max=0.85\
#            --max-active=7000 --beam=15.0 --acoustic-scale=0.0769 \
#            scp:${decode_dir}/input.scp ${final_model} ${ac_model}/HCLG.fst \
#            ${ac_model}/words.txt '1:2:3:4:5' ark,t:${decode_dir}/trans.txt \
#            ark,t:${decode_dir}/ali.txt ${trans_matrix};;
        # ==============================================================================
#        online2-wav-nnet3-latgen-faster $silence_weighting_opts --do-endpointing=$do_endpointing \
#            --frames-per-chunk=$frames_per_chunk \
#            --extra-left-context-initial=$extra_left_context_initial \
#            --online=$online \
#            $frame_subsampling_opt \
#            --config=$online_config \
#            --min-active=$min_active --max-active=$max_active --beam=$beam --lattice-beam=$lattice_beam \
#            --acoustic-scale=$acwt --word-symbol-table=$graphdir/words.txt \
#            $srcdir/${iter}.mdl $graphdir/HCLG.fst $spk2utt_rspecifier "$wav_rspecifier" \
#            "$lat_wspecifier" || exit 1;;

    *)
    echo "Invalid test mode! Should be either \"live\" or \"simulated\"!";
    exit 1;;
esac

echo "[Online_Decode] 4 ============================================"
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
