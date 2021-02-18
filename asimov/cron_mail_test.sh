#!/bin/bash
 #Created Date Tue Feb 4 11:05:57 PST 2020
 #.....................................................
 # Purpose Of The Script testing mail through cron job 
 #.....................................................
 #Start

SUBJECT="Test mail "
TO="wasim@baidu.com"
MESSAGE="Hello world "

echo "Security breached!" >> $MESSAGE
echo "Time: `date`" >> $MESSAGE

# /var/mail/sajjadwasim -s "$SUBJECT" "$TO" < $MESSAGE






 #End
