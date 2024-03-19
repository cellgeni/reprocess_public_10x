#!/bin/bash

SERIES=$1 ## GSE123456 
SCRIPT=$2  
FQDIR=$3


GROUP=`bugroup -w | grep "\b${USER}\b" | cut -d" " -f1`
CPUS=16
RAM=128000 
QUE="normal"
WDIR=`pwd`
N=`cat $SERIES.sample.list | wc -l`

#################

bsub -G $GROUP -n$CPUS -q $QUE \
  -R"span[hosts=1] select[mem>$RAM] rusage[mem=$RAM]" -M$RAM \
  -J "starsolo.$SERIES.[1-${N}]" \
  -o %J.%I.bsub.log -e %J.%I.bsub.err \
  $WDIR/$SCRIPT $FQDIR $SERIES
