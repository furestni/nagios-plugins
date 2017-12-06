#!/bin/bash

FILEDIR="./" 
DC=""
CRIT="1"
WARN="2"

while getopts "d:c:w:p:" opt; do
  case $opt in
    d)
		DC=$OPTARG
      ;;
    c)
		CRIT=$OPTARG
      ;;
    w)
		WARN=$OPTARG
	  ;;
    p)
		FILEDIR=$OPTARG
	  ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

awk -F: '
$1 ~ /^computeBlade_/ { total ++ }
$1 ~ /^computeBlade_/ && $2 ~ "unassociated" { unassociated++ } 
$1 ~ /^computeBlade_/ && $2 ~ "ok" { ok++ } 

END { 
	if (unassociated <= '$CRIT')   { rc=2; state="critical"; } 
	else if (unassociated <= '$WARN') { rc=1; state="warning";  }
   	else { rc=0; state="OK";}
	printf "Blade capacity %s total=%d used=%d free=%d | total=%d used=%d free=%d\n", state, total, ok, unassociated, total, ok, unassociated; 
	exit rc
} 
' ${FILEDIR}/ucs_${DC}_inventory*.txt 2>&1
rc=$?
exit $rc
