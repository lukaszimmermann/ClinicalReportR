FROM lukaszimmermann/clinical-reporting-base:v1
LABEL maintainer="luk.zim91@gmail.com"

USER root
WORKDIR /tmp
RUN mkdir -p /inout && \
    chown -R vep:vep /inout && \
    chown -R vep:vep /opt

USER vep
WORKDIR /opt
COPY report_generate.py /opt

# install ReportApp and templater
RUN chmod -R u+w /opt && \
    git clone https://github.com/PersonalizedOncology/ClinicalReportR.git && \
    mv  ClinicalReportR/ReportApp .. && \
    rm -rf ClinicalReportR && \
    chmod +x /opt/ReportApp/reporting.R && \
    mv /opt/ReportApp/clinicalreporting_docxtemplater /opt/templater

WORKDIR /opt/vep/src/ensembl-vep
ENTRYPOINT [ "python", "/opt/report_generate.py" ]
