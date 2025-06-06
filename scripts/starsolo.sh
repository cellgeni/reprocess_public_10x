#!/bin/bash -e 

## v3.2 of STARsolo wrappers is set up to guess the chemistry automatically
## newest version of the script uses STAR v2.7.10a with EM multimapper processing 
## in STARsolo which on by default; the extra matrix can be found in /raw subdir 

FQDIR=$1
SERIES=$2

if [[ $FQDIR == "" || $SERIES == "" ]]
then
  >&2 echo "Usage: ./starsolo_10x_auto.sh <fastq_dir> <series_id (GSE,E-MTAB,PRJNA)>"
  >&2 echo "(make sure you set the correct REF, WL, and BAM variables below)"
  exit 1
fi

## this is BSUB job array environmental variable
TAG=`head -$LSB_JOBINDEX $SERIES.sample.list | tail -1`

SHORTSP=""
RUNS=`grep -w $TAG $SERIES.sample_x_run.tsv | cut -f2 | tr ',' '|'`
LONGSP=`grep -P "$RUNS" $SERIES.parsed.tsv | cut -f2 | sort | uniq`

if [[ $LONGSP == "Homo sapiens" ]]
then
  SHORTSP="human"
elif [[ $LONGSP == "Mus musculus" ]]
then
  SHORTSP="mouse"
else
  >&2 echo "ERROR: It seems like sample $TAG is neither human no mouse! please investigate." 
  exit 1
fi

FQDIR=`readlink -f $FQDIR`

starsolo_10x_auto.sh $FQDIR $TAG $SHORTSP
