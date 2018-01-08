#!/bin/bash

MLABCONFIG=~/operator/plsync/mlabconfig.py

if [ ! -x "$MLABCONFIG" ]; then
    echo "Could not find mlabconfig.py or is it not executable. Exiting."
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
	
# Extract NDT sliver IPs from mlabconfig.py output
NDT_IPS=$($MLABCONFIG --format=hostips | egrep '^ndt\.iupui')

#
# Configure filters
#
# Add filters for each NDT IP address. egress traffic mathing a destination IP
# address of an NDT sliver gets queued into class id 1:10.  ingress traffic
# with a source IP matching one of the NDT slivers gets policed at 50Kbps.

for sliver in $NDT_IPS; do
    SLIVER_IP=$(echo $sliver | cut -d',' -f 2)    
    echo $SLIVER_IP
    tc filter add dev eth0 parent 1: protocol ip prio 1 \
        u32 match ip dst $SLIVER_IP flowid 1:10
    tc filter add dev eth0 parent ffff: protocol ip prio 1 \
        u32 match ip src $SLIVER_IP police rate 50kbps burst 10k drop
done
