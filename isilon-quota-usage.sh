#!/bin/bash


# Argument Parsing
function usage {
   echo "usage:"
   echo "-p [isilon share]"
   echo "-w [warning]"
   echo "-c [critical]"
   exit 3
}


# Catch Arguments
while getopts ":p:w:c:" optname
do
  case "$optname" in
    "p")
      path=$OPTARG
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
      ;;
    *)
      #Should not occur
      echo "Unknown error while processing options"
      usage
      ;;
  esac
done


#Disable nagios alerts if warning and critical limits are both set to 0 (zero)
if [ $warning -eq 0 ]
 then
  if [ $critical -eq 0 ]
   then
    ALERT=false
  fi
fi

#Ensure warning is greater than critical limit
if [ $critical -lt $warning ]
 then
  echo "Please ensure critial is greater than warning"
  exit 3
fi

# Ensure that isi is installed
if [ ! -e /usr/bin/isi ]
 then
  echo "isi tool not installed, are you on the isilon smart connect plattform?"
  exit 3
fi

NAME=`echo $path`

case "`echo ${NAME}`" in
'ev')
USAGE=`isi quota ls |grep "${NAME} "|awk '{ print $2, $6, $NF }'`
;;
'home')
USAGE=`isi quota ls |grep "${NAME} "|awk '{ print $2, $6, $NF }'`
;;
'nfs')
USAGE=`isi quota ls |grep "${NAME} "|awk '{ print $2, $6, $NF }'`
;;
'vmware')
USAGE=`isi quota ls |grep "${NAME} "|awk '{ print $2, $6, $NF }'`
;;
*)
USAGE=`isi quota ls | grep "${NAME} " | awk '{ print $3, $5, $NF }'`
;;
esac

# Unit Calculations
QUOTA=`echo "$USAGE"|awk '{print $2}'|sed -e 's/[a-zA-Z]//g'`
QUOTA_UNIT=`echo "$USAGE"|awk '{print $2}'|sed -e 's/[0-9.]//g'`
USED=`echo "$USAGE"|awk '{print $3}'|sed -e 's/[a-zA-Z]//g'`
USED_UNIT=`echo "$USAGE"|awk '{print $3}'|sed -e 's/[0-9.]//g'`

if [ ${USED:0:1} == '~' ]
 then
  echo "WARNING - still calculating"
  exit 1
fi

case "`echo ${USED_UNIT}`" in
'b')
USED_GB=0
;;
'K')
USED_GB=0
;;
'G')
USED_GB=$USED
;;
'M')
USED_GB=$(bc << EOF
scale = 2
$USED / 1024
EOF
)
;;
'T')
USED_GB=$(bc << EOF
scale = 1
$USED * 1024
EOF
)
;;
esac

case "`echo ${QUOTA_UNIT}`" in
'b')
USED_GB=0
;;
'b')
USED_GB=0
;;
'G')
QUOTA_GB=$QUOTA
;;
'M')
QUOTA_GB=$(bc << EOF
scale = 2
$QUOTA / 1024
EOF
)
;;
'T')
QUOTA_GB=$(bc << EOF
scale = 1
$QUOTA * 1024
EOF
)
;;
esac

FREE_GB=$(bc << EOF
($QUOTA_GB - $USED_GB)
EOF
)
FREE_GB2=`echo "$FREE_GB"|awk -F. '{print $1}'`

#Debug
#echo $FREE_GB
#echo $FREE_GB2

#Display Quota Usage without alert
if [ "$ALERT" == "false" ]
 then
     		echo "OK - Used = ${USED_GB}G, Quota = ${QUOTA_GB}G, Free = ${FREE_GB}G | QuotaUsage=${USED_GB} ; QuotaTotal=${QUOTA_GB} ; QuotaFree=${FREE_GB}"
                exit 0
 else
        ALERT=true
fi

#Display Quota Usage with alert
PERCENT_USED=$( echo "$USED_GB*100/$QUOTA_GB"|bc )

#if [ $FREE_GB2 -le "$3" ]
if [ $PERCENT_USED -gt "$critical" ]
then
  echo "CRITICAL - Used = ${USED_GB}G, Quota = ${QUOTA_GB}G, Free = ${FREE_GB}G, used=$PERCENT_USED% | used=$PERCENT_USED QuotaUsage=${USED_GB} ; QuotaTotal=${QUOTA_GB} ; QuotaFree=${FREE_GB}"
  exit 2
 else
#  if [ $FREE_GB2 -le "$2" ]
  if [ $PERCENT_USED -gt "$warning"  ]
   then
     echo "WARNING - Used = ${USED_GB}G, Quota = ${QUOTA_GB}G, Free = ${FREE_GB}G, used=$PERCENT_USED% | used=$PERCENT_USED QuotaUsage=${USED_GB} ; QuotaTotal=${QUOTA_GB} ; QuotaFree=${FREE_GB}"
     exit 1
   else
     echo "OK - Used = ${USED_GB}G, Quota = ${QUOTA_GB}G, Free = ${FREE_GB}G, used = $PERCENT_USED% | used=$PERCENT_USED QuotaUsage=${USED_GB} ; QuotaTotal=${QUOTA_GB} ; QuotaFree=${FREE_GB}"
     exit 0
  fi
fi
