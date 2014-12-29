#!/bin/bash
# Backup of Fortigate

icinga2core=icinga2core.stxt.media.int

function usage {
   echo "usage:"
   echo "-H Fortigate Host"
   echo "-i Identification for ssh login"
   echo "-u User for backup"
   echo "-p Path; where to save backups"
   exit 3
}

# Catch Arguments
while getopts ":H:i:p:u:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "i")
      key=$OPTARG
      ;;
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

destfilename="$path/$host/config_$(date +%Y%m%d-%H%M%S).cfg"

# save backup on icinga2Core
ssh root@$icinga2core -q -o UserKnownHostsFile=/dev/null -o LogLevel=Error -o BatchMode=yes -o StrictHostKeyChecking=no << EOF | > /dev/null 2>&1
if [ ! -d $path/$host ]
then
  mkdir -p $path/$host
fi
scp -i $key -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$host:sys_config $destfilename 
EOF

#Check if file written and not empty
if ssh -q root@$icinga2core test -e $destfilename;
then 
  echo OK - Last Backup performed at $(date +%Y-%m-%d-%H:%M:%S)
  exit 0
else 
  echo Error - Backup Job failed at $(date +%Y-%m-%d-%H:%M:%S)
  exit 2
fi
