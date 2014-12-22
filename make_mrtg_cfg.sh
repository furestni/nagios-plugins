#!/bin/bash
#Script to generate MRTG Configuration and HTML Site
#July 2013
#kollyma

htmlfile=/usr/local/icinga/network-menu.html

#cleanup old config files
rm -rf /var/www/mrtg/config/*

###################################Create HTML HEADER##############################
echo '<html>
<head>
<title>Network Devices List</title>
<style type="text/css">
body {
        font-family:verdana,arial,sans-serif;
        font-size:10pt;
        margin:10px;
        background-color:#A9BCF5;
        }
</style>
</head>
<body>
' > $htmlfile
####################################################################################


for ((count=1; count<=5; count++)); do
   case $count in
    1 )
        filenames=`grep -l -ie 'haproxy'  /etc/nagiosql/hosts/* | grep -v -i template | grep -i rts`
        echo '<h4>haproxy:</h4>' >> $htmlfile ;;
    2 )
        filenames=`grep -l -ie 'pcache[0-9]'  /etc/nagiosql/hosts/* | grep -v -i template`
        echo '<h4>Pcaches:</h4>' >> $htmlfile ;;
    3 )
        filenames=`grep -l -ie 'firewall-host'  /etc/nagiosql/hosts/* | grep -v -i template | grep -v -i fw-stxt`
        echo '<h4>Firewall:</h4>' >> $htmlfile ;;
    4 ) 
        filenames=`grep -l -i 'switch-host'  /etc/nagiosql/hosts/* | grep -v -i template | grep -v -i voip_switch`
        echo '<h4>Switches:</h4>' >> $htmlfile ;;
    5 ) 
        filenames=`grep -l -i 'icecast'  /etc/nagiosql/hosts/* | grep -v -i template`
        echo '<h4>Livestreaming Audio:</h4>' >> $htmlfile ;;
   esac

   for i in $filenames; do 
      echo "processing $i"
      address=`grep -i address $i | awk '{print $2}' | tr -d '\r'`
      name=`grep -i host_name $i | awk '{print $2}' | tr -d '\r'`
      com=`grep -i community $i | awk '{print $2}' | tr -d '\r' | sed -e "s/.STXT!mgmt$./STXT!mgmt$/" | sed -e "s/..txt-C0Re!./\\$txt-C0Re!/" `

      #Create html menu
      echo '      <li class="menuli_style1"><a href="/cgi-bin/14all.cgi?aktion='$name '" target="content">'$name'</a></li>' >> $htmlfile
      
      # Create MRTG Configuration
      /usr/bin/cfgmaker --global "Options[_]: growright, bits" --ifref=name $com'@'$address --global "Workdir: /var/www/mrtg" --global "LogFormat: rrdtool" -o /var/www/mrtg/config/$name.cfg
   done
done


################################Create HTML Footer####################################
echo '
</body>
</html>' >> $htmlfile
######################################################################################


cfgfiles=`grep -l Interface /var/www/mrtg/config/*`
echo "Workdir: /var/www/mrtg/" > /etc/mrtg.cfg
echo "LogFormat: rrdtool" >> /etc/mrtg.cfg
echo "PathAdd: /usr/bin/" >> /etc/mrtg.cfg
for i in $cfgfiles
  do
   echo "Include: $i"
done >> /etc/mrtg.cfg

service mrtg stop
service mrtg start
