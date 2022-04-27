#!/bin/bash 

file=$1

tail -n +2 $file | cut -f 7 |  tr ";" "\n" | while read i; do j=`basename $i`; k=${j%%.fastq.gz}; wget $i -o $k.wget.log; done
