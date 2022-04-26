#!/bin/bash 

file=$1

cat $file | while read i; do j=`basename $i`; k=${j%%.fastq.gz}; wget $i -o $k.wget.log; done
