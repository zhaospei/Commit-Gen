#!/bin/sh

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters"
fi

VALIDSIZE=$1
TRAINSIZE=$2
MSGVSIZE=$3
DIFFVSIZE=$4

# downloaded from https://raw.githubusercontent.com/rsennrich/wmt16-scripts/master/sample/validate.sh

# path to nematus ( https://www.github.com/rsennrich/nematus )
nematus=/scratch/commitgen/nematus

# path to moses decoder: https://github.com/moses-smt/mosesdecoder
mosesdecoder=/scratch/commitgen/moses/mosesdecoder

# theano device, in case you do not want to compute on gpu, change it to cpu
device=gpu0
# device=cpu

#model prefix
prefix=models/model.$TRAINSIZE.$MSGVSIZE.$DIFFVSIZE.npz

#dev=data/newsdev2016.bpe.ro
#ref=data/newsdev2016.tok.en
dev=data/valid.$VALIDSIZE.diff
ref=data/valid.$VALIDSIZE.msg

# decode
THEANO_FLAGS=mode=FAST_RUN,floatX=float32,device=$device,lib.cnmem=1,on_unused_input=warn python $nematus/nematus/translate.py \
     -m $prefix.dev.npz \
     -i $dev \
     -o $dev.output.dev \
     -k 12 -n -p 1

./postprocess-dev.sh < $dev.output.dev > $dev.output.postprocessed.dev


## get BLEU
BEST=`cat ${prefix}_best_bleu || echo 0`
$mosesdecoder/scripts/generic/multi-bleu.perl $ref < $dev.output.postprocessed.dev >> ${prefix}_bleu_scores
BLEU=`$mosesdecoder/scripts/generic/multi-bleu.perl $ref < $dev.output.postprocessed.dev | cut -f 3 -d ' ' | cut -f 1 -d ','`
BETTER=`echo "$BLEU > $BEST" | bc`

echo "BLEU = $BLEU"

# save model with highest BLEU
if [ "$BETTER" = "1" ]; then
  echo "new best; saving"
  echo $BLEU > ${prefix}_best_bleu
  cp ${prefix}.dev.npz ${prefix}.npz.best_bleu
fi
