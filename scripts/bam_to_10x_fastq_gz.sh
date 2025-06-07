#!/bin/bash 


function bam2fastq {
  local RUN=$1
  local CPUS=$2
  local CMD=${3:-""}
  ## this has to be 10x bamtofastq, ideally the latest version
  ## TODO: need to somehow auto-detect when --cr11 is needed
  $CMD bamtofastq --nthreads $CPUS $RUN.bam $RUN

  ## if the chemistry version is v1, the reads would be split into R1 (biological), R2 (barcode, 14 bp) and R3 (UMI, 10 bp).
  ## as we won't be able to process those, we need to fix it 

  if [[ `find $RUN/* | grep "_R3_.*fastq.gz"` != "" ]]
  then 
    >&2 echo "WARNING: bamtofastq generated read R3! This doesn't usually happen for GEX samples, except for v1 chemistry."
    R1=`find $RUN/* | grep "_R1_.*fastq.gz"`     
    R2=`find $RUN/* | grep "_R2_.*fastq.gz"`    
    R3=`find $RUN/* | grep "_R3_.*fastq.gz"`    
    R1F=`echo $R1 | cut -d' ' -f1`
    R2F=`echo $R2 | cut -d' ' -f1`
    R3F=`echo $R3 | cut -d' ' -f1`
    L1=`zcat $R1F | head -2 | tail -1 | awk '{print length($0)}'`                                                                       
    L2=`zcat $R2F | head -2 | tail -1 | awk '{print length($0)}'`
    L3=`zcat $R3F | head -2 | tail -1 | awk '{print length($0)}'`
    if (( $L1 > 50 && $L2 == 14 && $L3 == 10))
    then 
      >&2 echo "WARNING: v1 chemistry confirmed (read length: R1:$L1, R2:$L2, R3:$L3)! Will concatenate BC+UMI, and move BC+UMI to R1, and biological read to R2.."
      ## inflate the reads - it's more robust than process subs.. 
      for r2 in $R2
      do 
        r3=`echo $r2 | sed "s/_R2_/_R3_/"`
        gzip -d $r2 &
        gzip -d $r3 &
      done
      wait
      
      ## paste BC+UMI, gzip it
      for r2 in $R2
      do 
        r2fq=`echo $r2 | sed "s/\.gz$//"`
        r3fq=`echo $r2 | sed "s/_R2_/_R3_/" | sed "s/\.gz$//"`
        paste $r2fq $r3fq | awk -F '\t' '{if (NR%2==1) {print $1} else {print $1$2}}' | pigz > $r2.fixed &             
      done
      wait
      
      ## move reads around
      for r2 in $R2
      do 
        r1=`echo $r2 | sed "s/_R2_/_R1_/"`
        mv $r1 $r2
        mv $r2.fixed $r1
      done

      ## now remove all of the ungzipped fastqs 
      rm `find $RUN/* | grep "fastq$"`
    fi 
  fi
}

function main () {
  local PARSED=$1
  local CPUS=16
  local RUN=`grep -w "BAM$" $PARSED | cut -f1 | head -$LSB_JOBINDEX | tail -1`
  local SIF="/nfs/cellgeni/singularity/images/reprocess_10x.sif"
  local CMD="singularity run --bind /nfs,/lustre $SIF"

  bam2fastq $RUN $CPUS $CMD
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi