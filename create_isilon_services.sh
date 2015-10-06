#!/bin/bash

#Define Check Levels
warninglevel=95
criticallevel=98

#ExcludeFilter , need to be implemented
excludefilter=''

for hostname in isilon-ix-smartconnect.stxt.media.int isilon-cu01-smartconnect.stxt.media.int
do
  if [ $hostname == "isilon-ix-smartconnect.stxt.media.int" ]
  then
    servicelist=$( ssh root@isilon-ix-smartconnect.stxt.media.int -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q -C "isi quota quotas list --format=csv --no-header --no-footer" | awk -F, '$5 ~ "[[:digit:]]" { print $3 }'  )
    cfgfile="/etc/icinga2/zones.d/zone-ix/isilonshare.conf"
  else
    servicelist=$( ssh root@isilon-cu01-smartconnect.stxt.media.int -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q -C "isi quota quotas list --format=csv --no-header --no-footer" | awk -F, '$5 ~ "[[:digit:]]" { print $3 }' )
    cfgfile="/etc/icinga2/zones.d/zone-bie/isilonshare.conf"
  fi

  if [[ ! -z $servicelist ]]
  then

    # Clear tmp file
    echo "" > $cfgfile.tmp
    
    # Write Services for Smart Connect Host
    for y in $servicelist
    do 
       echo -e "apply Service \"Isilon_share $y\"{
       import \"generic-service-pnp\"
       vars.sla = \"24x7\"

       check_command  = \"check_by_ssh\"
       
       vars.user = \"root\" 
       vars.timeout = \"60\"
       vars.option = [ \"UserKnownHostsFile=/dev/null\", \"StrictHostKeyChecking=no\" ]
       vars.command = \"/bin/bash /ifs/data/nagios/isilon-quota-usage.sh -p $y -w $warninglevel -c $criticallevel\"
       assign where host.address == \"$hostname\"
        } \n " >> $cfgfile.tmp
    done
     
    # check if file exists
    if [ ! -e $cfgfile ]
    then
      touch $cfgfile
    fi

     # Check if modification
    cmp $cfgfile $cfgfile.tmp
    if [ $? -eq 1 ]
    then
      #echo "Config Changed, updating now"
      cp $cfgfile.tmp $cfgfile
      service icinga2 reload
    else
      #echo "no isilon shares modifications, nothing to do"
    fi
  fi
done


#chown icinga.icinga $isiloncfgpath
