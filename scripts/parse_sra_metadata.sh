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

  SPECIES=`grep -w $i $SERIES.sra.tsv | cut -f8 | tr -d '\r'`
  BAM=`grep -w $i $SERIES.sra.tsv | cut -f17 | tr -d '\r'` 
  SRA_LITE=`grep -w $i $SERIES.sra.tsv | cut -f11 | tr -d '\r'`
  SRA_NORM=`grep -w $i $SERIES.sra.tsv | cut -f14 | tr -d '\r'`  
  

  if [[ $BAM != "" ]]
  then 
    LOC=$BAM
    TYPE="BAM"
    echo $BAM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an BAM: $LOC"
  elif [[ $SRA_LITE != "" ]]
  then 
    LOC=$SRA_LITE
    echo $SRA_LITE >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an SRA archive: $LOC"
  elif [[ $SRA_NORM != "" ]]
  then 
    LOC=$SRA_NORM
    echo $SRA_NORM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an SRA archive: $LOC"
  else
    SRA=`srapath $i`
    LOC=$SRA
    >&2 echo "WARNING: No URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
    echo $SRA >> $SERIES.urls.list
    >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

