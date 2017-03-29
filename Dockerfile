FROM personalizedoncology/vep_plugins_containerized

# install current version of R and required packages
RUN sudo sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list' && \
 sudo sh -c 'echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu trusty-backports main restricted universe" >> /etc/apt/sources.list' && \
 gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
 gpg -a --export E084DAB9 | sudo apt-key add - && \
 apt-get -y update && \
 # install add-apt-repository
 apt-get install -y software-properties-common && \
 add-apt-repository -y ppa:opencpu/opencpu-1.6 && \
 sudo add-apt-repository ppa:marutter/rrutter -y && \
 sudo add-apt-repository ppa:marutter/c2d4u -y && \
 apt-get update && \
 apt-get install -y r-base r-base-dev libcurl4-openssl-dev openjdk-7-jdk r-cran-rjava libssh2-1-dev libcairo2-dev \
  r-cran-devtools r-cran-tidyr r-cran-dplyr r-cran-rmysql r-cran-reporters r-cran-stringr r-cran-xml r-cran-optparse \
  r-cran-readr r-bioc-biocgenerics r-bioc-genomicranges r-bioc-biostrings r-bioc-genomeinfodb r-bioc-summarizedexperiment \
  r-bioc-rsamtools r-bioc-biobase r-bioc-iranges r-bioc-annotationdbi r-bioc-genomicalignments

RUN R CMD javareconf

# install R package
RUN \
  Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation", "ensemblVEP"), ask = FALSE, suppressUpdates = TRUE)' && \
  Rscript -e 'devtools::install_github("PersonalizedOncology/ClinicalReportR", dependencies = TRUE)'

# copy configuration files
RUN mkdir -p /vep/.vep
COPY vep_docker.ini /vep/.vep/vep.ini

COPY opencpu.conf /etc/opencpu/server.conf

RUN mkdir /reporting
WORKDIR /reporting
RUN ln -s /usr/local/lib/R/site-library/ClinicalReportR/cmd/reporting.R

# Apache ports
EXPOSE 80
EXPOSE 443
EXPOSE 8004

# Define default command.
CMD service opencpu restart && tail -F /var/log/opencpu/apache_access.log

# Development
COPY inst/extdata/strelka.passed.missense.somatic.snvs_short.vcf /vep/test.vcf
