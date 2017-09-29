# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep). You can find an example report in data/.

## Requirements
The reporting script relies on a running REST service for the Biograph data. This is currently under development.


## Installation
Clone this repository and run the `reporting.R` script and provide a valid vcf file or use the docker container.

## Usage

Creating a report from a vcf file is currently a multi-step process:

1. Annotate your vcf via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep) __using the vep_docker.ini file included in this package__:
`docker run --rm -v /absolute/path/to/vcf:/data ensemblorg/ensembl-vep:latest vep --config /data/vep_docker.ini -i /data/strelka.passed.missense.somatic.snvs.vcf -o /data/strelka.passed.missense.somatic.snvs_annotated.vcf
`

2. Create a report:
`Rscript reporting.R -f /absolute/path/to/strelka.passed.missense.somatic.snvs_annotated.vcf`

This will create a file `/absolute/path/to/strelka.passed.missense.somatic.snvs_annotated.vcf.docx` with the report.

