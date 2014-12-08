#!/bin/bash
#mkolly
#17 Jan 2014
#Check count from hbbtv streaming platform


# Argument Parsing
function usage {
   echo "usage:"
   echo "-H [Host]"
   echo "-p [path]"
   exit 3
}

while getopts ":p:H:" optname
do
  case "$optname" in
    "H")
      host=$OPTARG
      ;;
    "p")
      path=$OPTARG
      ;;
    "?")
      echo "Unknown option $OPTARG"
      usage
      ;;
    ":")
      echo "No argument value for option $OPTARG"
      usage
      ;;
    *)
      #Should not occur
      echo "Unknown error while processing options"
      usage
      ;;
  esac
done

#Perform search on TFTP Server
count_hbbtv_listeners=$(curl -s http://$host/$path)

#catch return code
return_code=$?

#keep it simple and stupid
echo "Count = $count_hbbtv_listeners | count=$count_hbbtv_listeners"

exit $return_code
