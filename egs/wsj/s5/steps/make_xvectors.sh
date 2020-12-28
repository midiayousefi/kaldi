#!/bin/bash


# Begin configuration section.
nj=30
cmd="run.pl"
chunk_size=-1 # The chunk size over which the embedding is extracted.
              # If left unspecified, it uses the max_chunk_size in the nnet
              # directory.
stage=0
window=1.5
period=0.75
pca_dim=
min_segment=0.5
hard_min=false
apply_cmn=true # If true, apply sliding window cepstral mean normalization
use_gpu=false
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;


if [ $# != 3 ]; then
  echo "Usage: $0 <nnet-dir> <data> <xvector-dir>"
  echo " e.g.: $0 exp/xvector_nnet data/train exp/xvectors"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --window <window|1.5>                            # Sliding window length in seconds"
  echo "  --period <period|0.75>                           # Period of sliding windows in seconds"
  echo "  --pca-dim <n|-1>                                 # If provided, the whitening transform also"
  echo "                                                   # performs dimension reduction"
  echo "  --min-segment <min|0.5>                          # Minimum segment length in seconds per xvector"
  echo "  --hard-min <bool|false>                          # Removes segments less than min-segment if true."
  echo "                                                   # Useful for extracting training xvectors."
  echo "  --chunk-size <n|-1>                              # If provided, extracts embeddings with specified"
  echo "                                                   # chunk size, and averages to produce final embedding"
  echo "  --apply-cmn <true,false|true>                    # If true, apply sliding window cepstral mean"
  echo "                                                   # normalization to features"
  echo "  --nj <n|10>                                      # Number of jobs"
  echo "  --stage <stage|0>                                # To control partial reruns"
  exit 1;
fi

srcdir=$1
data=$2
dir=$3



for f in $srcdir/final.raw $srcdir/min_chunk_size $srcdir/max_chunk_size $data/feats.scp ; do
  [ ! -f $f ] && echo "No such file $f" && exit 1;
done

min_chunk_size=`cat $srcdir/min_chunk_size 2>/dev/null`
max_chunk_size=`cat $srcdir/max_chunk_size 2>/dev/null`

nnet=$srcdir/final.raw
if [ -f $srcdir/extract.config ] ; then
  echo "$0: using $srcdir/extract.config to extract xvectors"
  nnet="nnet3-copy --nnet-config=$srcdir/extract.config $srcdir/final.raw - |"
fi

if [ $chunk_size -le 0 ]; then
  chunk_size=$max_chunk_size
fi

if [ $max_chunk_size -lt $chunk_size ]; then
  echo "$0: specified chunk size of $chunk_size is larger than the maximum chunk size, $max_chunk_size" && exit 1;
fi


# Set various variables.
mkdir -p $dir/log
sdata=$data/split$nj;
utils/split_data.sh $data $nj || exit 1;

## Set up features.
if $apply_cmn; then
  feats="ark,s,cs:apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 scp:${sdata}/JOB/feats.scp ark:- |"
else
  feats="scp:${sdata}/JOB/feats.scp"
fi


if [ $stage -le 1 ]; then
  echo "$0: extracting xvectors from nnet"
  if $use_gpu; then
    for g in $(seq $nj); do
      $cmd --gpu 1 ${dir}/log/extract.$g.log \
        nnet3-xvector-compute --use-gpu=yes --min-chunk-size=$min_chunk_size --chunk-size=$chunk_size \
        "$nnet" "`echo $feats | sed s/JOB/$g/g`" ark,scp:${dir}/xvector.$g.ark,${dir}/xvector.$g.scp || exit 1 &
    done
    wait
  else
    $cmd JOB=1:$nj ${dir}/log/extract.JOB.log \
      nnet3-xvector-compute --use-gpu=no --min-chunk-size=$min_chunk_size --chunk-size=$chunk_size \
      "$nnet" "$feats" ark,scp:${dir}/xvector.JOB.ark,${dir}/xvector.JOB.scp || exit 1;
  fi
fi

if [ $stage -le 2 ]; then
  echo "$0: combining xvectors across jobs"
  for j in $(seq $nj); do cat $dir/xvector.$j.scp; done >$dir/xvector.scp || exit 1;
  cp $data/{spk2utt,utt2spk} $dir
fi

if [ $stage -le 3 ]; then
  echo "$0: Computing mean of xvectors"
  $cmd $dir/log/mean.log \
    ivector-mean scp:$dir/xvector.scp $dir/mean.vec || exit 1;
fi
