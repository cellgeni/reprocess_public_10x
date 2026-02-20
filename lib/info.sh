#!/bin/bash
# =============================================================================
# reprocess CLI - Info subcommand
# =============================================================================
# Decription:
# TOBEDONE
# =============================================================================

# ---------- Subcommand help -------------------------------------------------

show_info_help() {
    cat <<'EOF'
Usage: reprocess info <series> [options]

Description:
  Get dataset metadata and links to raw data files for a given the series:
    - GSE (GEO series)
    - E-MTAB (ArrayExpress series)
    - PRJ* (BioProject/SRA)

Required:
  <series>                  Series ID (GSE, E-MTAB, or PRJ*).

Options:
  --subset <path>     Path to file with list of sample IDs (GSM, SRS, or ERS) to subset the series to
  -h, --help          Show this help
EOF
}

# ---------- Helpers ---------------------------------------------------------

function download_geo_family() {
    local GSE=$1

    ## download the so-called soft_family file, and use it to generate same files as above
    local PAD=`echo $GSE | perl -ne 's/\d{3}$/nnn/; print'`
    wget -q -t 5 -O ${GSE}_family.soft.gz https://ftp.ncbi.nlm.nih.gov/geo/series/$PAD/$GSE/soft/${GSE}_family.soft.gz
    ## -f overwrites the old stuff
    gzip -fd ${GSE}_family.soft.gz
    if [[ ! -s ${GSE}_family.soft ]]
    then
        >&2 echo "ERROR: Failed to download ${GSE}_family.soft file; please make sure the series you requested exists, or fix the download URL!"
        return 1
    fi
    echo "${GSE}_family.soft"
}

function bioproject_from_geofamily() {
    local SOFT=$1
    # get bioproject series from the soft file
    BIO=$(grep Series_relation ${SOFT} | perl -ne 'print "$1\n" if (m/(PRJ[A-Z]+\d+)/)' | sort | uniq)
    if [[ -z "$BIO" ]]
    then
        >&2 echo "ERROR: Failed to extract BioProject ID from ${SOFT} file; the file may be malformed or the series may not be associated with a BioProject!"
        return 1
    fi

    # Calculate the number of samples
    local N_SAMPLES=$(grep -c "^\!Series_sample_id" ${SOFT})
    echo "${BIO}|${N_SAMPLES}"
}

function etools_bioproject_from_gse() {
    local GSE=$1
    local DB="gds"
    local query="${GSE}[ACCN]+GSE[ETYP]"
    local ESEARCH_BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?"
    local ESUMMARY_BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?"
    # Perform esearch to get WebEnv and QueryKey for the given query
    curl -s --globoff "${ESEARCH_BASE}db=${DB}&term=${query}&retmode=json&usehistory=y" | jq . > esearch.json
    local WEBENV=$(jq -r '.esearchresult.webenv' "esearch.json")
    local QKEY=$(jq -r '.esearchresult.querykey' "esearch.json")
    
    # Check that esearch returned results
    local COUNT=$(jq -r '.esearchresult.count' "esearch.json")
    rm esearch.json
    if [[ "$COUNT" -eq 0 ]]
    then
        >&2 echo "ERROR: No records found for query '$query'. Please check that the series ID is correct and try again!"
        return 1
    fi

    # Perform esummary to get the BioProject ID and check for errors
    sleep 0.34
    curl -s "${ESUMMARY_BASE}db=gds&query_key=${QKEY}&WebEnv=${WEBENV}&retmode=json" | jq . > esummary.json
    
    # Check that exactly one record was returned
    local N_UIDS=$(jq -r '.result.uids | length' "esummary.json")
    if [[ $N_UIDS -eq 0 || ! -s esummary.json ]]
    then
        >&2 echo "ERROR: No records found for query '$query'. Please check that the series ID is correct and try again!"
        rm esummary.json
        return 1
    elif [[ $N_UIDS -gt 1 ]]
    then
        >&2 echo "ERROR: Multiple records found for query '$query'. This is unexpected and may indicate an issue with the NCBI database or the query. Please investigate the esearch and esummary outputs for more details!"
        rm esummary.json
        return 1
    fi

    # Extract the BioProject ID from the esummary output
    local GEOID=$(jq -r '.result.uids[0]' "esummary.json")
    local BIO=$(jq -r ".result[\"$GEOID\"].bioproject" "esummary.json")
    local N_SAMPLES=$(jq -r ".result[\"$GEOID\"].n_samples" "esummary.json")
    rm esummary.json
    if [[ -z "$BIO" ]]
    then
        >&2 echo "ERROR: Failed to extract BioProject ID from esummary output. The record may be malformed or not associated with a BioProject. Please investigate the esummary output for more details!"
        rm esummary.json
        return 1
    fi
    echo "${BIO}|${N_SAMPLES}"
}

function bioproject_from_gse() {
    local GSE=$1
    # First try the NCBI eutils method, which is more robust and less likely to break than parsing the soft file
    local BIO="" N_SAMPLES=""
    IFS='|' read -r BIO N_SAMPLES <<< "$(etools_bioproject_from_gse "$GSE" || true)"
    if [[ -z "$BIO" ]]; then
        # If that fails, fall back to parsing the soft file (which is more brittle but may work for older series)
        local SOFT=$(download_geo_family "$GSE" || true)
        if [[ -z "$SOFT" ]]; then
            >&2 echo "ERROR: Failed to retrieve BioProject ID for GSE series '$GSE' using both eutils and soft file parsing methods."
            return 1
        fi
        IFS='|' read -r BIO N_SAMPLES <<< "$(bioproject_from_geofamily "$SOFT" || true)"
        if [[ -z "$BIO" ]]; then
            >&2 echo "ERROR: Failed to retrieve BioProject ID for GSE series '$GSE' using both methods."
            return 1
        fi
    fi
    
    # Check N_SAMPLES
    if [[ -z "$N_SAMPLES" || ! "$N_SAMPLES" =~ ^[0-9]+$ ]]
    then
        >&2 echo "WARNING: Failed to extract valid sample count"
        N_SAMPLES=""
    fi
    echo "${BIO}|${N_SAMPLES}"
}

function gse_from_bioproject() {
    local BIO=$1
    local DB="gds"
    local query="${BIO}[ALL]+GSE[ETYP]"
    local ESEARCH_BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?"
    local ESUMMARY_BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?"
    # Perform esearch to get WebEnv and QueryKey for the given query
    curl -s --globoff "${ESEARCH_BASE}db=${DB}&term=${query}&retmode=json&usehistory=y" | jq . > esearch.json
    local WEBENV=$(jq -r '.esearchresult.webenv' "esearch.json")
    local QKEY=$(jq -r '.esearchresult.querykey' "esearch.json")
    
    # Check that esearch returned results
    local COUNT=$(jq -r '.esearchresult.count' "esearch.json")
    if [[ "$COUNT" -eq 0 ]]
    then
        >&2 echo "ERROR: No records found for query '$query'. Please check that the BioProject ID is correct and try again!"
        return 1
    fi

    # Perform esummary to get the GSE ID and check for errors (wait a bit to avoid hitting NCBI rate limits)
    sleep 0.34
    curl -s "${ESUMMARY_BASE}db=gds&query_key=${QKEY}&WebEnv=${WEBENV}&retmode=json" | jq . > esummary.json
    
    # Check that at least one record was returned
    local N_UIDS=$(jq -r '.result.uids | length' "esummary.json")
    if [[ $N_UIDS -eq 0 || ! -s esummary.json ]]
    then
        >&2 echo "ERROR: No records found for query '$query'. Please check that the BioProject ID is correct and try again!"
        rm esummary.json
        return 1
    fi

    # Extract the GSE ID from the esummary output (if multiple records are returned, just take the first one)
    local GEOID=$(jq -r '.result.uids[0]' "esummary.json")
    local GSE=$(jq -r ".result[\"$GEOID\"].accession" "esummary.json")
    local N_SAMPLES=$(jq -r ".result[\"$GEOID\"].n_samples" "esummary.json")
    rm esummary.json
    if [[ -z "$GSE" ]]
    then
        >&2 echo "ERROR: Failed to extract GSE ID from esummary output. The record may be malformed or not associated with a GSE series. Please investigate the esummary output for more details!"
        return 1
    fi
    echo "${GSE}|${N_SAMPLES}"
}

# ---------- Main ------------------------------------------------------------

# Entrypoint called by bin/reprocess when 'info' subcommand is invoked. 
# Arguments are passed through from the CLI parser
# Path arguments must be absolute
info() {
    local SERIES=${1} OUTDIR=${2} SUBSET=${3:-}
    local GEO_SERIES="" AE_SERIES="" BIO_SERIES=""

    # Change to output directory
    cd "$OUTDIR"

    # Determine the type of series and extract corresponding IDs
    case "$SERIES" in
        GSE*) 
            GEO_SERIES="$SERIES"
            BIO_SERIES=$(bioproject_from_gse "$GEO_SERIES")
            ;;
        E-MTAB*)
            AE_SERIES="$SERIES"
            BIO_SERIES=$(bioproject_from_ae "$AE_SERIES")
            GEO_SERIES=$(gse_from_bioproject "$BIO_SERIES")
        ;;
        PRJ*)
            BIO_SERIES="$SERIES"
            GEO_SERIES=$(gse_from_bioproject "$BIO_SERIES")
            ;;
        *)
            echo "ERROR: Unrecognized series ID '$SERIES'. Must start with GSE, E-MTAB, or PRJ." >&2
            exit 1
            ;;
    esac

    echo "Identified series IDs:"
    echo "  BioProject: ${BIO_SERIES:-N/A}"
    echo "  GEO Series: ${GEO_SERIES:-N/A}"
    echo "  ArrayExpress Series: ${AE_SERIES:-N/A}"

    # Get metadata for all available series types (some may be empty if not applicable)
    #geo_sra_metadata "$GEO_SERIES"
    #ae_sra_metadata "$AE_SERIES"

    # Check if tables have the same samples and subset if necessary
    #validate_and_subset_metadata "$GEO_SERIES" "$AE_SERIES" "$SUBSET"

    # Get links to raw data files for all samples in the series
    #get_raw_data_links "$GEO_SERIES" "$AE_SERIES"

    # Make other necessary files for downstream processing (e.g. sample sheet)
    #prepare_downstream_files "$GEO_SERIES" "$AE_SERIES"
}