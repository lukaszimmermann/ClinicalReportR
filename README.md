# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep).

Note: CIvic only supports reference genome build 37.



## Usage

We assume that we want to create a report for a vcf file `my.vcf` residing in `$HOME`, and that you have R and Docker installed. First, follow instructions to download the [Biograph REST API](https://github.com/mrdivine/clinicalReporting_DB_RESTAPI). 

We clone this repository and checkout the single_script branch:

```
1. git clone -b single_script https://github.com/PersonalizedOncology/ClinicalReportR.git
2. cd ClinicalReportR/ReportApp
```
Now we download some data for required for ensemble-vep:

```
3. export CLINICALREPORTR=`pwd`
4. wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz
5. wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz.fai
6. wget https://raw.githubusercontent.com/Ensembl/VEP_plugins/release/90/LoFtool_scores.txt
7. docker run -t -i -v $CLINICALREPORTR:/home/vep/.vep ensemblorg/ensembl-vep perl INSTALL.pl -a acf -s homo_sapiens -y GRCh37
```

This will download cache files into `$CLINICALREPORTR`, e.g. the directory you cloned this repository into. 

```
8. cd ..
9. docker-compose run --service-ports ClinicalReportR -t /data/<VCF FILE> -p jwp

```
* `-t`: input file name. This should be in the data volume of ClinicalReportR service.
* `-p`: output format to save the results.
	* `j` to save report in JSON format
	* `w` to save report in DOCX format
	* `p` to save report in PDF format

You should now have the report in ReportApp folder.
