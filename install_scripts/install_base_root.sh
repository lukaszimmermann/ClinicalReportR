#!/bin/bash
set -e

cd /tmp
apt-get update -y
apt-get install -y --no-install-recommends --no-install-suggests \
      apt-utils
apt-get install -y --no-install-recommends --no-install-suggests \
      apt-transport-https \
      gfortran \
      libcairo2-dev \
      libcurl4-openssl-dev \
      libpq-dev \
      libreoffice-common \
      libssh2-1-dev \
      libxml2-dev \
      locales \
      nodejs \
      npm \
      python3 \
      python3-pip \
      r-base
locale-gen "en_US.UTF-8"
echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list
echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | apt-key add -
Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "RCurl", "devtools", "log4r"), dependencies = TRUE, repos = "https://cloud.r-project.org")'
Rscript -e 'devtools::install_github("jeremystan/tidyjson")'
Rscript -e 'devtools::install_github("davidgohel/officer")'
Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation", "rjson"), ask = FALSE)'
cpanm DBD::SQLite
mkdir -p /inout
chown -R vep:vep /inout
chown -R vep:vep /opt

# Make opt writeable for vep
chmod u+w /opt

