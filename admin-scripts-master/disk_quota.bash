#!/bin/bash -euE
# $Id: disquota 2 2018-01-01 12:00:00Z user $ (baidu usa)
#....................................................................
# This is a script to get quotas for nfs mounted disks
#....................................................................

function set_constants() {
    _DEBUG="off"
    unset GREP_OPTIONS
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
    /bin/echo -en "${c_red}Fatal error ${exit_status} in function ${error_function} on line ${c_brightred}${error_linenum}${c_clear}: ${exit_message} "
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
    /bin/echo -en "Script: ${0} stopped\n"
    dirs -c
    exit $exit_status
    fi
}

function debug() {
    [ "$_DEBUG" == "on" ] && ${@:-/bin/echo} || _INVALID_=0
}

function usage() {
    local scriptname=$(basename ${0})
    /bin/echo "This script shows disk quotas and usage for NFS mounted volumes"
    /bin/echo ""
    /bin/echo "Usage: ${scriptname} [-v] [-h] ..."
    /bin/echo "    -v|--verbose     be verbose"
    /bin/echo "    -h|--help        print this message"
    /bin/echo ""
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
                set -- $(/bin/echo "$split" | /usr/bin/cut -c 2- | /bin/sed 's/./-& /g') "$@"
                continue
                ;;
            --* | -?)
                /bin/echo "Not a valid option: '${1}'" >&2
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

function get_quota_local() {
    ## get quota from nfs shares using rpc.rquotad
    local location=${1:-NONE}
    local q_type=${2:-rpc}

    local premount=$(/bin/ls -U --directory --format=single-column ${location} || echo none)
    local nfs_output=$(/bin/mount -t nfs,nfs4 2>&1 | /bin/grep ${location} 2>&1 || /bin/echo "null" )
    local remote_mntpoint=$(/bin/echo "${nfs_output:-null}" | /usr/bin/cut -d: -f2 | /usr/bin/cut -d' ' -f1 | /usr/bin/cut -d'/' -f2)

    if [[ ${nfs_output} == "null" ]]; then
        /bin/echo "${location} not mounted"
        return 0
    else
        debug /bin/echo "found mount for dir ${remote_mntpoint}"
    fi

    local quota_output=$(/usr/bin/quota --format=${q_type} --no-wrap --show-mntpoint --all-nfs --user ${username:-nobody} 2>/dev/null | ( /bin/grep ${username:-nobody} | /bin/grep ${remote_mntpoint} || /bin/echo "unknown ${remote_mntpoint} 0 1 0" ) | tail -1)

    skip=$(echo ${quota_output} | cut -f1 -d' ')
    if [[ ${skip} == "unknown" ]]; then
        /bin/echo "no data for ${remote_mntpoint}"
        return 0
    fi
    q_used=$(/bin/echo ${quota_output:-} | /usr/bin/awk '{print $3}' || /bin/echo '0')
    q_limit=$(/bin/echo ${quota_output:-} | /usr/bin/awk '{print $4}' || /bin/echo '1')

    q_percent=$(/bin/echo "${q_used:--} ${q_limit:-}" | /usr/bin/awk '{printf "%0.1f\n", (100*($1/$2))}' 2>/dev/null || /bin/echo '0')
    c_used=$(/usr/bin/awk -v used=${q_used:-} 'BEGIN {printf "%0.1f", (used/1048576)}' || /bin/echo '0')
    c_limit=$(/usr/bin/awk -v limit=${q_limit:-} 'BEGIN {printf "%0.0f", (limit/1048576)}' || /bin/echo '0')

    output_string="  ${location:-}: ${q_percent:-}% (${c_used:-} GB of ${c_limit:-} GB limit)"

    /bin/echo "${output_string}"
}

function show_quota() {
    username=$(/usr/bin/whoami || /bin/echo "${USER:-null}")

    paths=("/mnt/home/${username}:rpc" "/mnt/scratch/${username}:rpc" "/mnt/data/${username}:rpc" "/mnt/archive/${username}:rpc")

    /bin/echo "Disk quota usage:"

    for keys in "${paths[@]}"; do
        local path=$(/bin/echo "${keys}" | /usr/bin/cut -d: -f1)
        local type=$(/bin/echo "${keys}" | /usr/bin/cut -d: -f2)
        get_quota_local ${path} ${type}
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
if [[ ${EUID} == 0 ]]; then
    error 1 "This script cannot by run by root";
fi

show_quota


## the script exits successfully
success
#___END___#
