#!/usr/bin/env bash

# Copyright 2012-2015 Brno University of Technology (author: Karel Vesely), Daniel Povey
# Apache 2.0

# Begin configuration section.
srcdir=             # non-default location of DNN-dir (decouples model dir from decode dir)

stage=0 # stage=1 skips lattice generation
nj=4
cmd=run.pl

acwt=0.10 # note: only really affects pruning (scoring is on lattices).
beam=13.0
lattice_beam=8.0
min_active=200
max_active=7000 # limit of active tokens
max_mem=50000000 # approx. limit to memory consumption during minimization in bytes

skip_scoring=false
scoring_opts="--min-lmwt 4 --max-lmwt 15"

num_threads=1 # if >1, will use latgen-faster-parallel
parallel_opts=   # Ignored now.
use_gpu="no" # yes|no|optionaly
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

set -euo pipefail


graphdir=$1
data=$2
json_path=$3
model_file=$4
feat_stats_file=$5
logprior_file=$6
dir=$7

[ -z $srcdir ] && srcdir=`dirname $dir`; # Default model directory one level up from decoding directory.
#sdata=$data/split$nj;

mkdir -p $dir/log

#[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs

# Possibly use multi-threaded decoder
thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"


left_context=10
right_context=10
device='cpu'

model=$(dirname $graphdir)/final.mdl

# Run the decoding in the queue,
if [ $stage -le 0 ]; then
  $cmd --num-threads $((num_threads+1)) JOB=1:$nj $dir/log/decode.JOB.log \
    /scratch2/mxy171630/ovr_ASR/overlap_asr/am_forward.py "$json_path" "$model_file" "$feat_stats_file" "$logprior_file" --left-context="$left_context" --right-context="$right_context" --device="$device" \| \
    latgen-faster-mapped$thread_string --min-active=$min_active --max-active=$max_active --max-mem=$max_mem --beam=$beam \
    --lattice-beam=$lattice_beam --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt \
    $model $graphdir/HCLG.fst ark:- "ark:|gzip -c > $dir/lat.JOB.gz" || exit 1;
fi

# Run the scoring
if ! $skip_scoring ; then
  [ ! -x local/score.sh ] && \
    echo "Not scoring because local/score.sh does not exist or not executable." && exit 1;
  local/score.sh $scoring_opts --cmd "$cmd" $data $graphdir $dir || exit 1;
fi

exit 0;
