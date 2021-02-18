#!/bin/bash


function disk_usage(){

	username=$(/usr/bin/whoami || /bin/echo "${USER:-null}")
	disk=$(df -h /media/2TB | awk 'NR==2 {print $2}')
	#paths=("/media/2TB/ ${username}")
	paths=("/media/2TB/")
        echo -e "Path= $paths UserName: $username  Size: $disk"




}


disk_usage
