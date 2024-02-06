#!/bin/bash 

## check that all the runs have exactly 2 archived fastq files associated with them, 
## and re-organise them according to sample_to_run.tsv 

SERIES=$1
if (( $# != 1 ))
then
  >&2 echo "USAGE: ./reorganize_fastq.sh <series_id>"
  >&2 echo
  >&2 echo "(requires non-empty <series_id>.sample.list, <series_id>.run.list, <series_id>.parsed.tsv, and <series_id>.sample_x_run.list)" 
  exit 1
fi

mkdir fastqs

SAMPLES=`cat $SERIES.sample.list`
RUNS=`cat $SERIES.run.list`

## at this point, all the downloaded or generated (from BAM or SRA) fastq.gz files should be in /done_wget
## four general cases are possible; type from <series_id>.parsed.tsv listed: 
## 1) gzipped files from ENA - these are always formatted as S/ERR12345_1/2.fastq.gz, type ENAFQ
## 2) gzipped files from original submitter - anything can happen in terms of format, type ORIFQ 
## 3) files converted from SRA - these should follow same convention as ENA, type SRA; 
## 4) files converted from BAM - these are located in folders and have strict Cell Ranger format, type BAM 

cd done_wget

for i in $RUNS
do
	TYPE=`grep -wF $i ../$SERIES.parsed.tsv | cut -f4`
	if [[ $TYPE == "ENAFQ" || $TYPE == "SRA" ]]
	then
    if [[ ! -s ${i}_1.fastq.gz || ! -s ${i}_2.fastq.gz ]]  
    then 
		  >&2 echo "WARNING: Run $i (type $TYPE) does not have two fastq files associated with it! Please investigate.."
    fi 
	elif [[ $TYPE == "BAM" ]]
	then
		if [[ ! -d $i ]]
		then 
			>&2 echo "WARNING: Run $i (type $TYPE) did not generate an output directory! Please investigate.."
		fi 

		NR1=`find $i/* | grep -c "_R1_...\.fastq.gz"`
		NR2=`find $i/* | grep -c "_R2_...\.fastq.gz"`
		if (( $NR1 != $NR2 || $NR1 == 0 || $NR2 == 0 )) 
		then 
			>&2 echo "WARNING: Run $i (type $TYPE) has $NR1 R1 files and $NR2 R2 files, which should not happen. Please investigate.." 
		fi
	elif [[ $TYPE == "ORIFQ" ]]
	then
		ORIFQS=`grep -wF $i ../$SERIES.parsed.tsv | cut -f3 | tr ';' ' ' | xargs basename -a | tr '\n' '|' | sed "s/|$//"`
		NR1=`find * | grep -P "$ORIFQS" | grep -cP "_1\.f.*q\.gz|R1\.f.*q\.gz|_R1_.*\.f.*q\.gz"`
		NR2=`find * | grep -P "$ORIFQS" | grep -cP "_2\.f.*q\.gz|R2\.f.*q\.gz|_R2_.*\.f.*q\.gz"`
    if (( $NR1 != $NR2 || $NR1 == 0 || $NR2 == 0 )) 
    then 
      >&2 echo "WARNING: Run $i (type $TYPE) has $NR1 R1 files and $NR2 R2 files, which should not happen. Please investigate.."
    fi
	fi
done 

for i in $SAMPLES
do
  >&2 echo "Moving the files for sample $i:" 
  mkdir $i 
  SMPRUNS=`grep $i ../$SERIES.sample_x_run.tsv | awk '{print $2}' | tr ',' '\n'`
  for j in $SMPRUNS
  do
    >&2 echo "==> Run $j belongs to sample $i, moving to directory $i.." 
    if [[ -s ${j}_1.fastq.gz ]]
    then
      mv ${j}_?.fastq.gz $i
    elif [[ -d $j ]] 
    then
      mv $j $i
    else
      ## special case for original submitter's fastqs: 
      URLS=`grep $j ../$SERIES.parsed.tsv | cut -f3 | tr ';' '\n'`
      for k in $URLS
      do
        ORIFQ=`basename $k`
        mv $ORIFQ $i
      done
    fi
  done 
  mv $i ../fastqs 
  >&2 echo "Moving directory $i to /fastqs.."
done 

echo "REORGANISE FASTQS: ALL DONE!" 

