#!/bin/bash

# identify the fauly HD in Mdadm

sync

################## To check mdadm package is intall or not ############################
mdadm --version | egrep ['v', '.' .'-'] 2>/dev/null
VER=$?
stat=0
    if [ $var > 0 ]; then
#  echo "here
        mdstat_out=$(cat /proc/mdstat)
        echo ${mdstat_out} | egrep 'U_' 2>/dev/null

    if [ $? != 0 ]; then
        m=`echo ${mdstat_out} | egrep "[sdb | sdc]"`

    if [ $m == "sdb" ]; then
        stat="sdc"
        elif [ $m == "sdc" ]; then
          stat="sdb"
        else
          echo "Error matching string"
          exit -1
fi
      else
          echo "Ok"
          exit 0
fi
fi

################## Now we need to comment fail drive and remove it ############################

mdadm --manage /dev/md0 --fail /dev/$stat

mdadm --manage /dev/md0 --remove /dev/$stat

# sudo ini 6


echo " Enter the new Disk we are waiting when you are done please press 'yes'to continue"

read ans

while [ ${ans} != "yes" ];
do
echo" you have to enter yes"
done

sfdisk -d /dev/"${stat%?}"

mdadm --manage /dev/md0 --add /dev/$stat

mdadm --manage /dev/md0 --add /dev/$stat

#else
#echo " your need to install mdadm please try apt install mdadm"

#fi
