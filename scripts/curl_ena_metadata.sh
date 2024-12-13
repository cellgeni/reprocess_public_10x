#!/bin/bash -e

SERIES=$1
RUNS="$SERIES.project.list"

if [[ ! -f $RUNS ]]
then
  >&2 echo "ERROR: file $RUNS not found!"
  exit 1
fi

KK=`cat $RUNS`

: > $SERIES.ena.tsv

for i in $KK
do
  >&2 echo "Loading ENA metadata for $i.."
  curl "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$i&result=read_run&fields=study_accession,secondary_study_accession,sample_accession,secondary_sample_accession,experiment_accession,experiment_alias,run_accession,run_alias,tax_id,scientific_name,fastq_ftp,submitted_ftp,sra_ftp&format=tsv&download=true&limit=0" 2> /dev/null | sed '/study_accession/d' >> $SERIES.ena.tsv
done


if [[ $SERIES == GSE* ]]
then
  >&2 echo "Loading SRA metadata for $i..."
  for i in $KK
  do
    wget --quiet --output-document="$i.xml" "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=${i}&usehistory=y"
    WebEnv=$(grep -oP '<WebEnv>\K[^<]+' $i.xml)
    QueryKey=$(grep -oP '<QueryKey>\K[^<]+' $i.xml)
    rm -f $i.xml
    curl "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/sra-db-be.cgi?rettype=exp&WebEnv=${WebEnv}&query_key=${QueryKey}" 2> /dev/null > $i.sra.xml
    ./parse_sra_xml.py --output $i.sra.tsv  $i.sra.xml
    rm $i.sra.xml
  done
fi

cat *.sra.tsv > $SERIES.sra.tsv

>&2 echo "CURL METADATA: ALL DONE!"
