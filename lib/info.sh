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
            BIO_SERIES=bioproject_from_gse "$GEO_SERIES"
            AE_SERIES=ae_from_bioproject "$BIO_SERIES"
            ;;
        E-MTAB*)
            AE_SERIES="$SERIES"
            BIO_SERIES=bioproject_from_ae "$AE_SERIES"
            GEO_SERIES=gse_from_bioproject "$BIO_SERIES"
        ;;
        PRJ*)
            BIO_SERIES="$SERIES"
            AE_SERIES=ae_from_bioproject "$BIO_SERIES"
            GEO_SERIES=gse_from_bioproject "$BIO_SERIES"
            ;;
        *)
            echo "Error: Unrecognized series ID '$SERIES'. Must start with GSE, E-MTAB, or PRJ." >&2
            exit 1 
            ;;
    esac

    # Get metadata for all available series types (some may be empty if not applicable)
    geo_sra_metadata "$GEO_SERIES"
    ae_sra_metadata "$AE_SERIES"

    # Check if tables have the same samples and subset if necessary
    validate_and_subset_metadata "$GEO_SERIES" "$AE_SERIES" "$SUBSET"

    # Get links to raw data files for all samples in the series
    get_raw_data_links "$GEO_SERIES" "$AE_SERIES"

    # Make other necessary files for downstream processing (e.g. sample sheet)
    prepare_downstream_files "$GEO_SERIES" "$AE_SERIES"
}