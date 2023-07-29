#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters"
fi

MSGVSIZE=$1
DIFFVSIZE=$2
VALIDSIZE=$3
TRAINSIZE=$4

echo "dictionaries data/vocab.diff.$DIFFVSIZE.json data/vocab.msg.$MSGVSIZE.json"
echo "model models/model.$TRAINSIZE.$MSGVSIZE.$DIFFVSIZE.npz"
echo "train datasets: data/train.$TRAINSIZE.diff data/train.$TRAINSIZE.msg"
echo "valid datasets: data/valid.$VALIDSIZE.diff data/valid.$VALIDSIZE.msg"

# check https://github.com/rsennrich/wmt16-scripts/tree/master/sample

python ../nematus/nmt.py \
  --model models/model.$TRAINSIZE.$MSGVSIZE.$DIFFVSIZE.npz \
  --dim_word 512 \
  --dim 1024 \
  --n_words_src $DIFFVSIZE \
  --n_words $MSGVSIZE \
  --decay_c 0 \
  --clip_c 1 \
  --lrate 0.0001 \
  --optimizer adadelta \
  --maxlen 400 \
  --batch_size 80 \
  --valid_batch_size 80 \
  --datasets data/train.$TRAINSIZE.diff data/train.$TRAINSIZE.msg \
  --valid_datasets data/valid.$VALIDSIZE.diff data/valid.$VALIDSIZE.msg \
  --dictionaries data/vocab.diff.$DIFFVSIZE.json data/vocab.msg.$MSGVSIZE.json \
  --validFreq 10000 \
  --dispFreq 1000 \
  --saveFreq 30000 \
  --sampleFreq 10000 \
  --dropout_embedding 0.2 \
  --dropout_hidden 0.2 \
  --dropout_source 0.1 \
  --dropout_target 0.1 \
  --no_shuffle \
  --external_validation_script "./validate.sh $VALIDSIZE $TRAINSIZE $MSGVSIZE $DIFFVSIZE"
