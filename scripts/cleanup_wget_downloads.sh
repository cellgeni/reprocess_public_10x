#!/bin/bash 

if (( $# == 0 ))
then
  echo "USAGE: ./cleanup_wget_downloads.sh <URLs.list>"
  echo "Please provide the list of URLs used for original download!"
  exit 1
fi

URLS=$1
KK=`cat $URLS`
AC=0
DC=0

if [[ -d done_wget ]]
then
  echo "Found directory named 'done_wget', will use it to move completed downloads!"
else 
  echo "No directory named 'done_wget' found! will create it and use to move completed downloads!"
  mkdir done_wget
fi

if [[ -f missing_URLs.list ]] 
then
  echo "Found file named 'missing_URLS.list'; deleting it.." 
  rm missing_URLs.list
fi

for i in $KK
do
  TAG=`basename $i`
  TAG=${TAG%%.fastq.gz}  ## this should work for both SRA (SRR1245 or SRR1245.1 formats), and *_1.fastq.gz/*_2.fastq.gz downloads
  if [[ -f $TAG.wget.log ]]
  then 
    SV=`tail $TAG.wget.log | grep -wF saved | wc -l`
    if (( $SV == 1 ))
    then
      AC=$((AC+1))
      DC=$((DC+1)) 
      echo "Sample # $AC ($TAG) was downloaded successfully, moving files to /done_wget!"
      mv ${TAG}* done_wget
    else 
      AC=$((AC+1)) 
      echo "Sample # $AC ($TAG) was NOT downloaded successufully; removing remaining files and adding URL to 'missing_URLs.list'!" 
      rm ${TAG}*
      echo $i >> missing_URLs.list
    fi
  else 
    AC=$((AC+1)) 
    echo "Sample # $AC ($TAG)   --  download was not attempted, probably completed earlier..."
  fi
done

echo "Cleanup done! Total number of evaluated files: $AC, successfully downloaded: $DC."
