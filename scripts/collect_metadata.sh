#!/bin/bash 

SERIES=$1

## rerun ffq if some fetching fails due to network issues
RET=1    
until [ ${RET} -eq 0 ]    
do    
  ffq $SERIES > $SERIES.ffq.json    
  RET=$?                                                  
  sleep 1
done

## homemade JSON parser to make a flat TSV file. Multiple SRR/ERR entries are comma-separated    
./parse_json.pl $SERIES.ffq.json > $SERIES.accessions.tsv                                                                                                                    
cut -f 1 $SERIES.accessions.tsv | sort | uniq > sample.list    
cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > run.list    
cut -f 1,4 $SERIES.accessions.tsv > sample_to_run.tsv

## curl info about each run (SRR/ERR/DRR) from ENA API 
RET=1
until [ ${RET} -eq 0 ]
do
  ./curl_ena_metadata.sh run.list > $SERIES.ena.tsv 
  RET=$?
  sleep 1
done

## classify each run into 3 major types: 
## 1) we have useable 10x paired-end files; 2) we need to get them from 10x BAM; 3) we need to get them from SRA
## simultaneously, 'URLs.list' is generated
./parse_ena_metadata.sh $SERIES.ena.tsv > $SERIES.parsed.tsv
