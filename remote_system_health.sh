#!/bin/bash
 #Created Date Tue Feb 4 02:37:39 PST 2020
 #.....................................................
 # Purpose Of The Script To Check System Health
 #.....................................................
 #Start

 echo -e " Please the server name to check its health {Example: asimov-49} = \c"
read -r file



 HOSTNAME=$(ssh $file hostname)
 DATE=$( date "+%Y-%m-%d %H:%M:%S")
 CPUUSAGE=$(ssh $file top -b -n 1 -d1 | grep "Cpu(s)" | awk '{print $2}' | awk -F. '{print $1}')
 MEMUSAGE=$(ssh $file free | grep Mem | awk '{print $3/$2 * 100.0}')
 DISKUSAGE=$(ssh $file df -P | column -t | awk '{print $5}' | tail -n 1 | sed 's/%//g')
 SLURMSTATUS=$(ssh $file systemctl status slurmd | grep "Active" | awk -F. '{print $1}';)
 MUNGESTATUS=$(ssh $file systemctl status munge | grep "Active" | awk -F. '{print $1}';)
 EXT_IP=$(ssh $file ip addr | grep "172.19.48*" | awk -F3. '{print $1}';)
 PROCESSCOUNT=$(ssh $file  ps axuf | awk '{A[$3]++}END{for(i in A)print i,A[i]}')

 #echo 'HOSTNAME, DATE, CPU_USAGE(%), Mem(%), Disk(%) | Slurm_Status  | Munge_Status'
 #echo "$HOSTNAME, $DATE, $CPUUSAGE%  $MEMUSAGE $DISKUSAGE | $SLURMSTATUS | $MUNGESTATUS $EXT_IP $PROCESSCOUNT"

 echo 'HOSTNAME =' $HOSTNAME
 echo 'DATE =' $DATE
 echo 'CPU Usage(%) =' $CPUUSAGE%
 echo 'Memory =' $MEMUSAGE%
 echo 'Disk Usage =' $DISKUSAGE
 echo 'Slurm Status =' $SLURMSTATUS
 echo 'Munge Status =' $MUNGESTATUS
 echo 'External IP =' $EXT_IP
 echo 'Running Process =' $PROCESSCOUNT
 #End
