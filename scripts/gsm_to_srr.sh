#!/bin/bash 

KK=`cut -f1 sample.tsv`

for i in $KK
do
  esearch -db sra -query $i | efetch -format runinfo | grep -v ReleaseDate | perl -ne 'm/(SRR\d+),/; print "$1,"' | sed "s/,$/\n/" | awk -v v=$i '{print v"\t"$0}'
done
