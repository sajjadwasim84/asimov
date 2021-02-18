#!/bin/bash

function show_quota() {
    username=$(/usr/bin/whoami || /bin/echo "${USER:-null}")

    paths=("/mnt/home/${username}:vfsv1" "/mnt/scratch/${username}:vfsv1" "/mnt/data/${username}:xfs" "/mnt/archive/${username}:xfs")

    /bin/echo "Disk quota usage:"

    for keys in "${paths[@]}"; do
        local path=$(/bin/echo "${keys}" | /usr/bin/cut -d: -f1)
        local type=$(/bin/echo "${keys}" | /usr/bin/cut -d: -f2)
        get_quota_ssh ${path} ${type}
    done
}
