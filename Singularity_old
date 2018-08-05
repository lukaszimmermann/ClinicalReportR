Bootstrap: docker
From: ensemblorg/ensembl-vep:latest

%labels
    Maintainer Lukas Zimmermann
    Version v1.0

%runscript

    echo "I can put here whatever I want to happen when the user runs my container!"
    exec echo "Hello Monsoir Meatball" "$@"

%environment
export OPT=/opt/vep
export PERL5LIB=/opt/vep/loftee-0.3-beta:/opt/vep/src/bioperl-live-release-1-6-924
export INOUT_DIR=/inout

%files
ReportApp

%post
########################################################################
# Define environment variables
########################################################################
export OPT=/opt/vep
export PERL5LIB=${OPT}/loftee-0.3-beta:${OPT}/src/bioperl-live-release-1-6-924
export VEP_CACHE=${OPT}/.vep/Cache
export VEP_PLUGINS=${OPT}/.vep/Plugins
export DATA_DIR=/data
export REST_API_DIR=/api
export LOG_BUILD_DIR=/buildlogs
export INOUT_DIR=/inout

########################################################################
# Install all the required pack mktemp -dages for the clinical Reporting pipeline
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

apt-get update -y
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
apt-get update -y
apt-get install -y apt-utils
apt-get install -y \
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
  r-base \
  samtools \
  sudo

  rm -rf ${TEMPDIR}

########################################################################
# Ensure existence of certain directories
########################################################################
mkdir -p ${LOG_BUILD_DIR}
mkdir -p ${VEP_PLUGINS}
mkdir -p ${VEP_CACHE}
mkdir -p ${DATA_DIR}/db
mkdir -p ${INOUT_DIR}

########################################################################
# Set the locale
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

apt-get update -y
locale-gen "en_US.UTF-8"

rm -rf ${TEMPDIR}
########################################################################
# Install MongoDB
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list
apt-get update -y
apt-get install -y mongodb-org

rm -rf ${TEMPDIR}
########################################################################
# Download and import the MongoDB seed
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

wget -O ${TEMPDIR}/db.json \
  https://raw.githubusercontent.com/PersonalizedOncology/clinicalReporting_DB_RESTAPI/master/mongo-seed/driver_db_dump.json

mongod &
child_pid=$!

mongoimport \
  --host localhost \
  --db clinical_reporting \
  --collection biograph_genes \
  --jsonArray \
  --file ${TEMPDIR}/db.json \
  --drop > ${LOG_BUILD_DIR}/mongoimport 2>&1

kill ${child_pid}

rm -rf ${TEMPDIR}
########################################################################
# Install R
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list
echo "deb http://ftp.halifax.rwth-aachen.de/ubuntu xenial-backports main restricted universe" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | apt-key add -
Rscript -e 'install.packages(c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "RCurl", "devtools", "log4r"), dependencies = TRUE, repos = "https://cloud.r-project.org")'
Rscript -e 'devtools::install_github("jeremystan/tidyjson")'
Rscript -e 'devtools::install_github("davidgohel/officer")'
Rscript -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("VariantAnnotation", "rjson"), ask = FALSE, suppressUpdates = TRUE)'

rm -rf ${TEMPDIR}
########################################################################
# Install Ensembl-vep
########################################################################
chown -R vep:vep ${OPT}

su vep <<'EOF'
cd ${OPT}/src/ensembl-vep/
git pull
git checkout release/92
./INSTALL.pl -a acf -s homo_sapiens -y GRCh37
./INSTALL.pl -a p -g LoFtool
EOF


########################################################################
# Install another version of LoFtee
########################################################################
# Although LoF is installed via VEP's install script above, it's unclear
# which version. To be sure, we overwrite it with the latest release on github
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

wget -O ${TEMPDIR}/v0.3-beta.zip \
   https://github.com/konradjk/loftee/archive/v0.3-beta.zip
unzip v0.3-beta.zip
cp loftee-0.3-beta/LoF.pm ${VEP_PLUGINS}

chown -R vep:vep ${VEP_PLUGINS}
rm -rf ${TEMPDIR}
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


# Set the data completeness flag
touch ${DATA_DIR}/completeness.flag

########################################################################
# Set up REST API
########################################################################
TEMPDIR=$(mktemp -d)
cd ${TEMPDIR}

mkdir -p ${REST_API_DIR}
pip3 install --no-cache-dir simplejson
pip3 install --no-cache-dir eve
pip3 install --no-cache-dir gunicorn
mv /ReportApp/settings.py  ${REST_API_DIR}/settings.py
mv /ReportApp/run.py  ${REST_API_DIR}/run.py

rm -rf ${TEMPDIR}
########################################################################
# Install Perl SQLite support
########################################################################
cpanm DBD::SQLite

########################################################################
# Move the VEP files to the correct location
########################################################################
mv /ReportApp/vep_singularity.ini ${OPT}/.vep/vep.ini
mv /ReportApp/make_report.sh ${OPT}
mv /ReportApp/reporting.R ${OPT}

########################################################################
# Setup docxtemplater
########################################################################
mv /ReportApp/docxtemplater ${OPT}
cd ${OPT}/docxtemplater
npm install -g

########################################################################
# Correct all permissions and set scripts executable
########################################################################
chown -R vep:vep ${OPT}
chown -R vep:vep ${INOUT_DIR}
chmod u+rwx ${INOUT_DIR}
chmod +x ${OPT}/make_report.sh
chmod +x ${OPT}/reporting.R

########################################################################
# Cleanup
########################################################################
rm -rf /ReportApp

%test
  export LOG_BUILD_DIR=/buildlogs
  export OPT=/opt/vep

  # Test the existence of certain files
  stat ${OPT}/make_report.sh
  stat ${OPT}/reporting.R
  stat ${OPT}/.vep/vep.ini

  # Check that the correct number of documents was imported to MongoDB
  grep 42307 ${LOG_BUILD_DIR}/mongoimport
