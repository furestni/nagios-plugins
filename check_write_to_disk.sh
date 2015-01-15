#!/bin/bash

#This is stupid scipt to check if write to local disk is possible
#Only needed to fulfill the requested KPI's in the SLA 
#Improvenments are in discussion

output=`/bin/touch /tmp/testfile`

if [ "$?" -eq "0" ]
  then
  echo "Check OK, Storage writable"
  exit 0;
else
  echo "$output"
  exit 2
fi

