#!/bin/bash 

SERIES=$1 ## GSE123456

## job array submission here
./bsub_starsolo.sh $SERIES starsolo_10x_auto.sh `pwd`/fastqs

while [[ `bjobs -w | grep "starsolo\.$SERIES" ` != "" ]] 
do
  sleep 300
done

## also add failsafe thing for some stupid cases when things would fail consistently - e.g. non-10x samples?  

>&2 echo "RUNNING STARSOLO: ALL DONE!" 
