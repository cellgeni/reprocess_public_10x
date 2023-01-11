#!/bin/bash 

SERIES=$1 ## GSE123456
SAMPLES="sample.list" 

## job array submission here
./bsub_starsolo.sh $SERIES starsolo_10x_auto.sh `pwd`/fastqs $SAMPLES

while [[ `bjobs -w | grep "starsolo\.$SERIES" ` != "" ]] 
do
  sleep 300
done

## TODO: add cleanup and re-running of failed samples - esp ones that timed out. 
## also add failsafe thing for some stupid cases when things would fail consistently - e.g. non-10x samples?  

>&2 echo "RUNNING STARSOLO: ALL DONE!" 
