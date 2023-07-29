#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters"
fi

MSGVSIZE=$1
DIFFVSIZE=$2
VALIDSIZE=$3
TRAINSIZE=$4

dev=gpu1

THEANO_FLAGS=mode=FAST_RUN,floatX=float32,device=$dev,lib.cnmem=1,on_unused_input=warn ./train.sh $MSGVSIZE $DIFFVSIZE $VALIDSIZE $TRAINSIZE

