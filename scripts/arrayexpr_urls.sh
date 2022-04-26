#!/bin/bash 

file=$1

tail -n +2 $file | tr '\t' '\n' | grep ftp | grep fastq.gz | egrep "_R1_|_R2_"
