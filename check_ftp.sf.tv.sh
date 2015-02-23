#!/bin/bash
#Dieses Skript wurde erstellt um die Geschwindigkeit des FTP Servers zu testen
#Momentan ist kein Error handling implementiert

# global vars
PLUGIN_PATH='/usr/lib64/nagios/plugins'
TMP_PATH='/tmp'

# generate file
dd if=/dev/zero of=$TMP_PATH/testfile_1M.dd bs=1024 count=1024 > /dev/null 2>&1

var=`ftp -vn << EOF 
open ftp.sf.tv
user swisstxt_livecenter l!v3cNtr
lcd $TMP_PATH 
put testfile_1M.dd
del testfile_1M.dd
EOF` 

var2=`echo $var | egrep -o '[0-9]\.[0-9]*.sec' | sed s/sec//`
echo "Transfer time $var2 seconds | sec=$var2"

# delete file
rm -rf $TMP_PATH/testfile_1M.dd > /dev/null 2>&1
