#!/bin/bash
#
# A basic invocation of the wehe-cmdline client.
#
# NOTE: This script will not work as is, as it is missing various required
# flags. It is meant to be called by the monitoring-token command inside of the
# script-exporter container, where additional flags will be passed in ($@) as
# necessary.

java -jar wehe-cmdline/wehe-cmdline.jar -m $MONITORING_URL $@

