FROM personalizedoncology/vep_plugins_containerized

# install current version of R
RUN sudo sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list' && \
 sudo sh -c 'echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu trusty-backports main restricted universe" >> /etc/apt/sources.list' && \
 gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
 gpg -a --export E084DAB9 | sudo apt-key add - && \
 apt-get -y update && apt-get install -y r-base r-base-dev libcurl4-openssl-dev openjdk-7-jdk r-cran-rjava libssh2-1-dev libcairo2-dev

RUN R CMD javareconf

# opencpu
# the following two packages are required for add-apt-repository only and could
# thus be removed if the ppa can be added to /etc/apt/sources.list as above directly
RUN sudo apt-get install -y software-properties-common python-software-properties
RUN sudo add-apt-repository -y ppa:opencpu/opencpu-1.6 && \
  sudo apt-get -y update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install -y opencpu-server

# install required R packages
RUN Rscript -e 'install.packages(c("devtools", "tidyr"), repos = "http://cran.uni-muenster.de/", dependencies = TRUE)' && \
  Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite("VariantAnnotation")'

RUN Rscript -e 'devtools::install_github("PersonalizedOncology/ClinicalReportR", dependencies = TRUE)'

RUN mkdir -p /vep/.vep
COPY vep_docker.ini /vep/.vep/vep.ini

RUN mkdir /reporting
WORKDIR /reporting
RUN ln -s /usr/local/lib/R/site-library/ClinicalReportR/cmd/reporting.R

CMD ["/usr/bin/Rscript", "/reporting/reporting.R"]
