#!/bin/bash 

SERIES=$1 ## GSE123456
if (( $# != 1 ))
then
  >&2 echo "USAGE: ./run_starsolo.sh <series_id>"
  >&2 echo
  >&2 echo "(requires bsub_starsolo.sh, starsolo_10x_auto.sh, and non-empty /fastqs directory)" 
  exit 1
fi

## job array submission here
bsub_starsolo.sh $SERIES starsolo_10x_auto.sh `pwd`/fastqs

while [[ `bjobs -w | grep "starsolo\.$SERIES" ` != "" ]] 
do
  sleep 300
done

## also add failsafe thing for some stupid cases when things would fail consistently - e.g. non-10x samples?  

>&2 echo "RUNNING STARSOLO: ALL DONE!" 
