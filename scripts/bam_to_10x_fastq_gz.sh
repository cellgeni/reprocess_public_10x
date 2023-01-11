#!/bin/bash 

PARSED=$1
RUN=`grep -w "BAM$" $PARSED | cut -f1 | head -$LSB_JOBINDEX | tail -1`

## this has to be 10x bamtofastq, ideally the latest version
bamtofastq --nthreads 16 $RUN.bam $RUN
