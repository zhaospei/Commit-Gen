#!/bin/bash

# downloaded from https://raw.githubusercontent.com/rsennrich/wmt16-scripts/master/sample/translate.sh

if [ "$#" -ne 5 ]; then
    echo "usage: model testfile testoutput testref bleuoutfile"
    exit 1
fi


MODEL=$1
TEST=$2
OUT=$3
TESTREF=$4
BLEUOUT=$5

echo "models: $MODEL\n"

MODELS=($MODEL)
echo "the first model: ${MODELS[0]}"

for i in "${MODELS[@]}"
do
    if [ ! -e $i.json ]
    then
	echo "json not exists."
	exit 0;
    fi
done

# theano device, in case you do not want to compute on gpu, change it to cpu
# device=gpu
device=gpu1

# path to nematus ( https://www.github.com/rsennrich/nematus )
nematus=$NematusPath

THEANO_FLAGS=mode=FAST_RUN,floatX=float32,device=$device,lib.cnmem=1,on_unused_input=warn python $nematus/nematus/translate.py \
     -m $MODEL \
     -i $TEST \
     -o $OUT \
     -k 12 -n -p 1

# the following is copied from validate.sh

## get BLEU
# path to moses decoder: https://github.com/moses-smt/mosesdecoder

mosesdecoder=/scratch/commitgen/moses/mosesdecoder
ref=$TESTREF

./postprocess-dev.sh < $OUT > $OUT.postprocessed

$mosesdecoder/scripts/generic/multi-bleu.perl $ref < $OUT.postprocessed >> $BLEUOUT
BLEU=`$mosesdecoder/scripts/generic/multi-bleu.perl $ref < $OUT.postprocessed | cut -f 3 -d ' ' | cut -f 1 -d ','`
echo "BLEU = $BLEU"
