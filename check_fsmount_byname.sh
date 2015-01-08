#!/bin/bash


function usage {
   echo "usage:"
   echo "Checks if hosts are reachable"
   echo "-H: Host"
   echo "-C: Community"
   echo "-m: NFS mount to check"
   exit 3
}

if (($# == 0)); then
   usage
   exit 2
fi

# Catch Arguments
while getopts ":H:m:C:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "m")
      mount=$OPTARG
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
      exit 2
      ;;
    *)
      #Should not occur
      echo "Unknown error while processing options"
      usage
      ;;
  esac
done


varcel=`/usr/bin/snmpwalk -v 1 $host -c $community 1.3.6.1.2.1.25.2.3.1.3 | grep -o $mount`;

if [ "$?" -eq "0" ]
  then
  echo "Check OK, filesystem $varcel is available"
  exit 0;
else
  echo "Error, $varcel not available"
  exit 1
fi

