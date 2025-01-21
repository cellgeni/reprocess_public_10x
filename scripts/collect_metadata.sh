#!/bin/bash 

set -uo pipefail

function download_geo_family() {
  local SERIES=$1

  ## download the so-called soft_family file, and use it to generate same files as above
  local PAD=`echo $SERIES | perl -ne 's/\d{3}$/nnn/; print'`
  wget -O ${SERIES}_family.soft.gz https://ftp.ncbi.nlm.nih.gov/geo/series/$PAD/$SERIES/soft/${SERIES}_family.soft.gz
  ## -f overwrites the old stuff
  gzip -fd ${SERIES}_family.soft.gz
  if [[ ! -s ${SERIES}_family.soft ]]
  then
    >&2 echo "ERROR: Failed to download ${SERIES}_family.soft file; please make sure the series you requested exists, or fix the download URL!"
    exit 1
  fi
}

function download_sdrf_idf_files() {
  local SERIES=$1

  wget -O $SERIES.sdrf.txt https://www.ebi.ac.uk/biostudies/files/$SERIES/$SERIES.sdrf.txt
  wget -O $SERIES.idf.txt https://www.ebi.ac.uk/biostudies/files/$SERIES/$SERIES.idf.txt
  
  if [[ ! -s $SERIES.sdrf.txt ]] 
  then
    >&2 echo "ERROR: Failed to download $SERIES.sdrf.txt file; please make sure the series you requested exists, or fix the download URL!"
    exit 1
  fi
}

function parse_geo_family() {
  local SERIES=$1

  ## get bioproject ID
  grep Series_relation ${SERIES}_family.soft | perl -ne 'print "$1\n" if (m/(PRJ[A-Z]+\d+)/)' | sort | uniq  > $SERIES.project.list
  
  ## get sample IDs; samples here are GSM IDs; usually for a 10x GSM==SRS==SRX, but I haven't checked *all* of the SRA you know 
  awk '
	BEGIN {OFS="\t"}
	# get all IDs
  /\^SAMPLE/ { sample=gensub(/.*(GSM[0-9]+)/, "\\1", "g", $0) }
  /Sample_geo_accession/ { geo=gensub(/.*(GSM[0-9]+)/, "\\1", "g", $0) }
  /Sample_relation = SRA:/ { sra=gensub(/.*(SRX[0-9]+)/, "\\1", "g", $0) }
  /Sample_relation = BioSample:/ { biosample=gensub(/.*(SAMN[0-9]+)/, "\\1", "g", $0) }
  
  # When all three pieces of information are found, print them as a tab-separated line
  sample && geo && sra && biosample {
    print sample,geo,sra,biosample
    sample="";  geo=""; sra=""; biosample=""
  }
  ' ${SERIES}_family.soft > $SERIES.sample.relation.list
  cut -f 2 ${SERIES}.sample.relation.list > $SERIES.sample.list
  cut -f 4 ${SERIES}.sample.relation.list > $SERIES.biosample.list

  ## first variable is used to spot dbGap and other problematic datasets;
  local EXPIDS=`grep Series_relation ${SERIES}_family.soft | grep -v PRJ | wc -l` 
  
  ## few sanity checks:
  if [[ `cat $SERIES.project.list | wc -l` -gt 1 ]]
  then 
    >&2 echo "WARNING: more than 1 project associated with series $SERIES! This shouldn't normally happen, do take a look."
  fi 

  if [[ $EXPIDS == "0" ]]
  then
    >&2 echo "WARNING: No secondary run/experiment (SRP/SRX) IDs in the family.soft file; this often happens in datasets that are restricted access (dbGap, etc)."
  fi
}

function parse_sdrf_idf() {
  local SERIES=$1

  ## samples are ERS in case of ArrayExpress. Why not ERX, you might ask? Yes, ask you might.   
  cat $SERIES.sdrf.txt | tr '\t' '\n' | grep "^ERS" | sort | uniq > $SERIES.sample.list
}

function get_subseries_from_family {
  local SERIES=$1
  local OUTPUT_FILE=$2
  local SUBGSE=`grep Series_relation ${SERIES}_family.soft | grep SuperSeries | perl -ne 'print "$1\n" if (m/(GSE\d+)/)'`
  
  ## delete output file if it exists
  if [[ -f $OUTPUT_FILE ]]
  then
    rm $OUTPUT_FILE
  fi

  ## pulls sub-series data
  if [[ $SUBGSE == "" ]]
  then
    >&2 echo "ERROR: No GSE subseries were listed in ${SERIES}_family.soft file!"
    return 1
  else
    for i in $SUBGSE
    do
      local PAD=`echo $i | perl -ne 's/\d{3}$/nnn/; print'`
      wget -O ${i}_family.soft.gz https://ftp.ncbi.nlm.nih.gov/geo/series/$PAD/$i/soft/${i}_family.soft.gz
      gzip -fd ${i}_family.soft.gz
      grep Series_relation ${i}_family.soft | perl -ne 'print "$1\n" if (m/(PRJ[A-Z]+\d+)/)' | sort | uniq >> $OUTPUT_FILE
    done
  fi
  return 1
}

function download_metadata {
  local SERIES=$1
  local SCRIPT=$2
  local DOWNLOAD_LIST=$3
  local OUTPUT_FILE=$4

  local STATUS=1
  local TRIES=1

  if [[ ! -s $DOWNLOAD_LIST ]]
  then
    >&2 echo "ERROR: No download list $DOWNLOAD_LIST found!"
    return 1
  fi


  while [[ ! $STATUS -eq 0 && TRIES -le 5 ]]
  do
    $SCRIPT $DOWNLOAD_LIST > $OUTPUT_FILE
    STATUS=$?
    TRIES=$((TRIES+1))
    sleep 1
  done

  if [[ ! -s $OUTPUT_FILE ]]
  then
    >&2 echo "ERROR: Failed to download metadata for $SERIES using $SCRIPT and $DOWNLOAD_LIST!"
    return 1
  else
    return $STATUS
  fi
}

function write_accessions() {
  local SERIES=$1
  local SAMPLE=$2
  local SMPS=$3
  local EXPS=$4
  local RUNS=$5

  ## check that we have all the IDs
  if [[ $EXPS == "" || $RUNS == "" ]]
  then
    return 1
  fi

  # write the accessions to the accessions file
  if [[ $SERIES == GSE* ]]
  then
    echo -e "$SAMPLE\t$SMPS\t$EXPS\t$RUNS" >> $SERIES.accessions.tsv
  else
    echo -e "-\t$SAMPLE\t$EXPS\t$RUNS" >> $SERIES.accessions.tsv
  fi
  return 0
}

function get_sample_ids() {
  local SERIES=$1
  local META=$2
  local STATUS=1

  ## delete accessions file if exists
  if [[ -s $SERIES.accessions.tsv ]] 
  then
    rm $SERIES.accessions.tsv
  fi

  ## get sample, experiment, and run IDs for each sample from metadata file
  if [[ -s $META ]]
  then
    for i in `cat $SERIES.sample.list`
    do
      ## get BioSample ID if possible
      if [[ -s $SERIES.sample.relation.list ]]
      then
        local biosample=`grep $i $SERIES.sample.relation.list | cut -f 4 | tr -d '\n'`
      else
        local biosample=$i
      fi
      
      ## try to get sample, experiment, and run IDs from metadata file using GSM
      if [[ `grep $i $META` ]]
      then
        SMPS=`grep $i $META | tr '\t' '\n' | grep -P "^[SE]RS\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        EXPS=`grep $i $META | tr '\t' '\n' | grep -P "^[SE]RX\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        RUNS=`grep $i $META | tr '\t' '\n' | grep -P "^[SE]RR\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        write_accessions $SERIES $i $SMPS $EXPS $RUNS
        STATUS=$?
      ## try to get sample, experiment, and run IDs from metadata file using BioSample
      elif [[ `grep $biosample $META` ]]
      then
        SMPS=`grep $biosample $META | tr '\t' '\n' | grep -P "^[SE]RS\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        EXPS=`grep $biosample $META | tr '\t' '\n' | grep -P "^[SE]RX\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        RUNS=`grep $biosample $META | tr '\t' '\n' | grep -P "^[SE]RR\d+$" | sort | uniq | tr '\n' ',' | sed "s/,$//"`
        write_accessions $SERIES $i $SMPS $EXPS $RUNS
        STATUS=$?
      else
        >&2 echo "ERROR: No experiment or run ID found for $i in $META!"
        STATUS=1
        break
      fi

      ## check that we have all the IDs
      if [[ $STATUS -eq 1 ]]
      then
        >&2 echo "WARNING: No experiment or run ID found for $i in $META!"
        break
      fi
    done

    ## check that all samples are in accessions file and change status to 0
    if [[ `cat $SERIES.sample.list | wc -l` -eq `cut -f 1 $SERIES.accessions.tsv | wc -l` ]]
    then
      STATUS=0
    fi
  else
    >&2 echo "ERROR: No metadata file $META found!"
  fi
  return $STATUS
}

subset_accessions() {
  local SERIES=$1
  local SUBSET=${2:-""}

  if [[ $SUBSET != "" ]]
  then
    >&2 echo "Narrowing down the dataset using the file $SUBSET"
    >&2 echo "New list of the samples to be processed:"
    >&2 cat $SUBSET 
    grep -f $SUBSET $SERIES.sample.list > $SERIES.sample.list.tmp
    mv $SERIES.sample.list.tmp $SERIES.sample.list
    grep -f $SUBSET $SERIES.accessions.tsv > $SERIES.accessions.tsv.tmp
    mv $SERIES.accessions.tsv.tmp $SERIES.accessions.tsv
  fi
}

subset_meta() {
  local META=$1
  local SUBSET=${2:-""}

  if [[ $SUBSET != "" ]]
  then
    grep -f $SUBSET $META > $META.tmp 
    mv $META.tmp $META
  fi
}

function make_run_relation_files() {
  local SERIES=$1

  ## make run list
  cut -f 4 $SERIES.accessions.tsv | tr ',' '\n' | sort | uniq > $SERIES.run.list
  
  ## make sample x run file
  if [[ $SERIES == GSE* ]]
  then
    cut -f 1,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
  else
    cut -f 2,4 $SERIES.accessions.tsv > $SERIES.sample_x_run.tsv
  fi                            
}

function make_util_files() {
  local SERIES=$1
  local SUBSET=${2:-""}
  local STATUS=1

  if [[ -s $SERIES.accessions.tsv ]] 
  then 
    >&2 echo "WARNING: file $SERIES.accessions.tsv exists. This shouldn't normally happen. Overwriting the file.."
    rm $SERIES.accessions.tsv
  fi

  
  ## get sample, experiment, and run IDs for each sample from SRA metadata file
  if [[ $SERIES == GSE* ]]
  then
    get_sample_ids $SERIES $SERIES.sra.tsv
    STATUS=$?
  fi

  ## get sample, experiment, and run IDs for each sample from ENA metadata file
  if [[ $STATUS -eq 1 ]]
  then
    get_sample_ids $SERIES $SERIES.ena.tsv
    STATUS=$?
  fi

  if [[ $STATUS -eq 1 ]]
  then
    >&2 echo "ERROR: Failed to get sample, experiment, and run IDs for $SERIES using any of the available metadata files!"
    exit 1
  fi

  ## subset the accessions file if a sample list is provided
  subset_accessions $SERIES $SUBSET

  ## make few more useful metadata files
  make_run_relation_files $SERIES

  ## finally, classify each run into 3 major types: 
  ## 1) we have useable 10x paired-end files; 2) we need to get them from 10x BAM; 3) we need to get them from SRA
  ## simultaneously, '$SERIES.urls.list' is generated listing all things that need to be downloaded 
  if [[ -s "$SERIES.ena.tsv" ]]
  then
    subset_meta $SERIES.ena.tsv $SUBSET
    ./parse_ena_metadata.sh $SERIES > $SERIES.parsed.tsv
  elif [[ -s "$SERIES.sra.tsv" ]]
  then
    subset_meta $SERIES.ena.tsv $SUBSET
    ./parse_sra_metadata.sh $SERIES > $SERIES.parsed.tsv
  else
    >&2 echo "ERROR: No metadata file found for $SERIES!"
    exit 1
  fi
}

function process_geo() {
  local SERIES=$1
  local SUBSET=${2:-""}
  local SRA_STATUS=1
  local ENA_STATUS=1

  ## download the family file from GEO
  download_geo_family $SERIES
  
  ## parse the family file to get the project and sample IDs
  parse_geo_family $SERIES

  ## Try loading metadata using $SERIES.project.list
  if [[ -s $SERIES.project.list ]]
  then
    ## download metadata from SRA
    download_metadata "$SERIES" "./curl_sra_metadata.sh" "$SERIES.project.list" "$SERIES.sra.tsv"
    SRA_STATUS=$?

    ## download metadata from ENA
    download_metadata "$SERIES" "./curl_ena_metadata.sh" "$SERIES.project.list" "$SERIES.ena.tsv"
    ENA_STATUS=$?
  fi


  ## if the download failed, try using suboroject IDs
  if [ $SRA_STATUS -eq 1 ] || [ $ENA_STATUS -eq 1 ]
  then
    >&2 echo "WARNING: replacing $SERIES.project.list with sub-series projects.."
    ## get subseries from family file
    get_subseries_from_family "$SERIES" "$SERIES.subproject.list"

    ## download metadata from SRA
    if [ $SRA_STATUS -eq 1 ]
    then
      download_metadata "$SERIES" "./curl_sra_metadata.sh" "$SERIES.subproject.list" "$SERIES.sra.tsv"
      SRA_STATUS=$?
    fi

    ## download metadata from ENA
    if [ $ENA_STATUS -eq 1 ]
    then
      download_metadata "$SERIES" "./curl_ena_metadata.sh" "$SERIES.subproject.list" "$SERIES.ena.tsv"
      ENA_STATUS=$?
    fi
  fi


## if the download using subproject IDs failed, try using BioSample IDs
  if [ $SRA_STATUS -eq 1 ] || [ $ENA_STATUS -eq 1 ]
  then
    >&2 echo "WARNING: replacing $SERIES.subproject.list with BioSample IDs.."

    ## download metadata from SRA
    if [ $SRA_STATUS -eq 1 ]
    then
      download_metadata "$SERIES" "./curl_sra_metadata.sh" "$SERIES.biosample.list" "$SERIES.sra.tsv"
      SRA_STATUS=$?
    fi

    ## download metadata from ENA
    if [ $ENA_STATUS -eq 1 ]
    then
      download_metadata "$SERIES" "./curl_ena_metadata.sh" "$SERIES.biosample.list" "$SERIES.ena.tsv"
      ENA_STATUS=$?
    fi
  fi

  ## if both downloads failed, exit with an error
  if [ $SRA_STATUS -eq 1 ] && [ $ENA_STATUS -eq 1 ]
  then
    >&2 echo "ERROR: Failed to download metadata for $SERIES using any of the available methods!"
    exit 1
  fi

  ## make utility files
  make_util_files $SERIES $SUBSET
}

function process_arrayexpress {
  local SERIES=$1
  local SUBSET=${2:-""}

  ## download the SDRF and IDF files from ArrayExpress
  download_sdrf_idf_files $SERIES
  
  ## parse the SDRF file to get the project and sample IDs
  parse_sdrf_idf $SERIES

  ## download metadata from ENA
  download_metadata "$SERIES" "./curl_ena_metadata.sh" "$SERIES.sample.list" "$SERIES.ena.tsv"
  local ENA_STATUS=$?

  ## if failed, exit with an error
  if [ $ENA_STATUS -eq 1 ]
  then
    >&2 echo "ERROR: Failed to download metadata for $SERIES using any of the available methods!"
    exit 1
  fi

  ## make utility files
  make_util_files $SERIES $SUBSET
}

function process_bioproject {
  local SERIES=$1
  local SUBSET=${2:-""}
  
  ## simple version of GEO processing (see above): pull all the needed metadata from ENA using PRJ*
  echo $SERIES > $SERIES.project.list

  ## download metadata from ENA
  download_metadata "$SERIES" "./curl_ena_metadata.sh" "$SERIES.project.list" "$SERIES.ena.tsv"
  local ENA_STATUS=$?

  ## if failed, exit with an error
  if [ $ENA_STATUS -eq 1 ]
  then
    >&2 echo "ERROR: Failed to download metadata for $SERIES using any of the available methods!"
    exit 1
  fi

  ## create sample list
  cat $SERIES.ena.tsv | tr '\t' '\n' | grep -P "^[SE]RS\d+$" | sort | uniq > $SERIES.sample.list 

  ## make utility files
  make_util_files $SERIES $SUBSET
}

function main () {
  if (( $# != 1 && $# != 2 ))
  then
    >&2 echo "USAGE: ./collect_metadata.sh <series_id> [sample_list]"
    >&2 echo
    >&2 echo "(requires curl_ena_metadata.sh and parse_ena_metadata.sh present in the same directory)" 
    exit 1
  fi

  local SERIES=$1
  local SUBSET=${2:-""}

  # Handle different series types
  case "$SERIES" in
    GSE*)  process_geo "$SERIES" "$SUBSET" ;;
    E-MTAB*) process_arrayexpress "$SERIES" "$SUBSET" ;;
    PRJ*)  process_bioproject "$SERIES" "$SUBSET" ;;
    *) echo "ERROR: The series ID must start with GSE, E-MTAB, or PRJ!" >&2; exit 1 ;;
  esac
}

main "$@"
