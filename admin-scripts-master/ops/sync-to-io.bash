#!/bin/bash -euE
# $Id: sync-to-io 2 2017-08-09 04:39:26Z user $ (BAIDU)
function set_constants() {
    _DEBUG="off"
    _DRY_RUN="false"
    _LIST_FLAG="false"
    SUDO_CMD=$(which sudo || echo "/usr/bin/sudo")
    RSYNC_CMD=$(which rsync || echo "/usr/bin/rsync")
    RSYNC_ARGS=" --sparse --hard-links --xattrs --acls --archive --delete-before --ignore-existing --rsh='ssh' --stats"
    BASE_DIR="/work"
    TARGETS=("io-0-ib" "io-1-ib" "io-2-ib" "io-3-ib" "io-4-ib" "io-5-ib" "io-6-ib")
    DOMAIN=".svail.baidu.com"
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
    echo -en "Fatal error ${exit_status} in function ${error_function} on line ${error_linenum}: ${exit_message}"
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
    echo "This script will sync data from this host to the io nodes"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] [-n] [-b] <directory> directory-1 ... directory-N"
    echo "    -h|--help        print this message"
    echo "    -v|--verbose     be verbose"
    echo "    -n|--dry-run     say what would be done without doing it"
    echo "    -l|--list        show a list of directories to sync"
    echo "    -b|--base-dir    set the base-dir"
    echo
}

function parse_opts() {
    while [ $# -gt 0 ]; do
        case ${1:-} in
            -v | --verbose)
                _DEBUG="on"
                RSYNC_ARGS+=" --verbose "
                ;;
            -h | --help)
                usage; success
                ;;
            -n | --dry-run)
                _DRY_RUN="True";
                RSYNC_ARGS=" --dry-run "
                ;;
            -l | --list)
                _LIST_FLAG="True";
                ;;
            -b | -b=* | --base-dir | --base-dir=*)
                local arg=${1#-*=*}; local arg=${arg#--base-dir*}; local arg=${arg#-b*}
                if [[ -z ${arg:-} ]] && [[ ! -z ${2:-} ]] && [[ $(echo "${2:-!}" | cut -c 1) != "-" ]]; then local arg="${2}"; shift; fi
                if [[ -z ${arg:-} ]]; then echo "Missing value: $1"; usage; success; fi
                BASE_DIR="${arg}"
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

function list_dirs() {
    ## list the directories available
    if [[ -d "${BASE_DIR}" ]]; then
        OIFS=$IFS; IFS=$'\n'
        real_dirs=($(ls -1 ${BASE_DIR}))
        IFS=$OIFS
    else
        error 1 "\nNo directory found: ${BASE_DIR}\n"
    fi

    echo "Here's a list of directories that can be synced:"
    for ((index = 0; index < ${#real_dirs[@]}; index++)); do
        if [[ -d "${BASE_DIR}/${real_dirs[$index]}" ]]; then
            echo "${real_dirs[$index]}";
        fi
    done
    success
}

function check_args() {
    # verify the args passed in are valid dirs that exist
    if [[ -z "${ARGS[@]}" ]]; then
        echo "Please specify a file or directory to sync to the io nodes"; usage;
        error 1 "\nNo file or directory specified\n"
    fi

    for ((index = 0; index < ${#ARGS[@]}; index++)); do
        fname="${ARGS[$index]}"
        aname="${BASE_DIR}/${fname}"
        if [[ -d "${aname}" ]]; then
            debug echo "directory ${aname} seems to exist..."
        elif [[ -f "${aname}" ]] && [[ ! -L "${aname}" ]]; then
            debug echo "regular file ${aname} seems to exist..."
        else
            debug echo "file or directory ${aname} doesn't actually exist..."
            error 1 "\nUnable to find regular file or directory ${fname}\n"
        fi
    done
}

function sync_stuff() {
    # for every item specified, run a rsyn to every ionode simultaneously, each dir one at a time
    for ((index = 0; index < ${#ARGS[@]}; index++)); do
        fname="${ARGS[$index]}"
        aname="${BASE_DIR}/${fname}"

        if [[ -d "${aname}" ]]; then
            _source="${aname}/"
            _dest="${aname%%/}"
        elif [[ -f "${aname}" ]] && [[ ! -L "${aname}" ]]; then
            _source="${aname}"
            _dest="${aname}"
        else
            _source="/dev/null"
            _dest="/dev/null"
            error 1 "\nSomething went wrong with the script logic. Better check it out.\n"
        fi

        batch="echo"
        for host in "${TARGETS[@]}"; do
            batch+=" & ${RSYNC_CMD} ${RSYNC_ARGS} ${_source} ${host}${DOMAIN}:${_dest}"
        done

        if [[ ${_DRY_RUN} == "false" ]]; then
            BATCH_CMD=""
            if [[ $EUID == 0 ]]; then
                debug echo "You are root, no sudo prompt will be given";
                ## TODO: eval is kind of nasty here. Yuck. Better way to subshell this?
                output=$(eval $batch)
                ## TODO: let's parse the output intead of dumping it in debug...
                debug echo "${output}"
            else
                echo "Since you are not root, please enter your password for SUDO when prompted:"
                BATCH_CMD="${SUDO_CMD} /bin/bash -c '$batch'"
                ## TODO: eval is kind of nasty here. Yuck. Better way to subshell this?
                output=$(eval $BATCH_CMD)
                ## TODO: let's parse the output instead of dumping it in debug..
                debug echo "${output}"
            fi
        else
            echo "What I would have run:"
            echo $batch
        fi
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
parse_opts "${@:-}"

# #=----------------------------------------------------------------#
# |Start our script                                                 |
# #=----------------------------------------------------------------#

if [[ $_LIST_FLAG == "True" ]]; then
    list_dirs
fi

check_args
sync_stuff

## the script exits successfully
success
#___END___#