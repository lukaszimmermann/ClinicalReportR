Bootstrap: docker
From: ensemblorg/ensembl-vep:latest

%labels
    Maintainer Lukas Zimmermann
    Version v1.0

%runscript

    echo "I can put here whatever I want to happen when the user runs my container!"
    exec echo "Hello Monsoir Meatball" "$@"

%environment
export PERL5LIB=/opt/vep/loftee-0.3-beta:/opt/vep/src/bioperl-live-release-1-6-924
export OUTPUT_DIR=/output

%files
ReportApp

%post
########################################################################
# Define environment variables
########################################################################
export TEMP_DIR=/tmp
export PERL5LIB=/opt/vep/loftee-0.3-beta:/opt/vep/src/bioperl-live-release-1-6-924
export VEP_BASEDIR=/opt/vep
export DATA_DIR=/data
export REST_API_DIR=/api
export LOG_BUILD_DIR=/buildlogs
export INOUT_DIR=/inout

########################################################################
# Install all the required packages for the clinical Reporting pipeline
########################################################################
cd ${TEMP_DIR}
apt-get update -y
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
apt-get update -y
apt-get install -y apt-utils
apt-get install -y \
  apt-transport-https \
  libcairo2-dev \
  libcurl4-openssl-dev \
  libpq-dev \
  libreoffice \
  libssh2-1-dev \
  libxml2-dev \
  locales \
  nodejs \
  npm \
  python3 \
  python3-pip \
  r-base \
  samtools

  ########################################################################
  # For buildlogs
  ########################################################################
  cd ${TEMP_DIR}
  mkdir -p ${LOG_BUILD_DIR}

########################################################################
# Set the locale
########################################################################
cd ${TEMP_DIR}
apt-get update -y
locale-gen "en_US.UTF-8"

########################################################################
# Install MongoDB
########################################################################
cd ${TEMP_DIR}
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list
apt-get update -y
apt-get install -y mongodb-org
mkdir -p ${DATA_DIR}/db

########################################################################
# Download and import the MongoDB seed
########################################################################
cd ${DATA_DIR}
wget -O ${DATA_DIR}/driver_db_dump.json \
  https://raw.githubusercontent.com/PersonalizedOncology/clinicalReporting_DB_RESTAPI/master/mongo-seed/driver_db_dump.json
mongoimport \
  --host localhost \
  --db clinical_reporting \
  --collection biograph_genes \
  --jsonArray \
  --file ${DATA_DIR}/driver_db_dump.json \
  --drop > ${LOG_BUILD_DIR}/mongoimport 2>&1

  ########################################################################
  # Install R
  ########################################################################
  cd ${TEMP_DIR}
echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list
echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | apt-key add -
Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "RCurl", "devtools", "log4r"), dependencies = TRUE, repos = "https://cloud.r-project.org")'
Rscript -e 'devtools::install_github("jeremystan/tidyjson")'
Rscript -e 'devtools::install_github("davidgohel/officer")'
Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation", "rjson"), ask = FALSE, suppressUpdates = TRUE)'


########################################################################
# Install Ensembl-vep
########################################################################
cd ${VEP_BASEDIR}/src/ensembl-vep/
git pull
git checkout release/92
./INSTALL.pl -a acf -s homo_sapiens -y GRCh37
./INSTALL.pl -a p -g LoFtool


########################################################################
# Install another version of LoFtee
########################################################################
# Although LoF is installed via VEP's install script above, it's unclear
# which version. To be sure, we overwrite it with the latest release on github
cd ${TEMP_DIR}
wget -O ${TEMP_DIR}/v0.3-beta.zip \
   https://github.com/konradjk/loftee/archive/v0.3-beta.zip
unzip v0.3-beta.zip
rm v0.3-beta.zip
cp loftee-0.3-beta/LoF.pm ${VEP_BASEDIR}/.vep/Plugins

########################################################################
# Assemble the data directory
########################################################################
cd ${DATA_DIR}
wget -O ${DATA_DIR}/human_ancestor.fa.rz \
 http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz
wget -O ${DATA_DIR}/human_ancestor.fa.rz.fai \
 http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz.fai
wget -O ${DATA_DIR}/LoFtool_scores.txt \
  https://raw.githubusercontent.com/Ensembl/VEP_plugins/release/90/LoFtool_scores.txt
wget -O ${DATA_DIR}/phylocsf.sql.gz \
  https://www.broadinstitute.org/%7Ekonradk/loftee/phylocsf.sql.gz
gunzip phylocsf.sql.gz

# Move the homo sapiens stuff to the data dir
mv ${VEP_BASEDIR}/.vep/homo_sapiens ${DATA_DIR}

# Set the data completeness flag
touch ${DATA_DIR}/completeness.flag

########################################################################
# Set up REST API
########################################################################
cd ${TEMP_DIR}
mkdir -p ${REST_API_DIR}
pip3 install --no-cache-dir --upgrade pip
pip3 install --no-cache-dir simplejson
pip3 install --no-cache-dir gunicorn
pip3 install --no-cache-dir eve
mv /ReportApp/settings.py  ${REST_API_DIR}/settings.py
mv /ReportApp/run.py  ${REST_API_DIR}/run.py

########################################################################
# Install Perl SQLite support
########################################################################
cpanm DBD::SQLite

########################################################################
# Move the VEP files to the correct location
########################################################################
mv /ReportApp/vep_docker.ini ${VEP_BASEDIR}/.vep/vep.ini
mv /ReportApp/make_report.sh ${VEP_BASEDIR}
mv /ReportApp/reporting.R ${VEP_BASEDIR}

########################################################################
# Setup docxtemplater
########################################################################
mv /ReportApp/docxtemplater ${VEP_BASEDIR}
cd ${VEP_BASEDIR}/docxtemplater
npm install -g

########################################################################
# Create the inout dir
########################################################################
mkdir -p ${INOUT_DIR}

########################################################################
# Correct all permissions and set scripts executable
########################################################################
chown -R vep:vep ${VEP_BASEDIR}
chown -R vep:vep ${INOUT_DIR}
chmod +x ${VEP_BASEDIR}/make_report.sh
chmod +x ${VEP_BASEDIR}/reporting.R

########################################################################
# Cleanup
########################################################################
rm -rf /tmp/* /var/tmp/* /ReportApp

%test
  # Test the existence of certain files
  stat ${VEP_BASEDIR}/make_report.sh
  stat ${VEP_BASEDIR}/reporting.R
  stat ${VEP_BASEDIR}/.vep/vep.ini

  # Check that the correct number of documents was imported to MongoDB
  grep 42307 ${LOG_BUILD_DIR}/mongoimport
