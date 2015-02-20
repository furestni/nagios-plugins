#!/bin/bash
#Dieses Skript wurde erstellt um die Geschwindigkeit des FTP Servers zu testen
#Momentan ist kein Error handling implementiert

var=`ftp -vn << EOF 
open ftp.sf.tv
user swisstxt_livecenter l!v3cNtr
lcd /tmp/
put testfile_1M.dd
del testfile_1M.dd
EOF` 

var2=`echo $var | egrep -o '[0-9]\.[0-9]*.sec' | sed s/sec//`
echo "Transfer time $var2 seconds | sec=$var2"

