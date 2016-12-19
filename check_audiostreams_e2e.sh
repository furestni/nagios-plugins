#!/bin/bash

function usage {
   echo "usage:"
   echo "-t type [icecast/wowza]"
   exit 3
}

# Catch Arguments
while getopts ":t:" optname
do
  case "$optname" in
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

#Variable init
okcount=0
errcount=0
wrncount=0
unkncount=0
pluginpath="/usr/lib64/nagios/plugins"

#Streams for icecast
if [ "$type" == "icecast" ]; then
   stream_list="\
  /m/couleur3/aacp_32 \
  /m/couleur3/aacp_96 \
  /m/couleur3/mp3_128 \
  /m/drs1/aacp_32 \
  /m/drs1/aacp_96 \
  /m/drs1/mp3_128 \
  /m/drs2/aacp_32 \
  /m/drs2/aacp_96 \
  /m/drs2/mp3_128 \
  /m/drs3/aacp_32 \
  /m/drs3/aacp_96 \
  /m/drs3/mp3_128 \
  /m/drs4news/aacp_32 \
  /m/drs4news/aacp_96 \
  /m/drs4news/mp3_128 \
  /m/drsmw/aacp_32 \
  /m/drsmw/aacp_96 \
  /m/drsmw/mp3_128 \
  /m/drsvirus/aacp_32 \
  /m/drsvirus/aacp_96 \
  /m/drsvirus/mp3_128 \
  /m/espace-2/aacp_32 \
  /m/espace-2/aacp_96 \
  /m/espace-2/mp3_128 \
  /m/la-1ere/aacp_32 \
  /m/la-1ere/aacp_96 \
  /m/la-1ere/mp3_128 \
  /m/option-musique/aacp_32 \
  /m/option-musique/aacp_96 \
  /m/option-musique/mp3_128 \
  /m/regi_ag_so/aacp_32 \
  /m/regi_ag_so/aacp_96 \
  /m/regi_ag_so/mp3_128 \
  /m/regi_be_fr_vs/aacp_32 \
  /m/regi_be_fr_vs/aacp_96 \
  /m/regi_be_fr_vs/mp3_128 \
  /m/regi_bs_bl/aacp_32 \
  /m/regi_bs_bl/aacp_96 \
  /m/regi_bs_bl/mp3_128 \
  /m/regi_ost/aacp_32 \
  /m/regi_ost/aacp_96 \
  /m/regi_ost/mp3_128 \
  /m/regi_zentr/aacp_32 \
  /m/regi_zentr/aacp_96 \
  /m/regi_zentr/mp3_128 \
  /m/regi_zh_sh/aacp_32 \
  /m/regi_zh_sh/aacp_96 \
  /m/regi_zh_sh/mp3_128 \
  /m/retedue/aacp_32 \
  /m/retedue/aacp_96 \
  /m/retedue/mp3_128 \
  /m/retetre/aacp_32 \
  /m/retetre/aacp_96 \
  /m/retetre/mp3_128 \
  /m/reteuno/aacp_32 \
  /m/reteuno/aacp_96 \
  /m/reteuno/mp3_128 \
  /m/rr/aacp_32 \
  /m/rr/aacp_96 \
  /m/rr/mp3_128 \
  /m/rsc_de/aacp_32 \
  /m/rsc_de/aacp_96 \
  /m/rsc_de/mp3_128 \
  /m/rsc_fr/aacp_32 \
  /m/rsc_fr/aacp_96 \
  /m/rsc_fr/mp3_128 \
  /m/rsc_it/aacp_32 \
  /m/rsc_it/aacp_96 \
  /m/rsc_it/mp3_128 \
  /m/rsj/aacp_32 \
  /m/rsj/aacp_96 \
  /m/rsj/mp3_128 \
  /m/rsp/aacp_32 \
  /m/rsp/aacp_96 \
  /m/rsp/mp3_128"
  command="$pluginpath/check_ice -p 80 -H streaming.swisstxt.ch -p 80 -m"

#
#/m/rts_event/aacp_32 \
#/m/rts_event/aacp_96 \
#/m/rts_event/mp3_128 \
#/m/rsi_event/aacp_32 \
#/m/rsi_event/aacp_96 \
#/m/rsi_event/mp3_128 \
#/m/rr_event/aacp_32 \
#/m/rr_event/aacp_96 \
#/m/rr_event/mp3_128 \
#/m/drs_event/aacp_32 \
#/m/drs_event/aacp_96 \
#/m/drs_event/mp3_128 \
#

elif [ "$type" == "wowza" ]; then
   stream_list="\
   /live/drs2.32.stream \
   /live/drs2.96.stream \
   /live/drs3.32.stream \
   /live/drs3.96.stream \
   /live/drs4news.32.stream \
   /live/drs4news.96.stream \
   /live/drsmw.32.stream \
   /live/drsmw.96.stream
   /live/rr.32.stream \
   /live/rr.96.stream \
   /live/drsvirus.32.stream \
   /live/drsvirus.96.stream \
   /live/espace-2.32.stream \
   /live/espace-2.96.stream \
   /live/la-1ere.32.stream \
   /live/la-1ere.96.stream \
   /live/option-musique.32.stream \
   /live/option-musique.96.stream \
   /live/regi_ag_so.32.stream \
   /live/regi_ag_so.96.stream \
   /live/regi_bs_bl.32.stream \
   /live/regi_bs_bl.96.stream \
   /live/regi_be_fr_vs.32.stream \
   /live/regi_be_fr_vs.96.stream \
   /live/regi_ost.32.stream \
   /live/regi_ost.96.stream \
   /live/regi_zentr.32.stream \
   /live/regi_zentr.96.stream \
   /live/regi_zh_sh.32.stream \
   /live/regi_zh_sh.96.stream \
   /live/rsj.32.stream \
   /live/rsj.96.stream \
   /live/rsp.32.stream \
   /live/rsp.96.stream \
   /live/rsc_de.32.stream \
   /live/rsc_de.96.stream \
   /live/rsc_fr.32.stream \
   /live/rsc_fr.96.stream \
   /live/rsc_it.32.stream \
   /live/rsc_it.96.stream \
   /live/reteuno.32.stream \
   /live/reteuno.96.stream \
   /live/retedue.32.stream \
   /live/retedue.96.stream \
   /live/retetre.32.stream \
   /live/retetre.96.stream \
   /live/couleur3.32.stream \
   /live/couleur3.96.stream \
   /live/drs_event.32.stream \
   /live/drs_event.96.stream \
   /live/rts_event.32.stream \
   /live/rts_event.96.stream \
   /live/rsi_event.32.stream \
   /live/rsi_event.96.stream \
   /live/rr_event.32.stream \
   /live/rr_event.96.stream"
   command="$pluginpath/check_rtmp_stream.sh -H rtmp.streaming.swisstxt.ch -p"
fi

#Perform the check for each stream
for stream in $stream_list
do
   $command $stream > /dev/null 2>&1

   if [ "$?" -eq "0" ];then
      (( okcount++ ))
   elif [ "$?" -eq "1" ];then
      (( wrncount++ ))
   elif [ "$?" -eq "2" ];then
      (( errcount++ ))
   else
      (( unkncount++ ))
   fi
done

echo "Stream Statistics: $okcount, Warning: $wrncount, Error: $errcount, Unknown: $unkncount | ok=$okcount warning=$wrncount error=$errcount unknown=$unkncount"

if [ "$errcount" -gt "0" ]; then
   exit 2
elif [ "$wrncount" -gt "0" ]; then
   exit 1
elif [ "$unkncount" -gt "0" ]; then
   exit 3
else
   exit 0
fi

