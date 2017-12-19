# Clinical Reporting in R

This is a prototype implementation of a clinical reporting pipeline in R.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep).

**Note** that this is an experimental branch. Currently, we need to build a docker image from this repository, but we can't run the `reporting.R` script from within the container, because it requires access to the REST service above, which will run on localhost port 5000. I haven't figured out yet how to make this accessible from the container, so we run the annotation from the container but create the final report using the plain reporting.R script.

## Usage

We assume that we want to create a report for a vcf file `my.vcf` residing in `$HOME`, and that you have R and Docker installed. First, follow instructions to install and run the [Biograph REST API](https://github.com/mrdivine/clinicalReporting_DB_RESTAPI). Then clone this repository and `cd` into it.

First, we need to get and run the REST service via docker:

```
1. git clone https://github.com/mrdivine/clinicalReporting_DB_RESTAPI.git
2. cd clinicalReporting_DB_RESTAPI
3. docker-compose up
```

Now we clone this repository and checkout the single_script branch:

```
4. git clone -b single_script https://github.com/PersonalizedOncology/ClinicalReportR.git
5. cd ClinicalReportR
6. docker build -t personalizedoncology/clinicalreportr:latest .
7. export CLINICALREPORTR=`pwd`
```

Now we download some data for required for ensemble-vep:

```
8. wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz
9. wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz.fai
10. wget https://github.com/Ensembl/VEP_plugins/blob/release/90/LoFtool_scores.txt
11. docker run -t -i -v $CLINICALREPORTR:/home/vep/.vep personalizedoncology/clinicalreportr:latest perl /home/vep/src/ensembl-vep/INSTALL.pl -a cf -s homo_sapiens -y GRCh37
```

This will download cache files into `$CLINICALREPORTR`, e.g. the directory you cloned this repository into. 

```
11. docker run -t -i -v $CLINICALREPORTR:/data personalizedoncology/clinicalreportr:latest vep -i /data/strelka.passed.missense.somatic.snvs_test.vcf -o my_annotated.vcf
12. Rscript reporting.R -f my_annotated.vcf
```

You should now have a file `my_annotated.vcf.docx`.

