#!/bin/bash

function usage {
   echo "usage:"
   echo "Checks if hosts are reachable"
   echo "-H List of Hosts, comma seperated"
   echo "-w Warning Level in %"
   echo "-c Critical Level in %"
   echo "-p Path; where to save backups"
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

okcount=0
errorcount=0

for i in ${host//,/ } ; do 
  if ping -c 1 -W 3 $i 2>&1 >/dev/null ; then
    okcount=$((okcount+1))
  else
    errorcount=$((errorcount+1))
  fi
done

if [ "$errorcount" -gt "0" ]; then
   echo "Failed - $okcount Servers are Online, $errorcount Servers are Offline"
   exit 2
else
   echo "OK - $okcount Servers are Online, $errorcount Servers are Offline"
   exit 0
fi
