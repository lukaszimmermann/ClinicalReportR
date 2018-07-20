#!/bin/bash
set -e

# Check that the directories are present
if [ ! -d /opt/reporting ]; then
  echo "FATAL: /opt/reporting  not found"
  exit 1
fi

if [ ! -d /opt/templater ]; then
  echo "FATAL: /opt/templater not found"
  exit 2
fi

# Install Reporting
chmod +x /opt/reporting/reporting.R

# Install templater
cd /opt/templater
npm install -y
