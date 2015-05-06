#!/bin/bash
# Backup of Fortigate

icinga2core=icinga2core.stxt.media.int
sshoptions="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=Error -o BatchMode=yes"

function usage {
   echo "usage:"
   echo "-H Fortigate Host"
   echo "-t type fortigate or nexus"
   echo "-i Identification for ssh login"
   echo "-u User for backup"
   echo "-p Path; where to save backups"
   exit 3
}

# Catch Arguments
while getopts ":H:i:p:u:t:" optname
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
    "t")
      type=$OPTARG
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

destfilename="$path/config_$(date +%Y%m%d-%H%M%S).cfg"

# save backup on icinga2Core
ssh root@$icinga2core $sshoptions << EOF | > /dev/null 2>&1
if [ ! -d $path ]
then
  mkdir -p $path
fi
if [ "$type" = "fortigate" ]
then
   scp -i $key $sshoptions $user@$host:sys_config $destfilename 
elif [ "$type" = "cisco" ]
then
   ssh -i $key $sshoptions $user@$host -C 'show run' > $destfilename
fi
EOF

#Check if file written and not empty
if ssh -q root@$icinga2core $sshoptions test -s $destfilename;
then 
  echo OK - Last Backup performed at $(date +%Y-%m-%d-%H:%M:%S)
  exit 0
else 
  echo Error - Backup Job failed at $(date +%Y-%m-%d-%H:%M:%S)
  exit 2
fi
