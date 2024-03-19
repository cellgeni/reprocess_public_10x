# Download and reprocess 10x datasets

<img src="https://github.com/cellgeni/reprocess_public_10x/blob/main/img/seriousman2.png">

This wrapper script can be used for a simple, one-command reprocessing of a publicly available 10x dataset. All you need to do is clone this repo anywhere on Farm, add the location of `reprocess_public_10x` to `$PATH` variable, and then run the following command in the directory with lots of space:  

`reprocess_public_10x.sh <series_ID> &> <series_ID>.reprocess.log &`

You should use `nohup`/`tmux`/`screen`/`disown` or any other tool you like to keep the process in the background, since the processing will probably take a while. This collection of scripts is Sanger-specific and Farm-specific, and would need to be modified substantially to work somewhere else. 

Currently, the following platforms are supported:

  - GEO: provide GSE series ID;
  - ArrayExpress: provide E-MTAB series ID;
  - SRA/ENA: provide bioProject (PRJNA/PRJEB etc). 

The processing is done under assumption of one 10x run per GSM in case of GEO, or one SRS/ERS in case of ArrayExpress/SRA/ENA.

In case your series contains non-10x things you don't want to download, make a file with a list of GSM/SRS/ERS IDs, and pass it to the main script as a second argument. Only samples present in the list will be downloaded and processed: 

`reprocess_public_10x.sh <series_ID> [sample_list] &> <series_ID>.reprocess.log &`

## But how does this magick works?!

Here's a brief description of what happens under the hood: 

  - In this version, we abandon the use of `ffq`, and rely on ENA and supplementary GEO/ArrayExpress files:
    - for GEO, we download the `<series_ID>_soft.family.gz` file from GEO ftp, and pull the GSM(==sample) list and SRA project number from it; 
    - for ArrayExpress, we download the `<series_ID>.sdrf.txt` file from ArrayExpress ftp, and pull the ERS(==sample) list from it; 
    - for SRA/ENA, we just use the project number (PRJEB/PRJNA) for further queries.
  - Using ENA web API, we get ENA metadata either by sample or by project IDs, and get the best URLs to download the raw data, alongside with some nice additional metadata; 
  - At this point, we parse the metadata tables and calculate the relationships between the samples (GSM/SRS/ERS) and runs (SRR/ERR); 
  - We then download the raw files using Farm's `transfer` queue. The process is followed by a "cleanup" and repeated until all files have been downloaded successfully; 
  - If the reads are available as paired-end fastq files, we assume they have been decoded correctly (i.e. read ending with **1.fastq.gz** is barcode + UMI, and **2.fastq.gz** is the "biological" read). No further processing is required; 
  - If the reads are only available as SRA archives, or have been decoded to single-end fastq files, we run [parallel-fastq-dump](https://github.com/rvalieris/parallel-fastq-dump) on the archive, after which we identify the biological and barcode reads, and rename them accordingly. After this, the reads are gzipped. This is done using the `normal` queue with 16 CPUs and 32 Gb RAM; 
  - If the reads are only available as 10x BAM files, we decode them to fastq files using 10x's version of `bamtofastq`. This is also done on the `normal` queue with 16 CPUs and 4 Gb RAM; 
  - After everything is successfully decoded, we group the reads according to the sample-to-run relationship file generated earlier (named `<series_ID>.sample_x_run.tsv`). All reads are placed into `/fastqs` subdirectory;
  - Following this, we run our wonderful [STARsolo](https://github.com/cellgeni/STARsolo/) script that automatically determines 10x chemistry, the name of your first pet, and security question to your bank account. This is done using the `normal` queue with 16 CPUs and 128 Gb RAM. Sometimes, 128 Gb is not enough and the job will fail quietly (without any messages to `STDERR`). Check the `STDOUT` logs for the jobs that have _Exited_ rather then _Done_; they will also have a message about job being terminated for requesting too much memory.
  - Finally, a simple QC script gathers some alignment statistics, that are placed in the file named `<series_ID>.solo_qc.tsv`. 

*Voila!*

All `bsub` jobs are submitted using job arrays with your series ID + job type (transfer, starsolo, etc) - thus, a simple `bjobs -w` command should help you see where are you on Farm queue. This also makes it easier to kill things selectively. 

## But why is this so complex?!! 

Unfortunately, GEO routinely butchers 10x read data, probably with some help from less experienced submitters. The reads are encoded in the *abhorrent* SRA format, and exact specifications change quite dramatically between different experiments. The process above took many months of trial and error to perfect, and was made as simple as possible, but not simpler (c). 

## Docker and used tool versions

Most executables used by the scripts are packaged into a Singularity container. You can make it on your own, using the `Dockerfile` available in this repo. To do this, go to a machine with Docker installed, and run in the same directory as the Dockerfile: 

```
docker build -t local/my_container:latest .
sudo singularity build reprocess_10x.sif docker-daemon://local/my_container:latest
```
Here are the tools and their versions that are used currently: 
| Tool | Version |
|:-:|:-:|
| STAR | 2.7.10a_alpha_220818 |
| samtools | 1.15.1 | 
| seqtk | 1.4 | 
| SRA-tools | 3.0.10 | 
| bamtofastq | 1.4.1 | 
| parallel-fastq-dump | 0.6.7 | 

## Your fancy script generated an error!

Please make an issue or message Alex (@ap41), and I'll be happy to take a look.
