#!/bin/bash

RUNS=$1
SERIES="${RUNS%%.*}"

if [[ ! -f $RUNS ]]
then
  >&2 echo "ERROR: file $RUNS not found!"
  exit 1
fi

KK=`cat $RUNS`

: > $SERIES.ena.tsv

for i in $KK
do
  >&2 echo "Processing run ID $i.."
  curl "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$i&result=read_run&fields=study_accession,secondary_study_accession,sample_accession,secondary_sample_accession,experiment_accession,experiment_alias,run_accession,run_alias,tax_id,scientific_name,fastq_ftp,submitted_ftp,sra_ftp&format=tsv&download=true&limit=0" 2> /dev/null | grep -v study_accession >> $SERIES.ena.tsv
done

set -e

if [[ ! -s $SERIES.ena.tsv ]]
then
  >&2 echo "WARNING: Was not able to load metadata from ENA. Loading it from SRA..."
  for i in $KK
  do
    curl "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/sra-db-be.cgi?rettype=runinfo&term=$i" $SERIES.ena.tsv 2> /dev/null >> $SERIES.ena.tsv
  done
fi

>&2 echo "CURL METADATA: ALL DONE!"
