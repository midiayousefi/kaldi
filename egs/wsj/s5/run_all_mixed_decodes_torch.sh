#!/bin/bash


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.
. path.sh




#steps/decode_torch.sh --nj 1 --cmd "$decode_cmd" \
#    exp/tri4b/graph_tgpr \
#    data/test_dev93 \
#    exp/tri4b/decode_nosp_tgpr_torch_dev93 || exit 1;
#

model_file="/scratch2/mxy171630/ovr_ASR/results/model_ckpt/baseline2_LRCont10_BS1024_Ep3600000_Lr0.01_MaxEp100_cvIm0.01_lrP2_esP5_lrD0.5/epoch_model_ckpt/best_epoch32/model.pt"
feat_stats_file="/scratch2/mxy171630/ovr_ASR/results/statistics/feat_stat_mean_var.npy"
logprior_file="/scratch2/mxy171630/ovr_ASR/results/statistics/logpriors.npy"


for sir in 0 5 10 15 20 25; do
    steps/decode_torch.sh --nj 1 --cmd "$decode_cmd" \
        exp/tri4b/graph_tgpr \
        data/mixed_datasets/SIR_${sir} \
        /scratch2/mxy171630/ovr_ASR/results/json_files/test_set_jsons/wsj_SIR_${sir}_dev93.json \
        "$model_file" \
        "$feat_stats_file" \
        "$logprior_file" \
        exp/tri4b/decode_overlapping_speech/decode_nosp_tgpr_torch_dev93_SIR_${sir} || exit 1;
done

