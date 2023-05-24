#!/bin/bash

SERIES=$1

if [[ -f $SERIES.urls.list ]]
then
  >&2 echo "WARNING: File '$SERIES.urls.list' exists! This should not happen; overwriting the file.." 
  rm $SERIES.urls.list
fi 

for i in `cat $SERIES.run.list`
do
  TYPE="SRA"  ## we always default to SRA. This could cause problems for very fresh datasets. 
  LOC=""
  AEGZ="" 
  if [[ $SERIES == E-MTAB-* ]]
  then 
    AEGZ=`grep -w $i $SERIES.sdrf.txt | tr '\t' '\n' | grep "ftp://.*\.f.*q" | tr '\n' ';' | sed "s/;$//"`
  fi 
  SPECIES=`grep -w $i $SERIES.ena.tsv | cut -f10`
  ENAGZ=`grep -w $i $SERIES.ena.tsv | cut -f11 | grep "_1\.fastq.gz" | grep "_2\.fastq.gz"`     ## ENA formatting is strict
  ORIFQ=`grep -w $i $SERIES.ena.tsv | cut -f12 | grep "f.*q"`                                   ## ppl name files *all kinds of random shiz*, really
  ORIBAM=`grep -w $i $SERIES.ena.tsv | cut -f12 | tr ';' '\n' | grep -v "\.bai" | grep "\.bam"` ## don't need the BAM index which is often there
  SRA=`grep -w $i $SERIES.ena.tsv | cut -f13` 
  

  if [[ $AEGZ != "" ]]
  then
    TYPE="GZP"
    LOC=$AEGZ
    echo $AEGZ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ArrayExpress as paired-end fastq archive: $LOC"
  elif [[ $ENAGZ != "" ]]
  then
    TYPE="GZP"
    LOC=$ENAGZ
    echo $ENAGZ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as a paired-end fastq: $LOC"
  elif [[ $ORIFQ != "" ]]
  then
    TYPE="GZP"
    LOC=$ORIFQ
    echo $ORIFQ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as original submitter's fastq: $LOC"
  elif [[ $ORIBAM != "" ]]
  then
    TYPE="BAM"
    LOC=$ORIBAM
    echo $ORIBAM >> $SERIES.urls.list
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

