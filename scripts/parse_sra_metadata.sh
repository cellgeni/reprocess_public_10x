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
  SPECIES=${SPECIES:-UNKNOWN}
  SRA=`grep -w $i $SERIES.sra.tsv | cut -f10`

  SUCCESS=0

  # Try getting BAM file from SDL api
  SDLBAM=`curl -s "https://locate.ncbi.nlm.nih.gov/sdl/2/retrieve?acc=$i&accept-alternate-locations=yes" | jq -r '
          .result[].files[] |
          select(.name | contains("bam")) |
          .locations[] |
          select((.rehydrationRequired // false) == false and (.payRequired // false) == false) |
          .link
        '`
  sleep 0.3
  if [[ $SDLBAM != "" ]]
  then
    TYPE="BAM"
    LOC=$SDLBAM
    echo $SDLBAM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via SRA as an original submitter's BAM file: $LOC"
    SUCCESS=1
  fi

  # Try getting SRA file from SDL api
  if [[ $SUCCESS -eq 0 ]]
  then
    SDLSRA=`curl -s "https://locate.ncbi.nlm.nih.gov/sdl/2/retrieve?acc=$i&accept-alternate-locations=yes" | jq -r '
              [
                .result[]
                .files[]
                | select(.type == "sra")
                | .locations[]
                | select((.payRequired // false) == false)
              ]
              | map(.link)
              | first'`
    sleep 0.3
    if [[ $SDLSRA != "" ]]
    then
      TYPE="SRA"
      LOC=$SDLSRA
      echo $SDLSRA >> $SERIES.urls.list
      >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
      SUCCESS=1
    elif [[ $SRA != "" ]]
    then
      LOC=$SRA
      echo $SRA >> $SERIES.urls.list
      >&2 echo "Sample $i is available via SRA as an SRA archive: $LOC"
      SUCCESS=1
    else
      SRA=`srapath $i`
      LOC=$SRA
      >&2 echo "WARNING: No ENA ftp URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
      echo $SRA >> $SERIES.urls.list
      >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
    fi
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

