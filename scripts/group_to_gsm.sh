#!/bin/bash 

## run this inside the fastq folder I guess

if [[ ! -e ../gsm_to_srr.tsv ]]
then
  echo "ERROR: make sure you run this in the /fastqs directory, and gsm_to_srr.tsv file is present in the root dir!"
  exit 1
fi

GSM=`cut -f1 ../gsm_to_srr.tsv`

for i in $GSM
do
  echo "Moving the files for sample $i:" 
  mkdir $i 
  SRRS=`grep $i ../gsm_to_srr.tsv | awk '{print $2}' | tr ',' '\n'`
  for j in $SRRS
  do
    echo "==> SRR $j belongs to sample $i, moving to directory $i.." 
    mv ${j}* $i
  done 
done 

echo "ALL DONE!" 
