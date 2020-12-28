#!/bin/bash


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.
. path.sh

steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train_si284 data/lang exp/tri4b exp/tri4b_ali_si284 || exit 1;
