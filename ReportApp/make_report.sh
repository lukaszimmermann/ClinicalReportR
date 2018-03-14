#!/bin/bash
OPTIND=1
while getopts "t:p:" opt; do
    case $opt in
        t) infile=$OPTARG
        ;;
        p) savedOut=$OPTARG
        ;;
    esac
done
shift "$((OPTIND-1))"

CPWD=$(pwd)

# outfile=$infile.out.vcf

# annotate file
echo "################ Starting variant effect prediction ################"
vep -i $infile -o $infile.out.vcf && \
echo "################ $outfile is created. ################"

# create json
echo "################ Start to create json ################"
Rscript /home/vep/reporting.R -f $infile.out.vcf  && \
echo "################ JSON is created  ################"
cp base.log /data

if [[ $savedOut == *"j"* ]]; then
    cp report.json /data
    echo "JSON is saved to the volume"
fi

echo "################ Start to create report ################"
nodejs /data/clinicalreporting_docxtemplater/main.js -d report.json -t /data/clinicalreporting_docxtemplater/data/template.docx -o out.docx && \
echo "################ Report is created  ################"
if [[ $savedOut == *"w"* ]]; then
    cp out.docx /data
    echo "Report is saved to the volume as DOCX file."
fi

    # convert it to pdf
if [[ $savedOut == *"p"* ]]; then
    echo "################ Start to create pdf ################"
    libreoffice --headless --convert-to pdf /data/out.docx && \
    echo "################ pdf is created  ################"
    cp out.pdf /data && \
    echo "Report is saved to the volume as PDF file."
fi
