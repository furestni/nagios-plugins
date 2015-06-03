#!/bin/bash

# default definitions
ORIGIN_URL="origin.akamai.slacheck.swisstxt.ch"
PUBLIC_URL="akamai.slacheck.swisstxt.ch"
WEBFILE="index.php"

# current timetstamps
remote_timestamp=`curl -s $PUBLIC_URL/$WEBFILE | grep Timestamp | cut -d: -f2 | tr -d ' \n'`
local_timestamp=`date +%s`
let limit_timestamp=local_timestamp-600 # add ten minutes tolerance

# Function to quit
# ($1: STATE (OK, WARNING,...) / $2: Message / $3: Exit-code)
function quit {
	echo $1: $2
	exit $3
}

# First check http response
http_response=`curl -s -o /dev/null -w "%{http_code}" $PUBLIC_URL/$WEBFILE`
if [ $http_response -ne 200 ]; then
	quit "CRITICAL" "akamai delivers $http_response error" 2
fi

# Second check actuality
if [ $limit_timestamp -gt $remote_timestamp ]; then

	# here we have to check if orign is alive
	ping_count=$( ping -c 1 $PUBLIC_URL | grep icmp* | wc -l )

	if [ $ping_count -eq 0 ]; then
		quit "WARNING" "content is out-dated due to dead origin" 1
	else
		quit "CRITICAL" "content is out-dated" 2
	fi
fi

# if not quit until here, everything's okay
quit "OK" "DSD works" 0
