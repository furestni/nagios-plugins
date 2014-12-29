#!/bin/bash

#USAGE
#./check_fortigate_uptime.pl {Host} {Community}

snmpget -v1 -c $2 $1 .1.3.6.1.2.1.1.3.0 | grep days > /dev/null
RETVAL=$?

if [ $RETVAL -eq 0 ]
  then
  days=`snmpwalk -v 1 $1 -c $2 .1.3.6.1.2.1.1.3.0 | awk '{print $5}'`
  hours=`snmpwalk -v 1 $1 -c $2 .1.3.6.1.2.1.1.3.0 | awk '{print $7}' | awk -F ':' '{print $1}' | sed 's/^0//'`
  minutes=`snmpwalk -v 1 $1 -c $2 .1.3.6.1.2.1.1.3.0 | awk '{print $7}' | awk -F ':' '{print $2}' | sed 's/^0//'`
  echo "OK Uptime > 1 day:  $days day(s) $hours hour(s) and $minutes minute(s) | day(s)=$days"
  exit 0
else
  days=0
  hours=`snmpwalk -v 1 $1 -c $2 .1.3.6.1.2.1.1.3.0 | awk '{print $5}' | awk -F ':' '{print $1}' | sed 's/^0//'`
  minutes=`snmpwalk -v 1 $1 -c $2 .1.3.6.1.2.1.1.3.0 | awk '{print $5}' | awk -F ':' '{print $2}' | sed 's/^0//'`
  echo "Warning Uptime < 1 day: Uptime $days day(s) $hours hour(s) and $minutes minute(s) | day(s)=$days"
  exit 1
fi


