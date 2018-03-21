# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep).

Note: CIvic only supports reference genome build 37.



## Usage

We assume that we want to create a report for a vcf file `my.vcf` residing in `$HOME`, and that you have R and Docker installed. First, follow instructions to download the [Biograph REST API](https://github.com/mrdivine/clinicalReporting_DB_RESTAPI). 

We clone this repository and checkout the single_script branch:

```
1. git clone -b single_script https://github.com/PersonalizedOncology/ClinicalReportR.git
```
Pelase note that the input VCF file should be in ReportApp folder.

```
2. cd ClinicalReportR/
3. docker-compose run --service-ports ClinicalReportR -t /inout/<VCF FILE> -p jwp

```
* `-t`: input file name. This should be in the data volume of ClinicalReportR service.
* `-p`: output format to save the results.
	* `j` to save report in JSON format
	* `w` to save report in DOCX format
	* `p` to save report in PDF format

You should now have the report in ReportApp folder.
