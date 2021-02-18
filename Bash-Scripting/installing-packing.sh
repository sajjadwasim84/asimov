#!/bin/bash
#insalling wget


pkg="wget"
output=$((dpkg-query --showformat='${Status}' --show ${pkg} 2>/dev/null | egrep 'install ok installed' 1>/dev/null && echo $?) || echo $?)
if [[ ${output} == 0 ]]; then
echo "Package is already installed"
else
#apt-cache show ${pkg} ... confirm package exists
apt install -y ${pkg}
fi
