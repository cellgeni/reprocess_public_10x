#!/bin/bash 

file=$1

tail -n +2 $file | cut -f 9 | while read i; do j=`basename $i`; wget $i -o $j.wget.log; done
