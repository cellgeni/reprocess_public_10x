#!/bin/bash 

SERIES=$1 ## GSE123456

## all BAM/SRA -> fastq.gz conversion is done in /done_wget
cd done_wget
cp ../$SERIES.parsed.tsv . 
cp ../bsub_bam2fastq.sh .
cp ../bsub_sra2fastq.sh .
cp ../bam_to_10x_fastq_gz.sh .
cp ../sra_to_10x_fastq_gz.sh .

BAMS=`grep -w "BAM$" $SERIES.parsed.tsv | cut -f1`
SRAS=`grep -w "SRA$" $SERIES.parsed.tsv | cut -f1`

for i in $BAMS
do
  URL=`grep -w $i $SERIES.parsed.tsv | cut -f3`
  FILE=`basename $URL`
  >&2 echo "Renaming BAM file $FILE to $i.bam.." 
  mv $FILE $i.bam
done

## job array submission here
if [[ $BAMS != "" ]]
then 
  ./bsub_bam2fastq.sh $SERIES bam_to_10x_fastq_gz.sh
fi

for i in $SRAS
do
  URL=`grep -w $i $SERIES.parsed.tsv | cut -f3`
  FILE=`basename $URL`
  >&2 echo "Renaming SRA file $FILE to $i.." 
  mv $FILE $i
done

## job array submission here
if [[ $SRAS != "" ]]
then
  ./bsub_sra2fastq.sh $SERIES sra_to_10x_fastq_gz.sh
fi

## patiently wait for all the jobs to complete
while [[ `bjobs -w | grep "2fastq\.$SERIES" ` != "" ]] 
do 
  sleep 300
done

>&2 echo "CONVERTING SRA/BAM TO FASTQ: ALL DONE!" 
