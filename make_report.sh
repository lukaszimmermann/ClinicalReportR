#!/bin/bash

infile=$1
outfile=$infile.out.vcf

# annotate file
vep -i $1 -o $outfile

# create report
Rscript /home/vep/reporting.R -f $outfile
