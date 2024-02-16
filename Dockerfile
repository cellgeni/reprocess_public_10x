FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG star_version=2.7.10a_alpha_220818
ARG samtools_version=1.15.1
ARG seqtk_version=1.4
ARG sratools_version=3.0.10
ARG bamtofastq_version=1.4.1
ARG pfq_version=0.6.7

#Install OS packages
RUN apt-get update && apt-get -y --no-install-recommends -qq install \
    wget gcc build-essential software-properties-common libz-dev \
    git libncurses5-dev libbz2-dev liblzma-dev default-jre bsdmainutils pbzip2 pigz

#Install STAR
RUN wget --no-check-certificate https://github.com/alexdobin/STAR/archive/${star_version}.tar.gz && \
    tar -xzf ${star_version}.tar.gz -C /opt && \
    cd /opt/STAR-${star_version}/source && \
    make STAR CXXFLAGS_SIMD="-msse4.2" && \
    cd / && rm ${star_version}.tar.gz 

#Install seqtk
RUN wget --no-check-certificate https://github.com/lh3/seqtk/archive/refs/tags/v${seqtk_version}.tar.gz && \
    tar -xzf v${seqtk_version}.tar.gz -C /opt && \
    cd /opt/seqtk-${seqtk_version} && \
    make && \
    cd / && rm v${seqtk_version}.tar.gz

#Install samtools
RUN wget --no-check-certificate https://github.com/samtools/samtools/releases/download/${samtools_version}/samtools-${samtools_version}.tar.bz2 && \
    tar -xvf samtools-${samtools_version}.tar.bz2 -C /opt && \
    cd /opt/samtools-${samtools_version} && \
    ./configure && \
    make && \
    make install && \
    cd / && rm samtools-${samtools_version}.tar.bz2  

#Install SRA-tools (pre-built binaries)
RUN wget --no-check-certificate https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${sratools_version}/sratoolkit.${sratools_version}-ubuntu64.tar.gz && \
    tar -xvf sratoolkit.${sratools_version}-ubuntu64.tar.gz -C /opt && \
    cd / && rm sratoolkit.${sratools_version}-ubuntu64.tar.gz

#Install bamtofastq
RUN wget --no-check-certificate https://github.com/10XGenomics/bamtofastq/releases/download/v${bamtofastq_version}/bamtofastq_linux && \
    chmod +x bamtofastq_linux && \
    mv bamtofastq_linux /usr/local/bin/bamtofastq

#Install parallel-fastq-dump
RUN wget --no-check-certificate https://github.com/rvalieris/parallel-fastq-dump/archive/refs/tags/${pfq_version}.tar.gz && \
    tar -xvf ${pfq_version}.tar.gz -C /opt && \
    cd / && rm ${pfq_version}.tar.gz
    

ENV PATH="${PATH}:/opt/STAR-${star_version}/source:/opt/seqtk-${seqtk_version}:/opt/sratoolkit.${sratools_version}-ubuntu64/bin:/opt/parallel-fastq-dump-${pfq_version}"     

#Saving Software Versions to a file
RUN echo "STAR version: ${star_version}" >> versions.txt && \
    echo "samtools version: ${samtools_version}" >> versions.txt && \
    echo "SRA-tools version: ${sratools_version}" >> versions.txt && \
    echo "bamtofastq version: ${bamtofastq_version}" >> versions.txt && \
    echo "seqtk version: ${seqtk_version}" >> versions.txt && \ 
    echo "Parallel fastq-dump version: ${pfq_version}" >> versions.txt 
