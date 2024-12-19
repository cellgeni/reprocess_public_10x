#!/bin/bash -e

SERIES=$1
RUNS="$SERIES.project.list"

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
  curl "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/sra-db-be.cgi?rettype=exp&WebEnv=${WebEnv}&query_key=${QueryKey}" 2> /dev/null > $i.sra.xml
  ./parse_sra_xml.py --output $i.sra.tsv  $i.sra.xml
  rm $i.sra.xml
done

cat *.sra.tsv > $SERIES.sra.tsv

>&2 echo "CURL SRA METADATA: ALL DONE!"
