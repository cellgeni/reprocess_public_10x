#!/bin/bash

SERIES=$1 ## GSE123456 - need this for properly formatted job names only
SCRIPT=$2  
URLS=$3

GROUP=`id -gn`
CPUS=1
RAM=100 
QUE="transfer"
N=`cat $URLS | wc -l`
WDIR=`pwd`

#################

bsub -G $GROUP -n$CPUS -q $QUE \
  -R"span[hosts=1] select[mem>$RAM] rusage[mem=$RAM]" -M$RAM \
  -J "transfer.$SERIES.[1-${N}]" \
  -o %J.%I.bsub.log -e %J.%I.bsub.err \
  $WDIR/$SCRIPT $URLS
