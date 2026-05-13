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
  SPECIES=${SPECIES:-UNKNOWN}
  ENAGZ=`grep -w $i $SERIES.ena.tsv | cut -f11 | grep "_1\.fastq.gz" | grep "_2\.fastq.gz"`     ## ENA formatting is strict
  ORIFQ=`grep -w $i $SERIES.ena.tsv | cut -f12 | grep "f.*q"`                                   ## ppl name files *all kinds of random shiz*, really
  ORIBAM=`grep -w $i $SERIES.ena.tsv | cut -f12 | tr ';' '\n' | grep -v "\.bai" | grep "\.bam"` ## don't need the BAM index which is often there
  SRA=`grep -w $i $SERIES.ena.tsv | cut -f13`

  # First priority
  SUCCESS=0
  if [[ $AEGZ != "" ]]
  then
    TYPE="ORIFQ"
    LOC=$AEGZ
    echo $AEGZ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ArrayExpress as paired-end fastq archive: $LOC"
    SUCCESS=1
  elif [[ $ENAGZ != "" ]]
  then
    TYPE="ENAFQ"
    LOC=$ENAGZ
    echo $ENAGZ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as a paired-end fastq: $LOC"
    SUCCESS=1
  elif [[ $ORIFQ != "" && $ORIBAM == "" ]]
  then
    TYPE="ORIFQ"
    LOC=$ORIFQ
    echo $ORIFQ | tr ';' '\n' >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as original submitter's fastq: $LOC"
    SUCCESS=1
  elif [[ $ORIBAM != "" ]]
  then
    TYPE="BAM"
    LOC=$ORIBAM
    echo $ORIBAM >> $SERIES.urls.list
    >&2 echo "Sample $i is available via ENA as an original submitter's BAM file: $LOC"
    SUCCESS=1
  fi
  
  # Try getting BAM file from SDL api
  if [[ $SUCCESS -eq 0 ]]
  then
    # Try getting BAM from SDL
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
      >&2 echo "Sample $i is available via NCBI/Amazon as a BAM file: $LOC"
      SUCCESS=1
    elif [[ $SRA != "" ]]
    then 
      TYPE="SRA"
      LOC=$SRA
      echo $SRA >> $SERIES.urls.list
      >&2 echo "Sample $i is available via ENA as an SRA archive: $LOC"
      SUCCESS=1
    fi
  fi

  # Try getting SRA file from SDL api
  if [[ $SUCCESS -eq 0 ]]
  then
    # Try getting SRA from SDL
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
    else
      ## means $SRA == "" for some reason - usually this is a failure of ENA, but not always 
      SRA=`srapath $i`
      LOC=$SRA
      >&2 echo "WARNING: No ENA ftp URL found for sample $i, using 'srapath' to get the (open) Amazon link to SRA archive.."
      echo $SRA >> $SERIES.urls.list
      >&2 echo "Sample $i is available via NCBI/Amazon as an SRA archive: $LOC"
      SUCCESS=1
    fi
  fi

  echo -e "$i\t$SPECIES\t$LOC\t$TYPE"
done

