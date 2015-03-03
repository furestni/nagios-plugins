#!/bin/bash

function usage {
   echo "usage:"
   echo "-f [backup-folder]"
   exit 3
}

# Catch Arguments
while getopts ":f:" optname
do
  case "$optname" in
    "f")
      BACKUP_FOLDER=$OPTARG
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

#Check if Backup-Folder exists
if [ ! -d $BACKUP_FOLDER ]; then
	echo "Backup-Folder $BACKUP_FOLDER doesnt exist!"
	exit 1
fi

#Check if new files
TMP_FILE='/tmp/automysqlbackups_list'
find $BACKUP_FOLDER -name "*sql.gz" -mtime -1 > $TMP_FILE
EXIT_FIND=$?
if [ $EXIT_FIND -ne 0 ]; then
	rm -rf $TMP_FILE
	echo "find-command failed with exit code $EXIT_FIND"
	exit 3
fi

# count backups
BACKUP_COUNT=`cat $TMP_FILE | wc -l`
echo "$BACKUP_COUNT backups made in last 24 hours (folder: $BACKUP_FOLDER)"
if [ "$BACKUP_COUNT" -eq "0" ]; then
	exit 2
else
	exit 0
fi
