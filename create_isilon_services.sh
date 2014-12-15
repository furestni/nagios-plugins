#!/bin/bash

#Warning Levels
warninglevel=95
criticallevel=98

#config file
isiloncfgpath=/etc/icinga/isilon/

#ExcludeFilter
excludefilter=''


for hostname in Isilon-ix-SmartConnect Isilon-cu01-SmartConnect
do


if [ ! -s $config_file ]
then
   echo "" >  $config_file
fi

if [ $hostname == "Isilon-ix-SmartConnect" ]
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
   echo -e "define service {
   host_name \t\t $hostname
   service_description \t isilon_share $y
   display_name \t isilon_share $y
   use \t\t\t Generic-Service,service-pnp
   check_command \t check_by_ssh! -l root -t 30 -C \"/bin/bash /ifs/data/nagios/isilon-quota-usage.sh -p $y -w $warninglevel -c $criticallevel\"
   register \t\t 1
    }" >> $isiloncfgpath/$hostname.cfg
   done
done

chown icinga.icinga $isiloncfgpath
