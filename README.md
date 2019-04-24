# script-exporter-support

This repo controls the deployment of the github.com/m-lab/script_exporter service to our standard GCP projects: mlab-sandbox, mlab-staging, mlab-oti.

Instead of pulling pre-built images from DockerHub, `deploy_script_exporter.sh` builds the docker image within the GCE VM that will run that version.
