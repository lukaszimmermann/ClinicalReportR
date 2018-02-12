#!/bin/bash

infile=$1
outfile=$infile.out.vcf

# annotate file
echo "################ Starting variant effect prediction ################"
vep -i $infile -o $outfile && \
echo "################ $outfile is created. ################"

# create report
echo "################ Start to create report ################"
Rscript /home/vep/reporting.R -f $outfile && \
echo "################ Report is created  ################"