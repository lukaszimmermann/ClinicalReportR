FROM ensemblorg/ensembl-vep:latest

# install and configure required vep plugins
USER vep
WORKDIR $HOME/src/ensembl-vep
RUN ./INSTALL.pl -a p -g LoFtool,GO

USER root
# install current version of R and required packages for vep
RUN sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list' && \
 sh -c 'echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list' && \
 gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
 gpg -a --export E084DAB9 | apt-key add - && \
 apt-get -y update
 # install add-apt-repository
 # apt-get install -y software-properties-common && \
 # add-apt-repository ppa:marutter/rrutter -y && \
 # add-apt-repository ppa:marutter/c2d4u -y && \
 # add-apt-repository ppa:openjdk-r/ppa -y && \
 # apt-get update && \
 # apt-get install -y --no-install-recommends r-base r-base-dev libcurl4-openssl-dev openjdk-7-jdk r-cran-rjava libssh2-1-dev libcairo2-dev \
 #  r-cran-devtools r-cran-tidyr r-cran-dplyr r-cran-rmysql r-cran-reporters r-cran-stringr r-cran-xml r-cran-optparse \
 #  r-cran-readr r-bioc-biocgenerics r-bioc-genomicranges r-bioc-biostrings r-bioc-genomeinfodb r-bioc-summarizedexperiment \
 #  r-bioc-rsamtools r-bioc-biobase r-bioc-iranges r-bioc-annotationdbi r-bioc-genomicalignments samtools

RUN apt-get install -y r-base libxml2-dev libcurl4-openssl-dev libssh2-1-dev libcairo2-dev samtools
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install R packages
RUN Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "tidyjson", "RCurl", "devtools"), dependencies = TRUE, repos = "https://cloud.r-project.org")'
RUN Rscript -e 'devtools::install_github("jeremystan/tidyjson")'
RUN Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation"), ask = FALSE, suppressUpdates = TRUE)'

# Although LoF is installed via VEP's install script above, it's unclear which version.
# To be sure, we overwrite it with the latest release on github
WORKDIR /home/vep
USER vep
RUN wget https://github.com/konradjk/loftee/archive/v0.3-beta.zip && \
  unzip v0.3-beta.zip && \
  rm v0.3-beta.zip && \
  cp loftee-0.3-beta/LoF.pm /home/vep/.vep/Plugins

USER root
# this is required for loftee-0.3-beta
RUN cpanm DBD::SQLite
ENV PERL5LIB /home/vep/loftee-0.3-beta/:$PERL5LIB

# copy configuration files
COPY inst/extdata/vep_docker.ini /home/vep/.vep/vep.ini
COPY make_report.sh /home/vep/
COPY inst/cmd/reporting.R /home/vep

RUN chmod +x /home/vep/make_report.sh /home/vep/reporting.R
CMD /home/vep/make_report.sh

#USER vep
#WORKDIR /home/vep
#RUN ln -s /usr/local/lib/R/site-library/ClinicalReportR/cmd/reporting.R
