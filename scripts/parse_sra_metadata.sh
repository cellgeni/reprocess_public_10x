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
  SRABAM=`curl -s "https://locate.ncbi.nlm.nih.gov/sdl/2/retrieve?acc=$i&accept-alternate-locations=yes" | jq -r '
          .result[].files[] | 
          select(.name | contains("bam")) | 
          .locations[] | 
          select((.rehydrationRequired // false) == false and (.payRequired // false) == false) | 
          .link
        '`

  if [[ $SRABAM != "" ]]
  then
    TYPE="BAM"
    LOC=$SRABAM
    echo $SRABAM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an original submitter's BAM file: $LOC"
  elif [[ $SRA != "" ]]
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

