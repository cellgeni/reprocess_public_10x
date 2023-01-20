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
  curl "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$i&result=read_run&fields=study_accession,secondary_study_accession,sample_accession,secondary_sample_accession,experiment_accession,experiment_alias,run_accession,run_alias,tax_id,scientific_name,fastq_ftp,submitted_ftp,sra_ftp&format=tsv&download=true&limit=0" | grep -v study_accession
done

>&2 echo "CURL ENA METADATA: ALL DONE!"
