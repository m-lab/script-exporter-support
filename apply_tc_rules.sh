#!/bin/bash

set -euo pipefail

# Fetch siteinfo hostnames.json and extract all NDT IPs.
NDT_IPS=$(curl -s https://siteinfo.mlab-oti.measurementlab.net/v1/sites/hostnames.json | \
    jq -r '.[] | select(.hostname | match("ndt.iupui.*")) | .ipv4')

# If fetching hostnames.json or parsing it produces an error or a null list of
# IPs, then exit now.
if [[ "$?" -ne "0" ]] || [[ -z "${NDT_IPS}" ]]; then
  echo "Failed to extract NDT IPs from hostnames.json."
  exit 1
fi

#
# Add root queues.
#
tc qdisc add dev eth0 root handle 1: htb default 1 || :
tc qdisc add dev eth0 handle ffff: ingress || :

#
# Configure classes. Default class egress queue gets 1Gbps, while slowed-down
# classes get only 5Mbps, which should hopefully be a sufficient pipe for any
# concurrent NDT E2E tests that may happen.
# 
tc class add dev eth0 parent 1: classid 1:1 htb rate 1000mbit || :
tc class add dev eth0 parent 1: classid 1:10 htb rate 5mbit || :

#
# Configure filters
#
# Add filters for each NDT IP address. egress traffic matching a destination IP
# address of an NDT experiment gets queued into class id 1:10.  ingress traffic
# with a source IP matching one of the NDT slivers gets policed at 50Kbps.
egress_filters=$(tc filter show dev eth0 parent 1:)
ingress_filters=$(tc filter show dev eth0 parent ffff:)

for ip in $NDT_IPS; do
  HEX_IP=$(printf '%02x' ${ip//./ })
  # Only add the egress filter for this IP if it doesn't already exist.
  if ! echo "${egress_filters}" | grep "${HEX_IP}"; then
    tc filter add dev eth0 parent 1: protocol ip prio 1 \
        u32 match ip dst ${ip} flowid 1:10
  fi
  # Only add the ingress filter for this IP if it doesn't already exist.
  if ! echo "${ingress_filters}" | grep "${HEX_IP}"; then
    tc filter add dev eth0 parent ffff: protocol ip prio 1 \
        u32 match ip src ${ip} police rate 50kbps burst 10k drop
  fi
done
