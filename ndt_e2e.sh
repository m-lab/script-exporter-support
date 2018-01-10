#!/usr/bin/env bash

# Globally installed Node.js modules are here
export NODE_PATH=/usr/lib/node_modules

# Return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

NDT_JS=/opt/mlab/ndt/src/node_tests/ndt_client.js

if [ -n "$1" ]; then
    HOST=$1
else
    echo -n "No host specified."
    exit $STATE_CRITICAL
fi

# If there is no traffic shaping rule in place for this IP address, then refuse
# to run.
IP_ADDR=$(dig $HOST +short)
HEX_IP=$(printf '%02x' ${IP_ADDR//./ })
if ! /sbin/tc filter show dev eth0 | grep -q $HEX_IP; then
    echo -n "No tc filter for this host. Refusing to run."
    exit $STATE_UNKNOWN
fi

OUTPUT=$(nodejs $NDT_JS --quiet --server $HOST)

if [ "$?" -eq "0" ]; then
    echo -n "NDT E2E test succeeded."
    exit $STATE_OK
else
    echo -n "$OUTPUT"
    exit $STATE_CRITICAL
fi
