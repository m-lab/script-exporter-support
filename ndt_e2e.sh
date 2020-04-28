#!/usr/bin/env bash

set -u

# Globally installed Node.js modules are here
export NODE_PATH=/usr/lib/node_modules

# Where to store cached NDT e2e test results
CACHE_DIR=/tmp/ndt-e2e-cache

# Max age (in seconds) to use a cached e2e test result before running the test
# again to refresh the cached value.
MAX_CACHE_AGE="600"

# Return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_QUEUEING=5

# Flags whether this is the first time an e2e test has been run against this
# node since this VM has been running. See comment later in this script to
# understand why this variable exists.
FIRST_RUN=false

NDT_JS=/opt/mlab/ndt/src/node_tests/ndt_client.js

if [ -n "$1" ]; then
    HOST=$1
else
    exit $STATE_CRITICAL
fi

# If the $CACHE_DIR doesn't exist create it.
if [[ ! -d $CACHE_DIR ]]; then
    mkdir $CACHE_DIR
fi

CACHE_STATUS=$(cat $CACHE_DIR/$HOST 2> /dev/null)

# If the cached status for this $HOST is a successful result and the mtime of
# the cache file is less than $MAX_CACHE_AGE, then return $STATE_OK.
if [[ -n "$CACHE_STATUS" ]]; then
    if [[ "$CACHE_STATUS" -eq "$STATE_OK" ]]; then
        file_age=$(expr $(date +%s) - $(stat --printf "%Y" $CACHE_DIR/$HOST))
        if [[ "$file_age" -lt $MAX_CACHE_AGE ]]; then
            exit $STATE_OK
        fi
    fi
else
    # The cache file didn't already exist, so this must be the first run of the
    # e2e test for this node. Flag this for later use.
    FIRST_RUN=true
fi

# If there is no traffic shaping rule in place for this IP address, then refuse
# to run.
IP_ADDR=$(dig $HOST +short)
HEX_IP=$(printf '%02x' ${IP_ADDR//./ })
if ! /sbin/tc filter show dev eth0 | grep -q $HEX_IP; then
    echo $STATE_UNKNOWN > $CACHE_DIR/$HOST
    exit $STATE_UNKNOWN
fi

# Do a queueing check first.
OUTPUT=$(nodejs $NDT_JS --quiet --queueingtest --server $HOST --protocol wss \
  --port 3010 --tests 16 )
STATUS=$?

# If the server isn't queueing, then run the e2e test.
if [[ "$STATUS" -ne "$STATE_QUEUEING" ]]; then
    OUTPUT=$(nodejs $NDT_JS --quiet --server $HOST --protocol wss --port 3010)
    STATUS=$?
fi

echo $STATUS > $CACHE_DIR/$HOST

# If the cache file didn't previously exist, then this is the first run against
# this sliver. In order to help spread out the cache expiration, and hence
# spread out the NDT e2e tests, set the cache file's mtime from 1 second to
# $MAX_CACHE_AGE seconds into the past, randomly. This means that the second
# e2e test will run sooner than normal, but will hopefully cause the cached
# statuses to expire at randomly different times and spread the NDT e2e test
# load across the entire expiration interval.
if [[ $FIRST_RUN = "true" ]]; then
    RAND=$(($RANDOM % $MAX_CACHE_AGE))
    touch --date "${RAND} seconds ago" $CACHE_DIR/$HOST
fi

if [ "$STATUS" -eq "0" ]; then
    exit $STATE_OK
else
    exit $STATE_CRITICAL
fi
