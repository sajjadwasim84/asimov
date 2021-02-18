#!/bin/bash -euE
# $Id: disquota 2 2018-01-01 12:00:00Z user $ (baidu usa)
#....................................................................
# This is a script to get quotas for nfs mounted disks
#....................................................................

function set_constants() {
    _DEBUG="off"
}

function define_colors() {
    _bCOLORS=0; _NUM_COLORS=$(tput colors 2>/dev/null) || _bCOLORS="${?}"
    if [[ ${_bCOLORS} == "0" ]] && [[ ${_NUM_COLORS} -gt 2 ]]; then
        #foreground='39' or '38', background='49' or '48'
        c_clear='\000\033[0;39;49m' ; c_bold='\00\00\00\033[1;39;49m'
        c_underline='\033[4;39;49m' ; c_inverse='\00\00\033[7;39;49m'
        c_red='\00\00\033[0;31;49m' ; c_brightred='\000\033[1;31;49m'
        c_green='\000\033[0;32;49m' ; c_brightgreen='\0\033[1;32;49m'
        c_yellow='\00\033[0;33;49m' ; c_brightyellow='\0033[1;33;49m'
        c_blue='\00\0\033[0;34;49m' ; c_brightblue='\00\033[1;34;49m'
        c_magenta='\0\033[0;35;49m' ; c_brightmagenta='\033[1;35;49m'
        c_cyan='\00\0\033[0;36;49m' ; c_brightcyan='\00\033[1;36;49m'
        c_black='\000\033[0;40;49m' ; c_grey='\00\00\00\033[1;40;49m'
    else
        c_clear=''; c_bold=''; c_underline=''; c_inverse=''
        c_red=''; c_brightred=''; c_green=''; c_brightgreen=''
        c_yellow=''; c_brightyellow=''; c_blue=''; c_brightblue=''
        c_magenta=''; c_brightmagenta=''; c_cyan=''; c_brightcyan=''
        c_black=''; c_grey=''
    fi
}

#....................................................................
# define the error/exit captures
#....................................................................
function error() {
    ## usage:  error ${?:-ERR_CODE} "message"
    ## this function is used to capture errors in the script manually
    local error_function="${FUNCNAME[1]}"
    local error_linenum="${BASH_LINENO[0]}"
    local exit_status="${1:-${?}}" ; if [[ "${exit_status}" == *[![:digit:]]* ]]; then exit_status=1; fi
    local exit_message="${2:-unknown error}"
    echo -en "${c_red}Fatal error ${exit_status} in function ${error_function} on line ${c_brightred}${error_linenum}${c_clear}: ${exit_message} "
    dirs -c
    exit $exit_status
}
function success() {
    onexit 0
}
function onexit() {
    local exit_status=${1:-$?}
    if [ ${exit_status} == 0 ]; then
        dirs -c
        exit $exit_status
    else
    echo -en "Script: ${0} stopped\n"
    dirs -c
    exit $exit_status
    fi
}

function debug() {
    [ "$_DEBUG" == "on" ] && ${@:-echo} || _INVALID_=0
}

function usage() {
    local scriptname=$(basename ${0})
    echo "This script shows disk quotas and usage for NFS mounted volumes"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ..."
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo ""
}

function parse_opts() {
    while [ $# -gt 0 ]; do
        case ${1:-} in
            -v | --verbose)
                _DEBUG="on"
                ;;
            -h | --help)
                usage; success
                ;;
            --)
                break
                ;;
            -[[:alpha:]][[:alpha:]]*)
                split=${1}; shift
                set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
                continue
                ;;
            --* | -?)
                echo "Not a valid option: '${1}'" >&2
                usage; success
                ;;
            *)
                break
                ;;
        esac
        shift
    done
    ARGS=("${@:-}")
}

function get_quota_ssh() {
    local location=${1:-NONE}
    local q_type=${2:-vfsv1}

    local mount_exists=$(ls ${location} 2>/dev/null 1>/dev/null || return $? ; echo $?)
    if [[ ${mount_exists:-1} -ne 0 || ${location:-NONE} == "NONE" ]]; then
        echo "no mounts for ${location}"
        continue
    fi

    local nfs_output=$(mount -t nfs,nfs4 2>&1 | grep ${location} 2>&1 || echo "null" )
    local nfs_host=$(echo "${nfs_output:-null}" | cut -d: -f1)
    local remote_mntpoint=$(echo "${nfs_output:-null}" | cut -d: -f2 | cut -d' ' -f1 | cut -d'/' -f2)

    if [[ ${nfs_output} == "null" ]]; then
        echo "no mounts found"
        continue
    fi

#    use this in case shells are respected or something:
#    local quota_output=$(ssh ${nfs_host} "bash -c \"/usr/bin/quota --format=${q_type} --no-wrap --show-mntpoint --user ${username:-nobody} | ( grep ${remote_mntpoint} || echo 'unknown ${remote-mntpoint} 0 1 0' ) | tail -1\"")
    local quota_output=$(ssh ${nfs_host} "/usr/bin/quota --format=${q_type} --no-wrap --show-mntpoint --user ${username:-nobody} | ( grep ${remote_mntpoint} || echo 'unknown ${remote-mntpoint} 0 1 0' ) | tail -1")
    local q_used=$(echo ${quota_output:-} | awk '{print $3}' || echo '0')
    local q_limit=$(echo ${quota_output:-} | awk '{print $4}' || echo '1')

    local q_percent=$(echo "${q_used:-0} ${q_limit:-1}" | awk '{printf "%0.1f\n", (100*($1/$2))}' 2>/dev/null || echo '0')
    local c_used=$(awk -v used=${q_used:-} 'BEGIN {printf "%0.1f", (used/1048576)}' || echo '0')
    local c_limit=$(awk -v limit=${q_limit:-} 'BEGIN {printf "%0.0f", (limit/1048576)}' || echo '0')

    local output_string="  ${location:-null}: ${q_percent:-}% (${c_used:-} GB of ${c_limit:-} GB limit)"

    echo "${output_string}"
}


function show_quota() {
    username=$(/usr/bin/whoami || echo "${USER:-null}")
    paths=("/mnt/home/${username}:vfsv1" "/mnt/scratch/${username}:vfsv1" "/mnt/data/${username}:xfs")

    echo "Disk quota usage:"

    for keys in "${paths[@]}"; do
        local path=$(echo "${keys}" | cut -d: -f1)
        local type=$(echo "${keys}" | cut -d: -f2)
        get_quota_ssh ${path} ${type}
    done
}


#....................................................................
# we've called bash with -euE, exit on error and error on unset variables
# so define some error prodedures to take when erroring out:
#....................................................................
trap onexit HUP INT TERM QUIT EXIT
trap error ERR ILL
set -o nounset -o errexit
#....................................................................
#  Defining variables we're using and handle options
#....................................................................
set_constants
define_colors
parse_opts ${@:-}

## --- start --- ##
show_quota


## the script exits successfully
success
#___END___#