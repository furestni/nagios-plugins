#!/bin/sh

stations=( drs1 drs2 drs3 drs4news drsmw rr drsvirus espace-2 la-1ere option-musique regi_ag_so regi_bs_bl regi_be_fr_vs regi_ost regi_zentr regi_zh_sh rsj rsp rsc_de rsc_fr rsc_it reteuno retedue retetre couleur3 drs_event rts_event rsi_event rr_event regi_gr )
qualities=(32 96)
host=$2
url_base="http://"$host"/audio/"
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
      content="$(curl -s "$url")"
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
    echo "Problems in "$error" of "$count" streams"
    exit 2
  else
    echo "Streams OK"
    exit 0
  fi
}

function checkDVR
{
  for i in ${stations[@]}; do
    for q in ${qualities[@]}; do
      url=$url_base$i"_"$q$url_playlist
      content="$(curl -s "$url")"
      segment_num="$(echo "$content" | grep aac -c)"
      perfdata=$perfdata$delimiter$i"_"$q"="$segment_num
      if [[ $segment_num < 4950  ]]; then
        error=$((error+1))
      fi
      count=$((count+1))
      delimiter=";"
    done
  done
  echo "Stations OK: "$((count-error))"/"$count"\|"$perfdata
  if [[ $error > 0 ]]; then
    exit 2
  else
    exit 0
  fi
}

while [ "$1" != "" ]; do
  case $1 in
   checkDVR )               shift
                            checkDVR
                            ;;
   checkActuallity )        checkActuallity
                            ;;
   * )                      echo "use checkDVR or checkActuallity and Host-IP"
                            ;;
   esac
   shift
done
