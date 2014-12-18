#!/bin/bash

#Define Check Levels
warninglevel=95
criticallevel=98

#ExcludeFilter , need to be implemented
excludefilter=''

for hostname in Isilon-ix-SmartConnect.stxt.media.int Isilon-cu01-SmartConnect.stxt.media.int
do
  if [ $hostname == "Isilon-ix-SmartConnect.stxt.media.int" ]
  then
    servicelist=$( ssh root@isilon-ix-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }'  )
    cfgfile="/etc/icinga2/zones.d/zone-ix/isilonshare.conf"
  else
    servicelist=$( ssh root@isilon-cu01-smartconnect.stxt.media.int -C "isi quota ls" | awk '$5 ~ "[[:digit:]]" { print $3 }' )
    cfgfile="/etc/icinga2/zones.d/zone-bie/isilonshare.conf"
  fi

  if [[ ! -z $servicelist ]]
  then
     # Write host definition for Smart Connect
    echo -e "object Host \"$hostname\" { 
    import \"generic-host\"
    address = \"$hostname\"
    } " >  $cfgfile.tmp
    
    # Write Services for Smart Connect Host
    for y in $servicelist
    do 
       echo -e "apply Service \"Isilon_share $y\"{
       import \"generic-service-pnp\"
       vars.sla = \"24x7\"

       check_command  = \"check_by_ssh\"
       
       vars.user = \"root\" 
       vars.timeout = \"30\"
       vars.option = [ \"UserKnownHostsFile=/dev/null\", \"StrictHostKeyChecking=no\" ]
       vars.command = \"/bin/bash /ifs/data/nagios/isilon-quota-usage.sh -p $y -w $warninglevel -c $criticallevel\"
       assign where host.address == \"$hostname\"
        } \n " >> $cfgfile.tmp
    done
     
     # Check if modification
    diff $cfgfile $cfgfile.tmp > /dev/null 2>&1
    if [ $? -eq 1 ]
    then
      echo "Config Changed, updating now"
      cp $cfgfile.tmp $cfgfile
    else
      echo "no isilon shares modifications, nothing to do"
    fi
  fi
done


#chown icinga.icinga $isiloncfgpath
