FROM ensemblorg/ensembl-vep:latest

# update vep, install and configure required vep plugins
USER vep
WORKDIR $HOME/src/ensembl-vep
RUN ./INSTALL.pl -a p -g LoFtool

#USER root
# install current version of R and required packages for vep
#RUN sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list' && \
# sh -c 'echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list' && \
# gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
# gpg -a --export E084DAB9 | apt-key add -

#RUN apt-get -y update && \
#  apt-get install -y r-base libxml2-dev libcurl4-openssl-dev libssh2-1-dev libcairo2-dev samtools libpq-dev
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install R packages
#RUN Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "RCurl", "devtools"), dependencies = TRUE, repos = "https://cloud.r-project.org")'
#RUN Rscript -e 'devtools::install_github("jeremystan/tidyjson")'
#RUN Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation"), ask = FALSE, suppressUpdates = TRUE)'

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
COPY vep_docker.ini /home/vep/.vep/vep.ini
COPY make_report.sh /home/vep/
COPY reporting.R /home/vep

#RUN chmod +x /home/vep/make_report.sh /home/vep/reporting.R
#CMD /home/vep/make_report.sh
