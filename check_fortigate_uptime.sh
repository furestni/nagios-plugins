#!/bin/bash

oid=.1.3.6.1.2.1.1.3.0

# Argument Parsing
function usage {
   echo "usage:"
   echo "-H Fortigate Host"
   echo "-C Community"
   exit 3
}

# Catch Arguments
while getopts ":H:C:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "C")
      community=$OPTARG
      ;;
    "?")
      echo "Unknown option $OPTARG"
      usage
      ;;
    ":")
      echo "No argument value for option $OPTARG"
      usage
      ;;
    *)
      #Should not occur
      echo "Unknown error while processing options"
      usage
      ;;
  esac
done


output=`snmpget -v1 -c $community $host $oid | grep days > /dev/null`
RETVAL=$?

if [ $RETVAL -eq 0 ]
  then
  days=`echo $output | awk '{print $5}'`
  hours=`echo $output | awk '{print $7}' | awk -F ':' '{print $1}' | sed 's/^0//'`
  minutes=`echo $output | awk '{print $7}' | awk -F ':' '{print $2}' | sed 's/^0//'`
  echo "OK Uptime > 1 day:  $days day(s) $hours hour(s) and $minutes minute(s) | day(s)=$days"
  exit 0
else
  days=0
  hours=`echo $output | awk '{print $5}' | awk -F ':' '{print $1}' | sed 's/^0//'`
  minutes=`echo $output | awk '{print $5}' | awk -F ':' '{print $2}' | sed 's/^0//'`
  echo "Warning Uptime < 1 day: Uptime $days day(s) $hours hour(s) and $minutes minute(s) | day(s)=$days"
  exit 1
fi


