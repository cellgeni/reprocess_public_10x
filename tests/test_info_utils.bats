#!/usr/bin/env bats

setup() {
    source lib/info.sh
}

@test "Download GEO soft family file with valid GSE" {
    run download_geo_family "GSE160513"
    [ "$status" -eq 0 ]
    [ -f "GSE160513_family.soft" ]
}

@test "extract bioproject from GEO soft family file" {
    run download_geo_family "GSE160513"
    [ "$status" -eq 0 ]
    [ -f "GSE160513_family.soft" ]
    run bioproject_from_geofamily "GSE160513_family.soft"
    [ "$status" -eq 0 ]
    [[ "$output" == "PRJNA673418|5" ]]
}

@test "extract bioproject from GSE using eutils" {
    run bioproject_from_gse "GSE160513"
    [ "$status" -eq 0 ]
    [[ "$output" == "PRJNA673418|5" ]]
}