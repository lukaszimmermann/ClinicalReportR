FROM ensemblorg/ensembl-vep:release_93
LABEL maintainer="luk.zim91@gmail.com"

USER root
WORKDIR /tmp
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends --no-install-suggests \
      apt-utils  && \
    apt-get install -y --no-install-recommends --no-install-suggests \
      apt-transport-https \
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
      r-base && \
    locale-gen "en_US.UTF-8" && \
    echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list && \
    echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list && \
    gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
    gpg -a --export E084DAB9 | apt-key add - && \
    Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "RCurl", "devtools", "log4r"), dependencies = TRUE, repos = "https://cloud.r-project.org")' && \
    Rscript -e 'devtools::install_github("jeremystan/tidyjson")' && \
    Rscript -e 'devtools::install_github("davidgohel/officer")' && \
    Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation", "rjson"), ask = FALSE)' && \
    cpanm DBD::SQLite && \
    mkdir -p /inout && \
    chown -R vep:vep /inout

USER vep
COPY vep.ini /opt/vep.ini
ENV CACHE_DIR "/opt/vep/.vep"
ENV DATA_INSTALL "/tmp/data_install"
WORKDIR /opt/vep/src/ensembl-vep
RUN git checkout release/93 && \
    git pull origin release/93 && \
    chmod +x /opt/vep/src/ensembl-vep/INSTALL.pl && \
    /opt/vep/src/ensembl-vep/INSTALL.pl -a acf -s homo_sapiens -y GRCh37 && \
    /opt/vep/src/ensembl-vep/INSTALL.pl -a p -g LoFtool && \
    mkdir -p "${DATA_INSTALL}" && \
    cd "${DATA_INSTALL}" && \
    wget https://github.com/konradjk/loftee/archive/v0.3-beta.tar.gz && \
    wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz && \
    wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz.fai && \
    wget https://raw.githubusercontent.com/Ensembl/VEP_plugins/release/93/LoFtool_scores.txt && \
    wget https://www.broadinstitute.org/%7Ekonradk/loftee/phylocsf.sql.gz && \
    tar xf v0.3-beta.tar.gz && \
    gunzip phylocsf.sql.gz && \
    cp "${DATA_INSTALL}/loftee-0.3-beta/LoF.pm" "${CACHE_DIR}/Plugins" && \
    cp "${DATA_INSTALL}/human_ancestor.fa.rz" "${CACHE_DIR}" && \
    cp "${DATA_INSTALL}/human_ancestor.fa.rz.fai" "${CACHE_DIR}" && \
    cp "${DATA_INSTALL}/LoFtool_scores.txt" "${CACHE_DIR}" && \
    cp "${DATA_INSTALL}/phylocsf.sql" "${CACHE_DIR}" && \
    rm -rf "${DATA_INSTALL}" /tmp/* /var/tmp/*
