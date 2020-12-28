
train=true   # set to false to disable the training-related scripts
             # note: you probably only want to set --train false if you
             # are using at least --stage 1.
decode=true  # set to false to disable the decoding-related scripts.

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.


# This is a shell script, but it's recommended that you run the commands one by
# one by copying and pasting into the shell.

#wsj0=/ais/gobi2/speech/WSJ/csr_?_senn_d?
#wsj1=/ais/gobi2/speech/WSJ/csr_senn_d?

#wsj0=/mnt/matylda2/data/WSJ/WSJ0
#wsj1=/mnt/matylda2/data/WSJ/WSJ1

#wsj0=/data/corpora0/LDC93S6B
#wsj1=/data/corpora0/LDC94S13B

#wsj0=/export/corpora5/LDC/LDC93S6B
#wsj1=/export/corpora5/LDC/LDC94S13B

#wsj0=/scratch2/mxy171630/wsj/WSJ0
#wsj1=/scratch2/mxy171630/wsj/WSJ1


mixed_datasets="/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_0
/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_5
/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_10
/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_15
/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_20
/scratch2/mxy171630/ovr_ASR/kaldi/egs/wsj/s5/data/mixed_datasets/SIR_25"


#for test_dir in $mixed_datasets; do
#    steps/make_mfcc.sh --cmd "$train_cmd" --nj 20 "$test_dir" || exit 1;
#    steps/compute_cmvn_stats.sh "$test_dir" || exit 1;
#done


for test_dir in $mixed_datasets; do
      dataset_name=$(basename $test_dir)
      nspk=$(wc -l <${test_dir}/spk2utt)
      steps/decode_fmllr.sh --nj ${nspk} --cmd "$decode_cmd" \
        exp/tri4b/graph_tgpr $test_dir \
        exp/tri4b/decode_tgpr_${dataset_name} || exit 1;
      steps/lmrescore.sh --cmd "$decode_cmd" \
        data/lang_test_tgpr data/lang_test_tg \
        $test_dir exp/tri4b/decode_{tgpr,tg}_${dataset_name} || exit 1

      steps/decode_fmllr.sh --nj ${nspk} --cmd "$decode_cmd" \
        exp/tri4b/graph_bd_tgpr $test_dir \
        exp/tri4b/decode_bd_tgpr_${dataset_name} || exit 1;
      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_bd_{tgpr,fgconst} \
        $test_dir exp/tri4b/decode_bd_tgpr_${dataset_name}{,_fg} || exit 1;
done
