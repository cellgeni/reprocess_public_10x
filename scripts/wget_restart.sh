#!/bin/bash 

URLS=$1
URL=`head -$LSB_JOBINDEX $URLS | tail -1` 

TAG=`basename $URL`
TAG2=${TAG%%.fastq.gz}
wget --retry-connrefused --read-timeout=20 --timeout=15 --tries=0 --continue $URL &> $TAG2.wget.log
