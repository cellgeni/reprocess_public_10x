#!/bin/bash

ENA=$1 ## ENA metadata from curl_ena_metadata.sh 

if [[ -f URLs.list ]]
then
  >&2 echo "ERROR: File 'URLs.list' exists! This should not happen, please investigate." 
  exit 1
fi 

KK=`cat run.list`

for i in $KK
do
  TYPE="SRA"
  SPECIES=`grep -w $i $ENA | cut -f6`
  LOC=""
  GZP=`grep -w $i $ENA | tr '\t' '\n' | grep "_1\.fastq.gz" | grep "_2\.fastq.gz"`
  BAM=`grep -w $i $ENA | tr '\t' '\n' | tr ';' '\n' | grep -v "\.bai" | grep "\.bam"` ## don't need the BAM index which is often there
  SRA=`grep -w $i $ENA | cut -f9` ## not sure how robust this is, but practice will showeth
  
  if [[ $GZP != "" ]]
  then
    TYPE="GZP"
    LOC=$GZP
    echo $GZP | tr ';' '\n' >> URLs.list
    >&2 echo "Sample $i is available via ENA as paired-end fastq archive: $LOC"
  elif [[ $BAM != "" ]]
  then
    TYPE="BAM"
    LOC=$BAM
    echo $BAM >> URLs.list
    >&2 echo "Sample $i is available via ENA as an original submitter's BAM file: $LOC"
  elif [[ $SRA != "" ]]
  then 
    TYPE="SRA"
    LOC=$SRA
    echo $SRA >> URLs.list
    >&2 echo "Sample $i is available via ENA as an SRA archive: $LOC"
  else
    ## means $SRA == "" for some reason - usually this is a failure of ENA, but not always 
    SRA=`srapath $i`
    LOC=$SRA
    >&2 echo "WARNING: No ENA ftp URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
    echo $SRA >> URLs.list
    >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

