#!/bin/bash 

file=$1

tail -n +2 $file | cut -f 4 | while read i; do wget https://sra-pub-run-odp.s3.amazonaws.com/sra/$i/$i -o $i.wget.log; done
