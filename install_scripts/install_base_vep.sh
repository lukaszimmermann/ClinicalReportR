#!/bin/bash
set -e

if [ ! -f /opt/vep.ini  ]; then
  echo "File: /opt/vep.ini does not exist!"
  exit 1
fi

CACHE_DIR="/opt/vep/.vep"
DATA_INSTALL="/tmp/data_install"

# Install VEP
cd /opt/vep/src/ensembl-vep
git checkout release/93
git pull origin release/93
chmod +x /opt/vep/src/ensembl-vep/INSTALL.pl
chmod +x /opt/vep/src/ensembl-vep/vep
/opt/vep/src/ensembl-vep/INSTALL.pl -a acf -s homo_sapiens -y GRCh37
/opt/vep/src/ensembl-vep/INSTALL.pl -a p -g LoFtool

# Install Data
mkdir -p "${DATA_INSTALL}"
cd "${DATA_INSTALL}"
wget https://github.com/konradjk/loftee/archive/v0.3-beta.tar.gz
wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz
wget http://www.broadinstitute.org/~konradk/loftee/human_ancestor.fa.rz.fai
wget https://raw.githubusercontent.com/Ensembl/VEP_plugins/release/93/LoFtool_scores.txt
wget https://www.broadinstitute.org/%7Ekonradk/loftee/phylocsf.sql.gz
tar xf v0.3-beta.tar.gz
gunzip phylocsf.sql.gz
cp "${DATA_INSTALL}/loftee-0.3-beta/LoF.pm" "${CACHE_DIR}/Plugins"
cp "${DATA_INSTALL}/human_ancestor.fa.rz" "${CACHE_DIR}"
cp "${DATA_INSTALL}/human_ancestor.fa.rz.fai" "${CACHE_DIR}"
cp "${DATA_INSTALL}/LoFtool_scores.txt" "${CACHE_DIR}"
cp "${DATA_INSTALL}/phylocsf.sql" "${CACHE_DIR}"
cp -a "${DATA_INSTALL}/loftee-0.3-beta" "${CACHE_DIR}/Plugins"

rm -rf "${DATA_INSTALL}"

