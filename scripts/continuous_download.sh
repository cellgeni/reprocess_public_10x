#!/bin/bash 

### basically a script to keep downloading things for as long as it is necessary
### step 0: start downloading everything using transfer queue

SERIES=$1
URLS="URLs.list"

if [[ $URLS == "" ]]
then 
  echo "Usage: ./continuous_download.sh <series_id> <URLs_list>"
  exit 1
fi

COUNT=1
## since this is a part of reprocessing script, we assume all the necessary sub-scripts have been copied already

echo "Iteration 1: downloading the files..."
echo "--------------------------------------------------------" 

## job array submission - use the whole list here
./bsub_transfer.sh $SERIES wget_restart.sh $URLS


## step 1: check if all the download jobs have finished successfully. 
##'bjobs -w' shows full job name; job array submission ensures all the naming is consistent
while [[ `bjobs -w | grep "transfer\.$SERIES"` != "" ]] 
do 
  sleep 300
done

## they did finish! let's run the cleanup  
echo "Cleanup 1: running the cleanup script..."
echo "--------------------------------------------------------" 
./cleanup_wget_downloads.sh $URLS

## let us repeat until no URLs are left in missing_URLs.list
while [[ -f missing_URLs.list ]]
do
  COUNT=$((COUNT+1))
  echo "Iteration $COUNT: downloading the files..." 
  echo "--------------------------------------------------------" 

  ## again, same job array strategy
  ./bsub_transfer.sh $SERIES wget_restart.sh missing_URLs.list
   
  ## wait patiently 
  while [[ `bjobs -w | grep "transfer\.$SERIES"` != "" ]] 
  do 
    sleep 300
  done
  
  ## they did finish! let's run the cleanup again
  echo "Cleanup $COUNT: running the cleanup script..."
  echo "--------------------------------------------------------" 
  ./cleanup_wget_downloads.sh $URLS
done

echo "FILE DOWNLOAD: ALL DONE!"  

