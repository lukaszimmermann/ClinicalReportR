#!/bin/bash

infile=$1
outfile=$infile.out.vcf

# annotate file
echo "################ Starting variant effect prediction ################"
vep -i $infile -o $outfile && \
echo "################ $outfile is created. ################"

# create json
echo "################ Start to create json ################"
Rscript /home/vep/reporting.R -f $outfile && \
echo "################ JSON is created  ################"
cp base.log /data
cp report.json /data

# create report
echo "################ Start to create report ################"
nodejs /data/docxtemplater/main.js -d report.json -t /data/docxtemplater/data/template.docx -o /data/out.docx && \
echo "################ Report is created  ################"