#!/bin/bash
echo -e " Please Enter The File Name You Want To Create: \c"
read -r file
touch /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh

echo -e $'#!/bin/bash' >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh
echo ' #Created Date' $(date) >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh
echo -e " #....................................................." >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh
echo -e " # Purpose Of The Script" >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh
echo -e " #....................................................." >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh
echo -e " #Start" >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh





echo -e " #End" >> /mnt/home/sajjadwasim/bash_scripts_2.0/$file.sh

