#!/bin/bash 

SERIES=$1
SUBSET=$2

## this would get increasingly complicated when we support more databases 
## for now its 3 main ones: GEO, ArrayExpress, and naked SRA/ENA project ID
## got rid of ffq in this version, this works faster and more to the point (but is more ENA-dependent)

if (( $# != 1 && $# != 2 ))
then
  >&2 echo "USAGE: ./collect_metadata.sh <series_id> [sample_list]"
  >&2 echo
  >&2 echo "(requires curl_ena_metadata.sh and parse_ena_metadata.sh present in the same directory)" 
  exit 1
fi

if [[ $SERIES == GSE* ]]
then
  ## download the so-called soft_family file, and use it to generate same files as above
  PAD=`echo $SERIES | perl -ne 's/\d{3}$/nnn/; print'`
  wget -O ${SERIES}_family.soft.gz https://ftp.ncbi.nlm.nih.gov/geo/series/$PAD/$SERIES/soft/${SERIES}_family.soft.gz
  ## -f overwrites the old stuff
  gzip -fd ${SERIES}_family.soft.gz
  if [[ ! -s ${SERIES}_family.soft ]]
  then
    >&2 echo "ERROR: Failed to download ${SERIES}_family.soft file; please make sure the series you requested exists, or fix the download URL!"
    exit 1
  fi

  ## samples here are GSM IDs; usually for a 10x GSM==SRS==SRX, but I haven't checked *all* of the SRA you know 
  grep Sample_geo_accession ${SERIES}_family.soft | awk '{print $3}' | sort | uniq > $SERIES.sample.list
  grep Series_relation ${SERIES}_family.soft | perl -ne 'print "$1\n" if (m/(PRJ[A-Z]+\d+)/)' | sort | uniq > $SERIES.project.list
 
  ## first variable is used to spot dbGap and other problematic datasets;
  ## second variable is used to find SubSeries when SuperSeries does not produce any meaningful ENA links
  EXPIDS=`grep Series_relation ${SERIES}_family.soft | grep -v PRJ | wc -l`
  SUBGSE=`grep Series_relation ${SERIES}_family.soft | grep SuperSeries | perl -ne 'print "$1\n" if (m/(GSE\d+)/)'` 
  
  ## few sanity checks:
  if [[ `cat $SERIES.project.list | wc -l` != "1" ]]
  then 
    >&2 echo "WARNING: more than 1 project associated with series $SERIES! This shouldn't normally happen, do take a look."
  fi 

  if [[ $EXPIDS == "0" ]]
  then
    >&2 echo "WARNING: No secondary run/experiment (SRP/SRX) IDs in the family.soft file; this often happens in datasets that are restricted access (dbGap, etc)."
  fi

  ## curl info about each run (SRR/ERR/DRR) from ENA API; v2 pulls GSM data etc 
  RET=1
  TRIES=1
  until (( $RET == 0 )) 
  do
    ./curl_ena_metadata.sh $SERIES.project.list > $SERIES.ena.tsv 
    RET=$?

    ## this either pulls sub-series data (and replaces $SERIES.project.list with useful PRJNA* IDs), or just quits after 5 tries
    TRIES=$((TRIES+1))
    if (( $TRIES > 5 )) 
    then
      >&2 echo "WARNING: No ENA records can be retrieved for GEO projects listed in $SERIES.project.list!"
      if [[ $SUBGSE == "" ]]
      then 
        >&2 echo "ERROR: No GSE subseries were listed in ${SERIES}_family.soft - no alternative PRJNA* to be found, and no ENA entries can be retrieved!"
        exit 1
      else 
        >&2 echo "WARNING: replacing $SERIES.project.list with sub-series projects.."
        rm $SERIES.project.list 
        for i in $SUBGSE
        do
          PAD=`echo $i | perl -ne 's/\d{3}$/nnn/; print'`
          wget -O ${i}_family.soft.gz https://ftp.ncbi.nlm.nih.gov/geo/series/$PAD/$i/soft/${i}_family.soft.gz
          gzip -fd ${i}_family.soft.gz
          grep Series_relation ${i}_family.soft | perl -ne 'print "$1\n" if (m/(PRJ[A-Z]+\d+)/)' | sort | uniq >> $SERIES.project.list
        done
           
        ## now, once we re-populated $SERIES.project.list, let's try to get ENA records for the new IDs.. 
        >&2 echo "WARNING: pulling ENA records using sub-series project identifiers.."
        RET=1
        TRIES=1
        until (( $RET == 0 ))
        do
          ./curl_ena_metadata.sh $SERIES.project.list > $SERIES.ena.tsv
          RET=$?
          TRIES=$((TRIES+1))
          if (( $TRIES > 5 ))
          then
            >&2 echo "ERROR: Still no ENA records can be retrieved for the GEO SUBSERIES projects listed in $SERIES.project.list, I quit!"
            exit 1
          fi
        done
      fi
    fi 
    sleep 1
  done

  ## make an accession table. If you adjust the ENA curl query, column numbers will change, so beware
  if [[ -s $SERIES.accessions.tsv ]] 
  then 
    >&2 echo "WARNING: file $SERIES.accessions.tsv exists. This shouldn't normally happen. Overwriting the file by parsing $SERIES.ena.tsv.."
    rm $SERIES.accessions.tsv
  fi 

  for i in `cat $SERIES.sample.list`
  do
		## changed this because ENA web API is inconsistent with column order..
    SMPS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RS\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    EXPS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RX\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    RUNS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RR\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    echo -e "$i\t$SMPS\t$EXPS\t$RUNS" >> $SERIES.accessions.tsv
  done

  ## make few more useful metadata files
  cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > $SERIES.run.list                               
  cut -f 1,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
elif [[ $SERIES == E-MTAB* ]]
then
  ## sdrf's are wonderful, but don't have the project ID, which is *annoying*. That's OK though, we'll go by SRS. 
  wget -O $SERIES.sdrf.txt https://www.ebi.ac.uk/biostudies/files/$SERIES/$SERIES.sdrf.txt
  wget -O $SERIES.idf.txt https://www.ebi.ac.uk/biostudies/files/$SERIES/$SERIES.idf.txt
  if [[ ! -s $SERIES.sdrf.txt ]] 
  then
    >&2 echo "ERROR: Failed to download $SERIES.sdrf.txt file; please make sure the series you requested exists, or fix the download URL!"
    exit 1
  fi 

  ## samples are ERS in case of ArrayExpress. Why not ERX, you might ask? Yes, ask you might.   
  cat $SERIES.sdrf.txt | tr '\t' '\n' | grep "^ERS" | sort | uniq > $SERIES.sample.list

  ## curl info about each run (SRR/ERR/DRR) from ENA API; in this case we use ERS IDs 
  RET=1
  TRIES=1
  until (( $RET == 0 )) 
  do
    ## for ArrayExpress, we query by sample ID because sdrf doesn't list the BioProject ID
    ./curl_ena_metadata.sh $SERIES.sample.list > $SERIES.ena.tsv 
    RET=$?
    TRIES=$((TRIES+1))
    if (( $TRIES > 5 )) 
    then
      >&2 echo "ERROR: No ENA records can be retrieved for ArrayExpress samples $SERIES.sample.list!"
      exit 1
    fi 
    sleep 1
  done

  ## make an accession table. If you adjust the ENA curl query, column numbers will change, so beware
  if [[ -s $SERIES.accessions.tsv ]] 
  then 
    >&2 echo "WARNING: file $SERIES.accessions.tsv exists. This shouldn't normally happen. Overwriting the file by parsing $SERIES.ena.tsv.."
    rm $SERIES.accessions.tsv
  fi 
  
  for i in `cat $SERIES.sample.list`
  do
    EXPS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RX\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    RUNS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RR\d+$" | uniq | tr '\n' ',' | sed "s/,$//"`
    echo -e "-\t$i\t$EXPS\t$RUNS" >> $SERIES.accessions.tsv
  done

  ## make few more useful metadata files
  cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > $SERIES.run.list                               
  cut -f 2,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
elif [[ $SERIES == PRJ* ]] 
then
  ## simple version of GEO processing (see above): pull all the needed metadata from ENA using PRJ*
  echo $SERIES > $SERIES.project.list

  ## curl info about each run (SRR/ERR/DRR) from ENA API; v2 pulls GSM data etc 
  RET=1
  TRIES=1
  until (( $RET == 0 )) 
  do
    ./curl_ena_metadata.sh $SERIES.project.list > $SERIES.ena.tsv 
    RET=$?
    TRIES=$((TRIES+1))
    if (( $TRIES > 5 )) 
    then
      >&2 echo "ERROR: No ENA records can be retrieved for BioProject(s) $SERIES.project.list!"
      exit 1
    fi 
    sleep 1
  done

  ## make an accession table. If you adjust the ENA curl query, column numbers will change, so beware
  if [[ -s $SERIES.accessions.tsv ]] 
  then 
    >&2 echo "WARNING: file $SERIES.accessions.tsv exists. This shouldn't normally happen. Overwriting the file by parsing $SERIES.ena.tsv.."
    rm $SERIES.accessions.tsv
  fi 

  ## for PRJ*, samples are SRS or ERS IDs: 
  cat $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RS\d+$" | sort | uniq > $SERIES.sample.list 

  for i in `cat $SERIES.sample.list`
  do
    EXPS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RX\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    RUNS=`grep $i $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RR\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
    echo -e "-\t$i\t$EXPS\t$RUNS" >> $SERIES.accessions.tsv
  done

  ## make few more useful metadata files
  cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > $SERIES.run.list                               
  cut -f 2,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
else 
  >&2 echo "ERROR: The series ID *must* start with GSE, E-MTAB, or PRJ!"
  exit 1
fi 

## if we only want a fraction of samples, make sure we subset all the relevant files
if [[ $SUBSET != "" ]]
then
  >&2 echo "Narrowing down the dataset using the file $SUBSET"
  >&2 echo "New list of the samples to be processed:"
  >&2 cat $SUBSET 
  grep -f $SUBSET $SERIES.sample.list > $SERIES.sample.list.tmp
  mv $SERIES.sample.list.tmp $SERIES.sample.list
  grep -f $SUBSET $SERIES.ena.tsv > $SERIES.ena.tsv.tmp 
  mv $SERIES.ena.tsv.tmp $SERIES.ena.tsv 
  grep -f $SUBSET $SERIES.accessions.tsv > $SERIES.accessions.tsv.tmp 
  mv $SERIES.accessions.tsv.tmp $SERIES.accessions.tsv

  cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > $SERIES.run.list                               
  ## for GSE, sample=GSM; for E-MTAB/PRJ, sample=ERS/SRS
  if [[ $SERIES == GSE* ]]
  then
    cut -f 1,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
  else 
    cut -f 2,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
  fi
fi

## finally, classify each run into 3 major types: 
## 1) we have useable 10x paired-end files; 2) we need to get them from 10x BAM; 3) we need to get them from SRA
## simultaneously, '$SERIES.urls.list' is generated listing all things that need to be downloaded 
./parse_ena_metadata.sh $SERIES > $SERIES.parsed.tsv
