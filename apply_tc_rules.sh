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

# Be sure that at least a reasonable number of IPs were discovered in
# hostnames.json. For example, at the time of this comment there are 528 NDT
# IPv4 addresses. This just ensures that a truncated or misconfigured file
# doesn't cause a majority of NDT servers to get marked as offline.
if [[ "$( echo $NDT_IPS | wc -w)" -lt 400 ]] ; then
  echo "Not enough NDT IPs were discovered in hostnames.json. Exiting."
  exit 1
fi

#
# First, erase all existing configurations.
#
tc qdisc del dev eth0 root
tc qdisc del dev eth0 ingress 

#
# Add root queues.
#
tc qdisc add dev eth0 root handle 1: htb default 1
tc qdisc add dev eth0 handle ffff: ingress

#
# Configure classes. Default class egress queue gets 1Gbps, while slowed-down
# classes get only 1Mbps, which should hopefully be a sufficient pipe for any
# concurrent NDT E2E tests that may happen.
# 
tc class add dev eth0 parent 1: classid 1:1 htb rate 1000mbit
tc class add dev eth0 parent 1: classid 1:10 htb rate 5mbit

#
# Configure filters
#
# Add filters for each NDT IP address. egress traffic matching a destination IP
# address of an NDT experiment gets queued into class id 1:10.  ingress traffic
# with a source IP matching one of the NDT slivers gets policed at 50Kbps.

for ip in $NDT_IPS; do
    tc filter add dev eth0 parent 1: protocol ip prio 1 \
        u32 match ip dst ${ip} flowid 1:10
    tc filter add dev eth0 parent ffff: protocol ip prio 1 \
        u32 match ip src ${ip} police rate 50kbps burst 10k drop
done
