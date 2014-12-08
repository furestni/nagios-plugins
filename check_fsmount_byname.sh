#!/bin/bash

#This is stupid scipt to check if server has the local nfs share mounted

varcel=`/usr/bin/snmpwalk -v 1 $1 -c public 1.3.6.1.2.1.25.2.3.1.3 | grep -o $2`;

if [ "$?" -eq "0" ]
  then
  echo "Check OK, filesystem $varcel is available"
  exit 0;
else
  echo "Error, $varcel not available"
  exit 1
fi

