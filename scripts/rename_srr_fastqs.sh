#!/bin/bash 


KK=`ls *_1.fastq`
if [[ $KK == "" ]]
then
  echo "ERROR: No files of format SRR*_1.fastq have been found!"
  exit 1
fi

for i in $KK
do
  TAG=${i%%_1.fastq}
  echo "Processing sample $TAG.." 
  R1LEN=`head -n400 ${TAG}_1.fastq | awk 'NR%4==2' | awk '{sum+=length($0)} END {printf "%d\n",sum/NR+0.5}'`
  R2LEN=`head -n400 ${TAG}_2.fastq | awk 'NR%4==2' | awk '{sum+=length($0)} END {printf "%d\n",sum/NR+0.5}'`
  R3LEN=`head -n400 ${TAG}_3.fastq | awk 'NR%4==2' | awk '{sum+=length($0)} END {printf "%d\n",sum/NR+0.5}'`
  echo "Read lengths for sample $TAG: 1 - $R1LEN bp, 2 - $R2LEN bp, 3 - $R3LEN bp.."
  
  ## !!! in every move command, have to make sure you don't overwrite necessary files!

  ## case 1: read 1 = 8 bp index
  if (( $R1LEN == 8 ))
    then
    if (( $R2LEN >= 24 && $R2LEN <= 28 && $R3LEN > 40 )) 
    then
      echo "Deleting: _1, moving: _2 => _1 (index), _3 => _2 (biological)"
      rm ${TAG}_1.fastq
      mv ${TAG}_2.fastq ${TAG}_1.fastq
      mv ${TAG}_3.fastq ${TAG}_2.fastq
    elif (( $R3LEN >= 24 && $R3LEN <= 28 && $R2LEN > 40 ))
    then
      echo "Deleting: _1, moving: _3 => _1 (index), _2 => _2 (biological)"
      rm ${TAG}_1.fastq
      mv ${TAG}_3.fastq ${TAG}_1.fastq
    fi
  fi

  ## case 2: read 2 = 8 bp index
  if (( $R2LEN == 8 ))
    then
    if (( $R1LEN >= 24 && $R1LEN <= 28 && $R3LEN > 40 )) 
    then
      echo "Deleting: _2, moving: _1 => _1 (index), _3 => _2 (biological)"
      rm ${TAG}_2.fastq
      mv ${TAG}_3.fastq ${TAG}_2.fastq
    elif (( $R3LEN >= 24 && $R3LEN <= 28 && $R1LEN > 40 ))
    then
      echo "Deleting: _2, moving: _3 => _1 (index), _1 => _2 (biological)"
      rm ${TAG}_2.fastq
      mv ${TAG}_1.fastq ${TAG}_2.fastq
      mv ${TAG}_3.fastq ${TAG}_1.fastq
    fi
  fi

  ## case 1: read 3 = 8 bp index
  if (( $R3LEN == 8 ))
    then
    if (( $R2LEN >= 24 && $R2LEN <= 28 && $R1LEN > 40 )) 
    then
      echo "Deleting: _3, moving: _2 => _1 (index), _1 => _2 (biological)"
      mv ${TAG}_1.fastq ${TAG}_3.fastq
      mv ${TAG}_2.fastq ${TAG}_1.fastq
      mv ${TAG}_3.fastq ${TAG}_2.fastq
    elif (( $R1LEN >= 24 && $R1LEN <= 28 && $R2LEN > 40 ))
    then
      echo "Deleting: _3, moving (not): _1 => _1 (index), _2 => _2 (biological)"
      rm ${TAG}_3.fastq
    fi
  fi
  echo
done
