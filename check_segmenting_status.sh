#!/bin/bash
# based on check_lsaplus_status
okcount=0
errorcount=0
warning=80
critical=70

function usage {
   echo "usage:"
   echo "-H Host"
   echo "-t [checkDVR|checkActuallity|checkFunctionality]"
   echo "-w Warning Level in %, default is $warning% up"
   echo "-c Critical Level in %, default is $critical% up"
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
url_base="http://"$host"/audio/"
url_playlist=".stream/chunklist_DVR.m3u8"
tmppath="/var/cache/icinga2/check_segmenting_status/"

function checkActuallity
{
  mkdir -p $tmppath
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      (touch "$tmppath$i"_"$q" || exit 3)
      laststate="$(cat "$tmppath"$i"_"$q )"
      url=$url_base$i"_"$q$url_playlist
      content="$(curl --compress -s -f "$url")"
      if [[ $? > 0 ]] ; then
         error=$((error+1))
      else
        content="$(echo "$content" | tail -1)"
        if [ "$laststate" == "$content" ]; then
          error=$((error+1))
        fi
      fi
      (echo "$content" > "$tmppath$i"_"$q" )
    done
  done
  echo $error
}

function checkDVR
{
  error=0
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      url=$url_base$i"_"$q$url_playlist
      content="$(curl --compress -s "$url")"
      segment_num="$(echo "$content" | grep -c aac )"
      if [[ $segment_num < 1980  ]]; then
        error=$((error+1))
      fi
    done
  done
  echo $error
}

function checkFunctionality
{
  error=0
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      url=$url_base$i"_"$q$url_playlist
      content="$(curl --compress -s -f "$url")"
      if [[ $? > 0 ]]; then
        error=$((error+1))
      else
      	content="$(echo "$content" | grep -v '^#' | tail -1)"
		curl -s -f $url_base$i"_"$q".stream/"$content > /dev/null 2>/dev/null || error=$((error+1))
      fi
    done
  done
  echo $error
}

function countStreams
{
   c=0
   for i in ${stations[@]}; do
     for q in ${qualities[@]}; do
       c=$((c+1))
     done
   done
   echo $c
}

if [ $type == "checkDVR" ]; then
  errorcount=$(checkDVR)
elif [ $type == "checkActuallity" ]; then
  errorcount=$(checkActuallity)
elif [ $type == "checkFunctionality" ]; then
  errorcount=$(checkFunctionality)
else 
  echo "unsupported check type"
  exit 3
fi

count=$(countStreams)

okcount=$(($count-errorcount))


ratio=$( echo "$okcount*100/$count"|bc )


if [ "$ratio" -lt "$critical" ]; then
   echo "Critical - $ratio% Streams are Online | avail=$ratio%"
   exit 2
elif [ "$ratio" -lt "$warning" ]; then
   echo "Warning - $ratio% Streams are Online | avail=$ratio%"
   exit 1
else
   echo "OK - $ratio% Streams are Online | avail=$ratio%"
   exit 0
fi
