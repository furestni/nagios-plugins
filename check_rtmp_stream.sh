#!/bin/bash

function usage {
   echo "usage:"
   echo "Checks if hosts are reachable"
   echo "-H Host"
   echo "-p Path"
   exit 3
}

if (($# == 0)); then
   usage
   exit 2
fi

# Catch Arguments
while getopts ":H:p:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "p")
      path=$OPTARG
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




REQUEST=$(/usr/bin/rtmpdump -o /dev/null -q -B 1 -r rtmp://$host$path)
returncode=$?

if [ "$returncode" -eq "0" ]
  then
  echo "Check OK, Stream $path is available"
elif [ "$returncode" -eq "1" ]
  then
  echo "Warning, Problem with Stream $path"
elif [ "$returncode" -eq "3" ]
  then
  echo "Status Stream $path unknown"
else
  echo "Error, Stream $path not available"
fi

exit $returncode
