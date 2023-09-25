#!/bin/bash -e

## V3: identify 10X samples, faster processing with tuned fasterq-dump & pigz 

PARSED=$1
SRA=`grep -w "SRA$" $PARSED | cut -f1 | head -$LSB_JOBINDEX | tail -1` 
WL=/nfs/cellgeni/STAR/whitelists
CPUS=16 

## fasterq-dump with extra settings tailored to our Farm environment 

fasterq-dump --threads $CPUS -b 10M -c 100M -m 5000M --split-files --include-technical $SRA

## then, find which reads contain actual 10X whitelist

BC=""
for i in ${SRA}*fastq
do
  seqtk sample -s100 $i 200000 | awk 'NR%4==2' | cut -c-14 | grep -F -f $WL/737K-april-2014_rc.txt | wc -l > $i.v1.count &
  seqtk sample -s100 $i 200000 | awk 'NR%4==2' | cut -c-16 | grep -F -f $WL/737K-august-2016.txt   | wc -l > $i.v2.count &
  seqtk sample -s100 $i 200000 | awk 'NR%4==2' | cut -c-16 | grep -F -f $WL/3M-february-2018.txt   | wc -l > $i.v3.count &
  seqtk sample -s100 $i 200000 | awk 'NR%4==2' | cut -c-16 | grep -F -f $WL/737K-arc-v1.txt        | wc -l > $i.arc.count &
done 

wait

## now let's analyze the results obtained
NMATCH=0
for i in ${SRA}*count
do
  N=`cat $i`
  KIT=${i%%.count}
  KIT=${KIT##$SRA*.fastq.}
  if (( $N > 50000 ))
  then
    BC=${i%%.$KIT.count}
    echo "Barcode file: $BC, matching whitelist: $KIT, number of matched barcodes: $N"
    NMATCH=$((NMATCH+1))
  fi
done 

## bail if more than 1 match - not going to accept that; also, DO NOT delete fastq files and report a warning if no WL is matched. 
if (( $NMATCH > 1 ))
then
  echo "WARNING: More than 1 file/whitelist match! This should not happen, please investigate the files in the log above." 
elif (( $NMATCH == 0 )) 
then
  echo "WARNING: No files matched any of the whitelists! Most likely, this experiment is not a 10X single-cell RNA-seq". 
fi 

## finally, find the longest read among the remaining and nominate it biological if reads are identified as 10x 
## otherwise, just compress everything and be done with it
if (( $NMATCH == 1 )) 
then
  BIO=""
  BLEN=0
  for i in `ls ${SRA}*fastq | grep -v $BC`
  do
    CURLEN=`head -n400 $i | awk 'NR%4==2' | awk '{sum+=length($0)} END {printf "%d\n",sum/NR+0.5}'`
    if (( $CURLEN >= $BLEN ))
    then
      BIO=$i
      BLEN=$CURLEN
    fi
  done
  
	echo "The longest read (aside from the barcode-carrying read): $BIO, mean read length: $BLEN"
  
	## delete all the unnecessary fastq files (index etc), rename, and gzip R1/R2
  mv $BC $SRA.tmp1
  mv $BIO $SRA.tmp2
  if [[ `ls | grep $SRA | grep "fastq$"` != "" ]] 
  then 
    rm $SRA*fastq
  fi
  mv $SRA.tmp1 ${SRA}_1.fastq
  mv $SRA.tmp2 ${SRA}_2.fastq
  
  pigz -p $CPUS ${SRA}_1.fastq
  pigz -p $CPUS ${SRA}_2.fastq
else
	## if things look weird, just compress everything, we'll sort it later
  for i in ${SRA}*fastq
  do
    pigz -p $CPUS $i 
  done
fi 
