#!/usr/bin/env bash

# Return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_QUEUEING=5

if [[ -z "$TARGET" ]] ; then
    echo 'ERROR: must define TARGET from environment'
    exit $STATE_CRITICAL
fi

if [[ -z "$EXPERIMENT" ]] ; then
    echo 'ERROR: must define EXPERIMENT from environment'
    exit $STATE_CRITICAL
fi

if [[ -z ${1} ]]; then
    echo "ERROR: missing TTL for command (arg 1)"
    exit $STATE_CRITICAL
fi

if [[ -z ${2} ]]; then
    echo "ERROR: missing command to run (arg 2)"
    exit $STATE_CRITICAL
fi

if [[ "$LOGX_DEBUG" == "true" ]] ; then
    # Enable additional execution logs for debugging.
    set -x
    exec 1> /tmp/${TARGET}.log 2>&1
fi

set -u

# Max age (in seconds) to use a cached command result before running the
# command again.
MAX_CACHE_AGE=${1}

# Where to store cached exit codes from the given command.
CACHE_DIR=/tmp/cache-${EXPERIMENT}

# If the $CACHE_DIR doesn't exist create it.
if [[ ! -d $CACHE_DIR ]]; then
    mkdir -p $CACHE_DIR
fi

CACHE_STATUS=$(cat $CACHE_DIR/$TARGET 2> /dev/null)

# If the cached status for this $TARGET was successful and the mtime of
# the cache file is less than $MAX_CACHE_AGE, then return $STATE_OK.
if [[ -n "$CACHE_STATUS" ]]; then
    if [[ "$CACHE_STATUS" -eq "$STATE_OK" ]]; then
        file_age=$(expr $(date +%s) - $(stat --printf "%Y" $CACHE_DIR/$TARGET ))
        if [[ "$file_age" -lt $MAX_CACHE_AGE ]]; then
            exit $STATE_OK
        fi
    fi
fi

shift 1  # Remove first parameter.
# Run command.
OUTPUT=$( $@ )
STATUS=$?

# Cache result.
echo $STATUS > $CACHE_DIR/$TARGET

# To help distribute the cache expiration randomly (and the command execution),
# we unconditionally set the cache file's mtime from 1 second to $MAX_CACHE_AGE
# seconds into the past. This means that the next command will run sooner,
# but it will also cause the cached statuses to expire at random times,
# distributing the command execution times uniformly.
RAND=$(($RANDOM % $MAX_CACHE_AGE))
touch --date "${RAND} seconds ago" $CACHE_DIR/$TARGET

if [ "$STATUS" -eq "0" ]; then
    exit $STATE_OK
else
    exit $STATE_CRITICAL
fi
