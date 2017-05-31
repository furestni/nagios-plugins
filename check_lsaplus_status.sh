#!/bin/bash

count=0
okcount=0
errorcount=0
warning=70
critical=80

function usage {
   echo "usage:"
   echo "-H Host"
   echo "-t [checkDVR/checkActuallity]"
   echo "-w Warning Level in %, default is 70% up"
   echo "-c Critical Level in %, default is 80% up"
   exit 3
}

if (($# == 0)); then
   usage
   exit 2
fi

# Catch Arguments
while getopts ":H:t:w:c:" optname
do
  case "$optname" in
    "t")
      type=$OPTARG
      ;;
    "H")
      host=$OPTARG
      ;;
    "w")
      warning=$OPTARG
      ;;
    "c")
      critical=$OPTARG
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

stations=( drs1 drs2 drs3 drs4news drsmw rr drsvirus espace-2 la-1ere option-musique regi_ag_so regi_bs_bl regi_be_fr_vs regi_ost regi_zentr regi_zh_sh rsj rsp rsc_de rsc_fr rsc_it reteuno retedue retetre couleur3 drs_event rts_event rsi_event rr_event regi_gr )
qualities=(32 96)
#url_base="http://"$host"/audio/"
url_playlist=".stream/chunklist_DVR.m3u8"
tmppath="/tmp/lsaplus/"
count=0


function checkActuallity
{
  mkdir -p $tmppath
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      (touch "$tmppath$i"_"$q" || exit)
      laststate="$(cat "$tmppath"$i"_"$q )"
      url=$url_base$i"_"$q$url_playlist
      content="$(curl --compress -s "$url")"
      returncode=$((returncode+$?))
      content="$(echo "$content" | tail -1)"
      if [ "$laststate" == "$content" ]; then
        error=$((error+1))
        perfdata=$perfdata$delimiter$i"_"$q
      elif [[ $returncode > 0 ]]; then
        error=$returncode
      fi
      (echo "$content" > "$tmppath$i"_"$q" )
      count=$((count+1))
      delimiter=", "
    done
  done
  if [[ $error > 0 ]]; then
    #echo "Problems in "$error" of "$count" streams"
    echo 1
  else
    #echo "Streams OK"
    echo 0
  fi
}

function checkDVR
{
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      url=$url_base$i"_"$q$url_playlist
      content="$(curl --compress -s "$url")"
      segment_num="$(echo "$content" | grep aac -c)"
      perfdata=$perfdata$delimiter$i"_"$q"="$segment_num
	  #echo "${i}_${q}: $segment_num" 1>&2
      if [[ $segment_num < 1980  ]]; then
        error=$((error+1))
      fi
      count=$((count+1))
      delimiter=";"
    done
  done
  #echo "Stations OK: "$((count-error))"/"$count"\|"$perfdata
  if [[ $error > 0 ]]; then
    echo 1
  else
    echo 0
  fi
}

if [[ $host == *","* ]]
then
  for i in ${host//,/ } ; do
    url_base="http://"$i"/audio/"

    if [ $type == "checkDVR" ]; then
      errorcount=$((errorcount+$(checkDVR)))
    elif [ $type == "checkActuallity" ]; then
      errorcount=$((errorcount+$(checkActuallity)))
    fi
    count=$((count+1))
  done
else
  url_base="http://"$host"/audio/"
  count=1

  if [ $type == "checkDVR" ]; then
    errorcount=$(checkDVR)
  elif [ $type == "checkActuallity" ]; then
    errorcount=$(checkActuallity)
  fi
fi


okcount=$(($count-errorcount))
ratio=$( echo "$okcount*100/$count"|bc )
if [ "$ratio" -lt "$critical" ]; then
   echo "Critical - $ratio% Servers are Online, $okcount of $count  Servers are Online | avail=$ratio%"
   exit 2
elif [ "$ratio" -lt "$warning" ]; then
   echo "Warning - $ratio% Servers are Online, $okcount of $count Servers are Online | avail=$ratio%"
   exit 1
else
   echo "OK - $ratio% Servers are Online, $okcount of $count Servers are Online | avail=$ratio%"
   exit 0
fi
