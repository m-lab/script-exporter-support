#!/bin/bash

set -e
set -u
set -x

# These variables should not change much
USAGE="Usage: $0 <project> <keyname>"
PROJECT=${1:?Please provide project name: $USAGE}
KEYNAME=${2:?Please provide an authentication key name: $USAGE}
SCP_FILES="apply_tc_rules.sh Dockerfile ndt_e2e.sh ndt/src/node_tests/ndt_client.js operator script_exporter script-exporter.yml"
IMAGE_TAG="m-lab/prometheus-script-exporter"
GCE_ZONE="us-central1-a"
GCE_NAME="script-exporter"
GCE_IP_NAME="script-exporter-public-ip"
GCE_IMG_PROJECT="cos-cloud"
GCE_IMG_FAMILY="cos-stable"

# Add gcloud to PATH.
source "${HOME}/google-cloud-sdk/path.bash.inc"

# Add m-lab/travis help lib
source "$TRAVIS_BUILD_DIR/travis/gcloudlib.sh"

# Set the project and zone for all future gcloud commands.
gcloud config set project $PROJECT
gcloud config set compute/zone $GCE_ZONE

# Authenticate the service account using KEYNAME.
activate_service_account "${KEYNAME}"

# Make sure that the files we want to copy actually exist.
for scp_file in ${SCP_FILES}; do
  if [[ ! -f "${TRAVIS_BUILD_DIR}/${scp_file}" ]]; then
    echo "Missing required file: ${TRAVIS_BUILD_DIR}/${scp_file}!"
    exit 1
  fi
done

# Delete the existing GCE instance, if it exists. gcloud has an exit status of 0
# whether any instances are found or not. When no instances are found, a short
# message is echoed to stderr. When an instance is found a summary is echoed to
# stdout. If $EXISTING_INSTANCE is not null then we infer that the instance
# already exists.
EXISTING_INSTANCE=$(gcloud compute instances list --filter "name=${GCE_NAME}")
if [[ -n "${EXISTING_INSTANCE}" ]]; then
  gcloud compute instances delete $GCE_NAME --quiet
fi

# Create the new GCE instance. NOTE: $GCE_IP_NAME *must* refer to an existing
# static external IP address for the project.
gcloud compute instances create $GCE_NAME --address $GCE_IP_NAME \
  --image-project $GCE_IMG_PROJECT --image-family $GCE_IMG_FAMILY

# Copy required snmp_exporter files to the GCE instance.
gcloud compute scp $SCP_FILES $GCE_NAME:~

# Apply the traffic shaping rules (via tc) on the instance
gcloud compute ssh $GCE_NAME --command "bash apply_tc_rules.sh"

# Build the snmp_exporter Docker container.
gcloud compute ssh $GCE_NAME --command "docker build -t ${IMAGE_TAG} ."

# Start a new container based on the new/updated image
gcloud compute ssh $GCE_NAME --command "docker run -p 9172:9172 -d ${IMAGE_TAG}"
