#!/bin/bash 

## check that all the runs have exactly 2 archived fastq files associated with them, 
## and re-organise them according to sample_to_run.tsv 

SERIES=$1
mkdir fastqs

SAMPLES=`cat $SERIES.sample.list`
RUNS=`cat $SERIES.run.list`

## at this point, all the downloaded or converted fastq.gz files should be in /done_wget
cd done_wget

for i in $RUNS
do
  if [[ ! -s ${i}_1.fastq.gz || ! -s ${i}_2.fastq.gz || ! -d $i ]]
  then 
    >&2 echo "WARNING: Run $i does not seem to have two fastq files (or a bamtofastq output directory) associated with it! Please investigate."
  fi 
done 

for i in $SAMPLES
do
  >&2 echo "Moving the files for sample $i:" 
  mkdir $i 
  SMPRUNS=`grep $i ../$SERIES.sample_x_run.tsv | awk '{print $2}' | tr ',' '\n'`
  for j in $SMPRUNS
  do
    >&2 echo "==> Run $j belongs to sample $i, moving to directory $i.." 
    if [[ -s ${j}_1.fastq.gz ]]
    then
      mv ${j}_?.fastq.gz $i
    elif [[ -d $j ]] 
    then
      mv $j $i
    fi
  done 
  mv $i ../fastqs 
  >&2 echo "Moving directory $i to /fastqs.."
done 

echo "REORGANISE FASTQS: ALL DONE!" 

