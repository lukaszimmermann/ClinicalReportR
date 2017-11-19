# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep).

## Quickstart

We assume that we want to create a report for a vcf file `my.vcf` residing in `$HOME/vep_data`, and that you have R and Docker installed. First, follow instructions to install and run the [Biograph REST API](https://github.com/mrdivine/clinicalReporting_DB_RESTAPI). Then clone this repository and `cd` into it.

First, we need to get and run the REST service via docker:

```
1. git clone https://github.com/mrdivine/clinicalReporting_DB_RESTAPI.git
2. cd clinicalReporting_DB_RESTAPI
3. docker-compose up
```

Now we clone this repository and checkout the single_script branch:

```
4. git clone https://github.com/PersonalizedOncology/ClinicalReportR.git
5. cd ClinicalReportR
6. git checkout single_script
```

Now we download some data for required for ensemble-vep:

```
7. wget https://s3.amazonaws.com/bcbio_nextgen/human_ancestor.fa.gz
8. wget https://s3.amazonaws.com/bcbio_nextgen/human_ancestor.fa.gz.fai
9. wget https://s3.amazonaws.com/bcbio_nextgen/human_ancestor.fa.gz.gzi
8. docker run -t -i -v $CLINICALREPORTR:/home/vep/.vep personalizedoncology/clinicalreportr:latest perl /home/vep/src/ensembl-vep/INSTALL.pl perl INSTALL.pl -a cf -s homo_sapiens -y GRCh38
```

This will download cache files into `$CLINICALREPORTR`, e.g. the directory you cloned this repository into. 

```
9. docker run -t -i -v $CLINICALREPORTR:/data personalizedoncology/clinicalreportr:latest vep -i /data/my.vcf -o my_annotated.vcf
10. Rscript reporting.R -f my_annotated.vcf
```

## Requirements
The reporting script relies on a running REST service for the Biograph data. This is currently under [development](https://github.com/mrdivine/clinicalReporting_DB_RESTAPI).
After cloning the repository, change to the respective directory and run:

```docker-compose up```

## Installation
The preferred method to run this script is to use the docker container:


## Usage

Creating a report from a vcf file is currently a multi-step process:

1. Annotate your vcf via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep) __using the vep_docker.ini file included in this package__:
`docker run --rm -v /absolute/path/to/vcf:/data ensemblorg/ensembl-vep:latest vep --config /data/vep_docker.ini -i /data/strelka.passed.missense.somatic.snvs.vcf -o /data/strelka.passed.missense.somatic.snvs_annotated.vcf
`

2. Create a report:
`Rscript reporting.R -f /absolute/path/to/strelka.passed.missense.somatic.snvs_annotated.vcf`

This will create a file `/absolute/path/to/strelka.passed.missense.somatic.snvs_annotated.vcf.docx` with the report.
