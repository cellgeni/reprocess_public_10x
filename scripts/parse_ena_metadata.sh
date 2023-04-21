#!/bin/bash

SERIES=$1

if [[ -f $SERIES.urls.list ]]
then
  >&2 echo "WARNING: File '$SERIES.urls.list' exists! This should not happen; overwriting the file.." 
  rm $SERIES.urls.list
fi 

for i in `cat $SERIES.run.list`
do
  TYPE="SRA"
  LOC=""
  SPECIES=`grep -w $i $SERIES.ena.tsv | cut -f10`
  GZ1=`grep -w $i $SERIES.ena.tsv | cut -f11 | grep "_1\.fastq.gz" | grep "_2\.fastq.gz"`
  GZ2=`grep -w $i $SERIES.ena.tsv | cut -f12 | grep "_R1_.*\.fastq.gz" | grep "_R2_.*\.fastq.gz"`
  BAM=`grep -w $i $SERIES.ena.tsv | cut -f12 | tr ';' '\n' | grep -v "\.bai" | grep "\.bam"` ## don't need the BAM index which is often there
  SRA=`grep -w $i $SERIES.ena.tsv | cut -f13` 
  
  if [[ $GZ1 != "" ]]
  then
    TYPE="GZP"
    LOC=$GZ1
    echo $GZ1 | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as paired-end fastq archive: $LOC"
  elif [[ $GZ2 != "" ]]
  then
    TYPE="GZP"
    LOC=$GZ2
    echo $GZ2 | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ArrayExpress as original submitter's paired-end fastq: $LOC"
  elif [[ $BAM != "" ]]
  then
    TYPE="BAM"
    LOC=$BAM
    echo $BAM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as an original submitter's BAM file: $LOC"
  elif [[ $SRA != "" ]]
  then 
    TYPE="SRA"
    LOC=$SRA
    echo $SRA >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as an SRA archive: $LOC"
  else
    ## means $SRA == "" for some reason - usually this is a failure of ENA, but not always 
    SRA=`srapath $i`
    LOC=$SRA
    >&2 echo "WARNING: No ENA ftp URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
    echo $SRA >> $SERIES.urls.list
    >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

