#!/bin/bash 

## check that all the runs have exactly 2 archived fastq files associated with them, 
## and re-organise them according to sample_to_run.tsv 

mkdir fastqs

SAMPLES=`cat sample.list`
RUNS=`cat run.list`

## at this point, all the downloaded or converted fastq.gz files should be in /done_wget
cd done_wget

for i in $RUNS
do
  if [[ ! -s ${i}_1.fastq.gz || ! -s ${i}_2.fastq.gz ]]
  then 
    >&2 echo "WARNING: Run $i does not seem to have two fastq files associated with it! Please investigate."
  fi 
done 

for i in $SAMPLES
do
  >&2 echo "Moving the files for sample $i:" 
  mkdir $i 
  SMPRUNS=`grep $i ../sample_to_run.tsv | awk '{print $2}' | tr ',' '\n'`
  for j in $SMPRUNS
  do
    >&2 echo "==> Run $j belongs to sample $i, moving to directory $i.." 
    mv ${j}_?.fastq.gz $i
  done 
  mv $i ../fastqs 
  >&2 echo "Moving directory $i to /fastqs.."
done 

echo "REORGANISE FASTQS: ALL DONE!" 

