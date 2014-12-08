#!/bin/bash

dir=/var/fwbackup/$1

backfile=$(find $dir -mtime -1 -type f)

if [ -z "$backfile" ] ; then
   echo "Error no Backup found today"
   exit 2
else
   echo "OK, Last Backup `stat -c %y $backfile | awk -F '.' '{print $1}'`"
   exit 0
fi

