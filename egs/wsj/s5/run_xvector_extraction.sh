#!/bin/bash


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.
. path.sh


stage=3


# copy original data dirs for new feature extractions

if [ $stage -le 1 ]; then
     mkdir -p ./data/data_for_xvector/train_si284
     mkdir -p ./data/data_for_xvector/test_dev93
     
     cp data/train_si284/{wav.scp,utt2spk,spk2utt,text} ./data/data_for_xvector/train_si284/
     cp data/test_dev93/{wav.scp,utt2spk,spk2utt,text} ./data/data_for_xvector/test_dev93/
     
     # extract MFCC features for x-vector
     for dataset_name in test_dev93 train_si284; do
         steps/make_mfcc.sh --cmd "run.pl" --nj 1 --mfcc-config conf/mfcc_for_xvector.conf \
             ./data/data_for_xvector/$dataset_name || exit 1;
     
         steps/compute_cmvn_stats.sh \
             ./data/data_for_xvector/$dataset_name || exit 1;
     done
fi

#  apply sliding CMVN and write new feature directories
if [ $stage -le 2 ]; then
    for dataset_name in test_dev93 train_si284; do
        ../../callhome_diarization/v2/local_old/nnet3/xvector/prepare_feats.sh --nj 1 --cmd  "run.pl" \
        ./data/data_for_xvector/$dataset_name \
        ./data/data_for_xvector/${dataset_name}_normalized \
        ./data/data_for_xvector/${dataset_name}_normalized
    done
fi



# extract xvectors for each utterance
nnet_dir="/scratch2/mxy171630/ovr_ASR/kaldi/egs/callhome_diarization/v2/exp/xvector_nnet_1a" #downloaded

if [ $stage -le 3 ]; then
    for dataset_name in test_dev93 train_si284; do
        ./steps/make_xvectors.sh --nj 1 --cmd  "run.pl" \
            --window 1.5 \
            --period 0.75 \
            --min-segment 0.5 \
            --apply-cmn false \
            "$nnet_dir" \
            ./data/data_for_xvector/${dataset_name}_normalized \
            ./exp/extracted_xvectors/${dataset_name}
    done
fi
