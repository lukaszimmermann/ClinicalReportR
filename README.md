# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via https://github.com/PersonalizedOncology/vep_plugins_containerized.
You can find an example report and corresponding template in inst/extdata.

## Installation
Simply install this R package

1. from an R session: `devtools::install_github("PersonalizedOncology/ClinicalReportR", dependencies = TRUE)`

or use the docker container.

## Usage

Creating a report from a vcf file is currently a two-step process:

1. Annotate your vcf via [Ensembl Variant Effect Predictor](https://hub.docker.com/r/personalizedoncology/vep_plugins_containerized/) __using the vep_docker.ini file included in this package__:
`docker run --rm -v /absolute/path/to/vcf:/data personalizedoncology/vep_plugins_containerized vep.pl --config /data/vep_docker.ini -i /data/strelka.passed.missense.somatic.snvs.vcf -o /data/strelka.passed.missense.somatic.snvs_annotated.vcf --vcf
`

2. Create a report:
`Rscript inst/cmd/reporting.R -f inst/extdata/strelka.passed.missense.somatic.snvs_annotated.vcf`
