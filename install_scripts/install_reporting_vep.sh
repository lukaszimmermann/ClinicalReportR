#!/bin/bash
set -e

    git clone https://github.com/PersonalizedOncology/ClinicalReportR.git && \
    mv  ClinicalReportR/ReportApp .. && \
    rm -rf ClinicalReportR && \
    chmod +x /opt/ReportApp/reporting.R && \
    mv /opt/ReportApp/clinicalreporting_docxtemplater /opt/templater

WORKDIR /opt/vep/src/ensembl-vep
ENTRYPOINT [ "python", "/opt/report_generate.py" ]
