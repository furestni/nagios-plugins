#!/bin/bash
# Monitor Sotschi Stream
# Alarming when not available

tmpfile="/tmp/hbbtv_srg_$1"
rm -f $tmpfile

curl -o $tmpfile http://streaming.hbbtv.swisstxt.ch/srg/$1 -m 4 > /dev/null 2>&1

# Check if Warning or Critical
if [ ! -f $tmpfile ] ; then
  echo "Stream $1 does not exist"
  exitvalue=2
elif [ !  -s $tmpfile ] ; then
  echo "Stream $1; empty " 
  exitvalue=2
else
  echo "Stream $1 OK"
  exitvalue=0
fi

exit $exitvalue
