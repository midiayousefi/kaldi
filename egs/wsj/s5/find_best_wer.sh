#!/bin/bash

decode_dir=$1
cat "$decode_dir"/wer_* | fgrep "WER" | awk 'BEGIN{best_wer=1000}{if($2<best_wer) best_wer=$2}END{print best_wer}'
