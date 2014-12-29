#!/bin/bash

# Argument Parsing
function usage {
   echo "usage:"
   echo "-H Fortigate Host"
   echo "-i Identification for ssh login"
   echo "-u User for backup"
   echo "-p Path; where to save backups"
   exit 3
}

# Catch Arguments
while getopts ":H:i:p:u" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "i")
      key=$OPTARG
    "p")
      path=$OPTARG
      ;;
    "u")
      user=$OPTARG
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


if [ ! -e $path ]
then
  mkdir $path
fi

/usr/bin/scp -i $key -B -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$host:sys_config $path/$host/date +%Y-%m-%d:%H:%M:%S.cfg

