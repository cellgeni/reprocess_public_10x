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

  SPECIES=`grep -w $i $SERIES.sra.tsv | cut -f29`
  SRA=`grep -w $i $SERIES.sra.tsv | cut -f10` 
  
  if [[ $SRA != "" ]]
  then 
    LOC=$SRA
    echo $SRA >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an SRA archive: $LOC"
  else
    SRA=`srapath $i`
    LOC=$SRA
    >&2 echo "WARNING: No ENA ftp URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
    echo $SRA >> $SERIES.urls.list
    >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

