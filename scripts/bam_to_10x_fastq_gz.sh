#!/bin/bash 

PARSED=$1
RUN=`grep -w "BAM$" $PARSED | cut -f1 | head -$LSB_JOBINDEX | tail -1`
SIF="/nfs/cellgeni/singularity/images/reprocess_10x.sif"
CMD="singularity run --bind /nfs,/lustre $SIF"

## this has to be 10x bamtofastq, ideally the latest version
$CMD bamtofastq --nthreads 16 $RUN.bam $RUN
