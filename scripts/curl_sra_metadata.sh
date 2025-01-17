#!/bin/bash -e

RUNS=$1

if [[ ! -f $RUNS ]]
then
  >&2 echo "ERROR: file $RUNS not found!"
  exit 1
fi

KK=`cat $RUNS`

for i in $KK
do
  >&2 echo "Processing run ID $i.."
  wget --quiet --output-document="$i.xml" "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=${i}&usehistory=y"
  WebEnv=$(grep -oP '<WebEnv>\K[^<]+' $i.xml)
  QueryKey=$(grep -oP '<QueryKey>\K[^<]+' $i.xml)
  rm -f $i.xml
  curl "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/sra-db-be.cgi?rettype=runinfo&WebEnv=${WebEnv}&query_key=${QueryKey}" 2> /dev/null | sed '/BioProject/d' | sed  's/,/\t/g'
done

>&2 echo "CURL SRA METADATA: ALL DONE!"
