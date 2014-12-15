#!/bin/bash

#Warning Levels
warninglevel=95
criticallevel=98


#ExcludeFilter
excludefilter=''


for hostname in Isilon-ix-SmartConnect.stxt.media.int Isilon-cu01-SmartConnect.stxt.media.int
do

if [ $hostname == "Isilon-ix-SmartConnect.stxt.media.int" ]
then
  servicelist=$( ssh root@isilon-ix-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }'  )
  cfgfile="/etc/icinga2/zones.d/datacenter-ix/isilonshare.cfg"
else
  servicelist=$( ssh root@isilon-cu01-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }' )
  cfgfile="/etc/icinga2/zones.d/datacenter-bie/isilonshare.cfg"
fi


if [ ! -s $cfgfile ]
then
   echo -e "object Host \"$hostname\" { 
   import \"generic-host\"
   address = \"$hostname\"
   } " >  $cfgfile

fi

if [[ ! -z $servicelist ]]
then
   echo "" >  $isiloncfgpath/$hostname.cfg
fi

for y in $servicelist
do 
   echo -e "apply service \"Isilon_share $y\"{
   import \"generic-service-pnp\"
   vars.sla = \"24x7\"

   check_command \t check_by_ssh
   
   vars.user = \"root\" 
   vars.timeout = \"30\"
   vars.command = \"/bin/bash /ifs/data/nagios/isilon-quota-usage.sh -p $y -w $warninglevel -c $criticallevel\"
    } \n " >> $cfgfile
   done
done

chown icinga.icinga $isiloncfgpath
