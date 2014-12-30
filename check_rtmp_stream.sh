#!/bin/bash

REQUEST=$(/usr/bin/rtmpdump -o /dev/null -q -B 1 -r rtmp://$1$2)
returncode=$?

if [ "$returncode" -eq "0" ]
  then
  echo "Check OK, Stream $2 is available"
elif [ "$returncode" -eq "1" ]
  then
  echo "Warning, Problem with Stream $2"
elif [ "$returncode" -eq "3" ]
  then
  echo "Status Stream $2 unknown"
else
  echo "Error, Stream $2 not available"
fi

exit $returncode
