#!/bin/bash

okcount=0
errorcount=0
warning=70
critical=80

function usage {
   echo "usage:"
   echo "Checks if hosts are reachable"
   echo "-H List of Hosts, comma seperated"
   echo "-w Warning Level in %, default is 70% up"
   echo "-c Critical Level in %, default is 80% up"
   exit 3
}

if (($# == 0)); then
   usage
   exit 2
fi

# Catch Arguments
while getopts ":H:w:c:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "w")
      warning=$OPTARG
      ;;
    "c")
      critical=$OPTARG
      ;;
    "e")
      command=$OPTARG
      ;;
    "?")
      echo "Unknown option $OPTARG"
      usage
      ;;
    ":")
      echo "No argument value for option $OPTARG"
      usage
      exit 2
      ;;
    *)
      #Should not occur
      echo "Unknown error while processing options"
      usage
      ;;
  esac
done

for i in ${host//,/ } ; do 
  if $command ; then
    okcount=$((okcount+1))
  else
    errorcount=$((errorcount+1))
  fi
done

sum=$((okcount + errorcount))
ratio=$( echo "$okcount*100/$sum"|bc )

if [ "$ratio" -lt "$critical" ]; then
   echo "Critical - $ratio% Servers are Online, $errorcount of $sum  Servers are Offline | avail=$ratio%"
   exit 2
elif [ "$ratio" -lt "$warning" ]; then
   echo "Warning - $ratio% Servers are Online, $errorcount of $sum Servers are Offline | avail=$ratio%"
   exit 1
else
   echo "OK - $ratio% Servers are Online, $errorcount of $sum Servers are Offline | avail=$ratio%"
   exit 0
fi
