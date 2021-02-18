#!/bin/bash -euE
# $Id: gather-hashes.bash 4 2017-01-01 12:00:00Z aaron $ (baidu)
#....................................................................
# This is a script to gather file hashes to compare files with
#....................................................................

declare -A _GLOBALS_=()
declare -A hashArray=()
function set_constants() {
    _GLOBALS_['debug_flag']=false
    _GLOBALS_['dry_run']=false
    ## Set defaults for command line options
    _GLOBALS_['save_file']="/tmp/hashlist.txt"
    _GLOBALS_['search_path']="/tmp/"
}

function define_colors() {
    local _bCOLORS=0; local _NUM_COLORS=$(tput colors 2>/dev/null) || local _bCOLORS="${?}"
    if [[ ${_bCOLORS} == "0" ]] && [[ ${_NUM_COLORS} -gt 2 ]]; then
        #foreground='39' or '38', background='49' or '48'
            c_clear='\e[0;39;49m' ;          c_bold='\e[1;39;49m'
        c_underline='\e[4;39;49m' ;       c_inverse='\e[7;39;49m'
            c_black='\e[0;30;49m' ;          c_grey='\e[1;30;49m'
              c_red='\e[0;31;49m' ;     c_brightred='\e[1;31;49m'
            c_green='\e[0;32;49m' ;   c_brightgreen='\e[1;32;49m'
           c_yellow='\e[0;33;49m' ;  c_brightyellow='\e[1;33;49m'
             c_blue='\e[0;34;49m' ;    c_brightblue='\e[1;34;49m'
          c_magenta='\e[0;35;49m' ; c_brightmagenta='\e[1;35;49m'
             c_cyan='\e[0;36;49m' ;    c_brightcyan='\e[1;36;49m'
            c_white='\e[0;37;49m' ;   c_brightwhite='\e[1;37;49m'
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
    echo -en "${c_red}Fatal error ${exit_status:-unknown} in function ${error_function:-unknown} on line ${c_brightred}${error_linenum:-unknown}${c_clear}: ${exit_message:-unknown} "
    dirs -c
    exit ${exit_status}
}
function success() {
    onexit 0
}
function onexit() {
    local exit_status=${1:-$?}
    if [ ${exit_status} == 0 ]; then
        dirs -c
        exit ${exit_status}
    else
    echo -en "Script: ${0} stopped\n"
    dirs -c
    exit ${exit_status}
    fi
}

function debug() {
    ## usage: debug echo "This is a debug message for example"
    [ "${_GLOBALS_['debug_flag']:-}" == true ] && ${@:-echo} || _INVALID_=0
}

function dryrun_eval() {
    ## usage: dryrun_eval "rm -rf /tmp/deleted"
    ## WARNING: USES eval!!! Be Very Careful!
    [ "${_GLOBALS_['dry_run']:-}" == true ] && echo "${@:-}" || eval "${@:-echo}"
}

function usage() {
    local scriptname=$(basename ${0})
    echo "Gather or print file hash info"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ... [-s] <cache filename> [-f] <search path> - gather|dump"
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -n|--dry-run     don't actually do anything, just say what would be done"
    echo "    -s|--save-file   filename/location where to output the hash temp data"
    echo "    -f|--search-path the path to gather file hashes from"
    echo "    gather|dump      whether to gather hashes for listing, or dump known hashes from the cache file"
    echo ""
}

function parse_opts() {
    while [ $# -gt 0 ]; do
        case ${1:-} in
            -h | --help)
                usage; success
                ;;
            -v | --verbose)
                _GLOBALS_['debug_flag']=true
                ;;
            -n | --dry-run)
                _GLOBALS_['dry_run']=true
                ;;
            -s | -s=* | --save-file | --save-file=*)
                local arg="${1#-*=*}"; local arg=${arg#--save-file*}; local arg=${arg#-s*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                _GLOBALS_['save_file']="${arg}"; shift "${num_of_array-1}"; continue
                ;;
            -f | -f=* | --search-path | --search-path=*)
                local arg="${1#-*=*}"; local arg=${arg#--search-path*}; local arg=${arg#-f*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                _GLOBALS_['search_path']="${arg}"; shift "${num_of_array-1}"; continue
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
    if [[ "${1:-}" == "-" ]]; then shift; fi
    _ARGS_=("${@:-}")
}

function gather_hashes() {
    SAVE_FILE="/tmp/test/file_hashes.txt"

    if ${_GLOBALS_['dry_run']}; then
        output=$( find ${_GLOBALS_['search_path']} -type f )
        echo "I would have run sha256sum on:"
        echo -e "${output[@]}"
    else
        while read -r input; do
            # stuff into array for --verbose option
            key=${input%%[[:space:]]*}
            val=${input#*[[:space:]]}
            hashArray[${key}]+="${val}\n"
            # stuff into cache file
            echo "${input[@]}" >> ${_GLOBALS_['save_file']}
        done < <(find ${_GLOBALS_['search_path']} -type f -print0 | xargs -0 -n1 sha256sum)

        debug show_hashes
    fi

}

function show_hashes() {
    for key in "${!hashArray[@]}"; do
        dup_files=(${hashArray[$key]})
        if [[ ${#dup_files[@]} -gt 1 ]]; then
            echo -e ":sha256sum:\n$key"
            echo -e ":files:"
            for filename in ${hashArray[$key]}; do
                echo -en "${filename}"
            done
        else
            #echo -e "not a dup: ${hashArray[$key]}"
            pass=0
        fi
    done
}

function dump_hashes() {
    declare -A outArray

    while read -r input; do
        key=${input%%[[:space:]]*}
        val=${input#*[[:space:]]}
        hashArray[${key}]+="${val}\n"
    done <  ${_GLOBALS_['save_file']}

    show_hashes
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

if [[ ${_ARGS_[0]:-} == "gather" ]]; then
    gather_hashes
elif [[ ${_ARGS_[0]:-} == "dump" ]]; then
    dump_hashes
else
    usage
    error 1 "You must specify whether to gather or dump hashes"
fi


## the script exits successfully
success
#___END___#