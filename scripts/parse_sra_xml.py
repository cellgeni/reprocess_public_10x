#!/usr/bin/env python3

import csv
import argparse
from typing import Dict
from xml.dom import minidom


KEYS = [
    "accession",
    "experiment",
    "sample",
    "allias",
    "primary_id",
    "geo_id",
    "geo_sample",
    "organism",
    "sra_lite_filename",
    "sra_lite_available",
    "sra_lite_url",
    "sra_normalized_filename",
    "sra_normalized_available",
    "sra_normalized_url",
    "bam_filename",
    "bam_available",
    "bam_url",
]


def init_parser() -> argparse.ArgumentParser:
    """
    Initialise argument parser for the script
    Returns:
        argparse.ArgumentParser: argument parser
    """
    parser = argparse.ArgumentParser(
        description="Reads GEO metadata from .xml file and writes it to .tsv"
    )
    parser.add_argument(
        "meta",
        metavar="<file>",
        type=str,
        help="specify a path to the .xml file with GEO metadata",
    )
    parser.add_argument(
        "--output",
        metavar="<file>",
        type=str,
        help="specify an output filename; default: sra.meta.tsv",
        default="sra.meta.tsv",
    )
    parser.add_argument(
        "--sep",
        metavar="<sep>",
        type=str,
        help="specify a separator for csv type file; default: \\t",
        default="\t",
    )
    return parser


def parse_run(run: minidom.Element) -> Dict[str, str]:
    """
    Parse run name
    Args:
        run (minidom.Element): run metadata

    Returns:
        Dict[str, str]: metadata dict
    """
    # create dict for meta
    run_meta = dict()
    # write meta to dict
    run_meta["accession"] = run.getAttribute("accession")
    run_meta["allias"] = run.getAttribute("alias")
    return run_meta


def parse_id(run: minidom.Element) -> Dict[str, str]:
    """
    Parse id names
    Args:
        run (minidom.Element): grouped run metadata

    Returns:
        Dict[str, str]: metadata dict
    """
    # create dict for meta
    id_meta = dict()
    # get id objects
    identifiers = run.getElementsByTagName("IDENTIFIERS")[0]
    primary_id = identifiers.getElementsByTagName("PRIMARY_ID")[0]
    external_ids = identifiers.getElementsByTagName("EXTERNAL_ID")
    # write to dict
    id_meta["primary_id"] = primary_id.childNodes[0].nodeValue
    id_meta.update(
        {
            id.getAttribute("namespace").lower() + "_id": id.childNodes[0].nodeValue
            for id in external_ids
        }
    )
    return id_meta


def parse_references(run: minidom.Element) -> Dict[str, str]:
    """
    Parse experiment and sample names for the run
    Args:
        run (minidom.Element): grouped run metadata

    Returns:
        Dict[str, str]: metadata dict
    """
    # create dict for meta
    reference_meta = dict()
    # get pool and experiment objects
    pool_member = run.getElementsByTagName("Pool")[0].getElementsByTagName("Member")[0]
    experiment = run.getElementsByTagName("EXPERIMENT_REF")[0]
    # write to dict
    reference_meta["experiment"] = experiment.getAttribute("accession")
    reference_meta["sample"] = pool_member.getAttribute("accession")
    reference_meta["geo_sample"] = pool_member.getAttribute("sample_name")
    reference_meta["organism"] = pool_member.getAttribute("organism")
    return reference_meta


def parse_files(run: minidom.Element) -> Dict[str, str]:
    """
    Parse file urls
    Args:
        run (minidom.Element): grouped run metadata

    Returns:
        Dict[str, str]: metadata dict
    """
    # create dict for meta
    file_meta = dict()
    # get file objects
    files = run.getElementsByTagName("SRAFiles")[0].getElementsByTagName("SRAFile")
    # edit name string
    edit = lambda name: (
        "bam" if "bam" in name.lower() else name.lower().replace(" ", "_")
    )
    for file in files:
        name = file.getAttribute("semantic_name")
        alternatives = file.getElementsByTagName("Alternatives")
        file_meta[f"{edit(name)}_filename"] = file.getAttribute("filename")
        file_meta[f"{edit(name)}_url"] = file.getAttribute("url")
        for alternative in alternatives:
            if alternative.getAttribute("url") == file_meta[f"{edit(name)}_url"]:
                file_meta[f"{edit(name)}_available"] = alternative.getAttribute(
                    "free_egress"
                )
    return file_meta


def parse_run_meta(run: minidom.Element) -> Dict[str, str]:
    """
    Parse run metadata
    Args:
        run (minidom.Element): grouped run metadata

    Returns:
        Dict[str, str]: metadata dict
    """
    # create a dict with specified keys
    run_meta = {key: None for key in KEYS}
    # write metadata to dict
    run_meta.update(parse_run(run))
    run_meta.update(parse_id(run))
    run_meta.update(parse_references(run))
    run_meta.update(parse_files(run))
    return run_meta


def main() -> None:
    # parse script arguments
    parser = init_parser()
    args = parser.parse_args()

    # parse xml file and group elements
    domtree = minidom.parse(args.meta)
    group = domtree.documentElement

    # write run meta to list
    run_meta_list = [parse_run_meta(run) for run in group.getElementsByTagName("RUN")]

    # write to tsv file
    with open(args.output, mode="w", newline='') as csv_file:
        # create writer object
        writer = csv.DictWriter(
            csv_file, fieldnames=KEYS, delimiter=args.sep
        )

        # write the data
        for run_meta in run_meta_list:
            meta_to_write = {key:run_meta.get(key, None) for key in KEYS}
            writer.writerow(meta_to_write)


if __name__ == "__main__":
    main()
