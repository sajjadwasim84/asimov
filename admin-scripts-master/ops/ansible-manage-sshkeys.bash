#!/bin/bash -euE
# $Id: script 2 2017-01-01 12:00:00Z user $ (work_name)
#....................................................................
# This is a default template to begin writing a simple bash script
# You can add a description of your script in this box
#....................................................................

function set_constants() {
    _DEBUG="on"
    KEYDIR="/mnt/misc/config/sshkeys"
    SSHDIR="/etc/ssh"
    BAKUPDIR="${SSHDIR}/backup"
    SENTINEL="/etc/ssh/ansible.out"
    HOSTNAME=$(/bin/hostname -s)
    sctl=$(/usr/bin/which systemctl || echo "/usr/bin/systemctl")
    srvc=$(/usr/bin/which service || echo "/usr/sbin/service")
    if [[ -f "${sctl:-}" ]]; then sys_service=1; else sys_service=0; fi
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
    local exit_status="${1:-${?}}" ; if [[ "${exit_status:-}" == *[![:digit:]]* ]]; then exit_status=1; fi
    local exit_message="${2:-unknown error}"
    debug echo -en "${c_red:-}Fatal error ${exit_status:-unknown} in function ${error_function:-unknown} on line ${c_brightred:-}${error_linenum:-unknown}${c_clear:-}: ${exit_message:-unknown} "
    dirs -c
    exit $exit_status
}
function success() {
    onexit 0
}
function onexit() {
    local exit_status=${1:-$?}
    if [[ ${exit_status} == 0 ]]; then
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
    echo "A script to move sshkeys from a new host to storage, or restore from existing entries"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ..."
    echo "    -v|--verbose           be verbose"
    echo "    -h|--help              print this message"
    echo "    -f|--force-overwrite   overwrite the entries in storage with the extant entries"
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
            -f | --force-overwrite)
                FORCE=True
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

function service_handle() {
  _state_=${1:-status}
  _service_=${2:-none}

  if [[ ${sys_service:-} == 0 ]]; then
      $srvc ${_service_} ${state} || debug echo "No ssh service running to stop"
  elif [[ ${sys_service:-} == 1 ]]; then
      $sctl ${state} ${_service_} || debug echo "No ssh service running to stop"
  else
      debug echo "Unknown service system call"
  fi
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

# #=----------------------------------------------------------------#
# |Start our script                                                 |
# #=-|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|-=#

if [ -f "${SENTINEL:-/dev/nonexistent}" ]; then
  # Exit if the sentinel file is present
  echo "unchanged"
  success
fi

if [ -d "${KEYDIR}/${HOSTNAME}" ]; then
  # We have existing keys for this machine, stop ssh and restore them
  service_handle stop ssh
  mkdir ${BAKUPDIR}
  mv ${SSHDIR}/ssh_host* ${BAKUPDIR}
  mv ${SSHDIR}/ssh_import_id ${BAKUPDIR}
  cp -p ${KEYDIR}/${HOSTNAME}/* ${SSHDIR}
  chown root:root ${SSHDIR}/*
  chmod 600 ${SSHDIR}/ssh_host*key
  chmod 644 ${SSHDIR}/ssh_host*.pub
  chmod 644 ${SSHDIR}/ssh_import_id
  service_handle start ssh
else
  # No existing keys, make a reference copy for future use
  mkdir ${KEYDIR}/${HOSTNAME} || error $? "error creating keydir folder"
  cp --dereference --preserve=links --recursive /etc/ssh/ssh_host_* /etc/ssh/ssh_import_id ${KEYDIR}/${HOSTNAME} || error $? "error when copying the keys to the folder..."
fi

# Create a sentinel file so that this script won't do anything on future runs
echo "Sentinel file created by Ansible" >> ${SENTINEL}
echo "changed"

## the script exits successfully
success
#___END___#
