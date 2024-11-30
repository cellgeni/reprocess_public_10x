#!/bin/bash

SERIES=$1 ## GSE123456 
SCRIPT=$2  

GROUP=`id -gn`
CPUS=16
RAM=4000 
QUE="normal"
WDIR=`pwd`
N=`grep -w "BAM$" $SERIES.parsed.tsv | wc -l`

#################

bsub -G $GROUP -n$CPUS -q $QUE \
  -R"span[hosts=1] select[mem>$RAM] rusage[mem=$RAM]" -M$RAM \
  -J "bam2fastq.$SERIES.[1-${N}]" \
  -o %J.%I.bsub.log -e %J.%I.bsub.err \
  $WDIR/$SCRIPT $SERIES.parsed.tsv
