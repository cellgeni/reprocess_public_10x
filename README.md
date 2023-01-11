# Download and reprocess 10x datasets

<img width="1233" height="474" src="https://github.com/cellgeni/reprocess_public_10x/blob/master/img/seriousman2.png">


This wrapper script can be used for a simple, one-command reprocessing of a publicly available 10x dataset. All you need to do is clone this repo into your home on Farm, and then run 

`nohup ./reprocess_public_10x.sh <series_ID> &> reprocess.log &`

This collection of scripts is Sanger-specific and Farm-specific, and would need to be modified substantially to work somewhere else.  

Currently, the following platforms are supported:

  - GEO: provide GSE series ID;
  - ArrayExpress: provide E-MTAB series ID;
  - SRA/ENA: provide bioProject (PRJNA/PRJEB etc). 

The processing is done under assumption of one 10x run per GSM in case of GEO, or one SRS/ERS in case of ArrayExpress/SRA/ENA. 

## But how does this magick works?!

Here's a brief description of what happens under the hood: 

  - Using ffq, we obtain metadata JSON for the whole series. We loop until `ffq` produces no error, which can be tricky for series with 1000's of IDs (e.g. ones that include Smart-seq2, etc). We're working on a more robust solution for cases like this; 
  - Using a custom script named `parse_json.pl`, we obtain a flat table that contains GSM/SRS/SRX/SRR IDs (only the last 3 for AE/SRA/ENA); 
  - Using ENA web API, we get ENA metadata for each run (ERR/SRR), and get the best URLs to download the raw data, alongside with some nice additional metadata;
  - We then download the raw files using Farm's `transfer` queue. The process is followed by a "cleanup" and repeated until all files have been downloaded successfully; 
  - If the reads are available as paired-end fastq files, we assume they have been decoded correctly (i.e. read ending with **1.fastq.gz** is barcode + UMI, and **2.fastq.gz** is the "biological" read). No further processing is required; 
  - If the reads are only available as SRA archives, or have been decoded to single-end fastq files, we run `fastq-dump` on the archive, after which we identify the biological and barcode reads, and rename them accordingly. After this, the reads are gzipped. This is done using the `normal` queue with 16 CPUs and 128 Gb RAM; 
  - If the reads are only available as 10x BAM files, we decode them to fastq files using 10x's version of `bamtofastq`. This is also done on the `normal` queue with 16 CPUs and 128 Gb RAM; 
  - After everything is successfully decoded, we group the reads according to the sample-to-run relationship file generated earlier (named `sample_to_run.tsv`). All reads are placed into `/fastqs` subdirectory;
  - Following this, we run our wonderful starsolo script that automatically determines 10x chemistry, the name of your first pet, and security question to your bank account. This is also done - *you've guessed it!* - using the `normal` queue with 16 CPUs and 128 Gb RAM! 
  - Finally, a simple QC script gathers some alignment statistics, that are placed in the file ending with `solo_qc.tsv`. 

*Voila!*

All `bsub` jobs are submitted using job arrays with your series ID + job type (transfer, starsolo, etc) - thus, a simple `bjobs -w` command should help you see where are you on Farm queue. This also makes it easier to kill things selectively. 

## But why is this so complex?!! 

Unfortunately, GEO routinely butchers 10x read data, probably with some help from less experienced submitters. The reads are encoded in the *abhorrent* SRA format, and exact specifications change quite dramatically between different experiments. The process above took many months of trial and error to perfect, and was made as simple as possible, but not simpler (c). 

## Your fancy script generated an error!

Please make an issue or message Alex (@ap41), and I'll be happy to take a look.
