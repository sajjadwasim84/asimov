#!/bin/bash
 #Created Date Mon Feb 24 00:27:04 PST 2020
 #.....................................................
 # Purpose Of The Script to check slurm controller is runing or not
 #.....................................................
 #Start

> /mnt/home/sajjadwasim/code/test1.log
/mnt/home/sajjadwasim/code/torun.sh 

sleep 5

textvalue=$(cat /mnt/home/sajjadwasim/code/test1.log)
if [[ $textvalue = "hello world" ]]

then
         echo “body of the email” | /usr/bin/mail -s “slrumtest101” muhammadwasim@baidu.com  
else
	echo  $(date)
fi

 #End
