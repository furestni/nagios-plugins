#!/bin/bash

#Warning Levels
warninglevel=95
criticallevel=98

#config file
isiloncfgpath=/etc/icinga/dynamic/

#ExcludeFilter
excludefilter=''


for hostname in Isilon-ix-SmartConnect.stxt.media.int Isilon-cu01-SmartConnect.stxt.media.int
do

if [ ! -s $config_file ]
then
   echo -e "object Host $hostname { 
   import \"generic-host-pnp\"
   address == $hostname " >  $config_file
   }
fi

if [ $hostname == "Isilon-ix-SmartConnect.stxt.media.int" ]
then
  servicelist=$( ssh root@isilon-ix-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }'  )
else
  servicelist=$( ssh root@isilon-cu01-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }' )
fi

if [[ ! -z $servicelist ]]
then
   echo "" >  $isiloncfgpath/$hostname.cfg
fi

for y in $servicelist
do 
   echo -e "apply service "Isilon_share $y{
   import \"generic-service\"
   vars.sla = \"24x7\"
   check_command \t check_by_ssh! -l root -t 30 -C \"/bin/bash /ifs/data/nagios/isilon-quota-usage.sh -p $y -w $warninglevel -c $criticallevel\"
    }" >> $isiloncfgpath/$hostname.cfg
   done
done

chown icinga.icinga $isiloncfgpath
