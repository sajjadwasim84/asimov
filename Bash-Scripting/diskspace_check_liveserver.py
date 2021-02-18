#!/usr/bin/env python
"""
Basic python script
"""

from optparse import OptionParser
from subprocess import Popen
from subprocess import PIPE as subprocess_PIPE
from platform import system as os_system

DEBUG_FLAG = False
def debug(message):
    """ docstring
    """
    if DEBUG_FLAG:
        print(message)

CRIT_PERCENT = 0
WARN_PERCENT = 0
OS_TYPE = "unknown"

def init_opts():
    """ docstring
    """
    global DEBUG_FLAG
    global CRIT_PERCENT, WARN_PERCENT

    parserobject = OptionParser(description='Check the available diskspace on this system', prog='check_diskspace.py', version='check_diskspace 0.1', usage='%prog -h')
    parserobject.add_option('-v', '--verbose', action="store_true", dest="debug", default=False, help="Enable verbose output")
    parserobject.add_option('-c', '--critical', action="store", dest="crit", default=95, help="return a critical result at this percent expressed as integer")
    parserobject.add_option('-w', '--warning', action="store", dest="warn", default=85, help="return a warning result at this percent expressed as integer")

    ## options is a key pair of the values sent to each switch, arguments is a list of all other argumnents supplied
    options, arguments = parserobject.parse_args()

    DEBUG_FLAG = options.debug
    CRIT_PERCENT = int(options.crit)
    WARN_PERCENT = int(options.warn)

    if WARN_PERCENT > CRIT_PERCENT:
        raise Warning("The warning percent of disk usage must be smaller than the critical percent of disk usage.")

def get_args():
    """ docstring
    """
    df_args = None
    ## linux command = "df -P -l" + " --block-size=G -exclude=tmpfs -exclude=devtmpfs -exclude=debugfs"
    ## mac command = "df -P -l" + " -g"
    if OS_TYPE == "Linux":
        df_args = ["--block-size=G", "--exclude-type=tmpfs", "--exclude-type=devtmpfs", "--exclude-type=debugfs", "--exclude-type=squashfs"]
    elif OS_TYPE == "Darwin":
        df_args = ["-g"]
    else:
        raise Warning("Unknown OS")
    debug("df arguments are: " + " ".join(df_args))

    return df_args

def get_disk_stats():
    """ docstring
    """
    ## df --portability --local
    df_command = ["df", "-P", "-l"]
    df_args = get_args()
    if df_args:
        df_command += df_args
    debug("Full command is: " + " ".join(df_command))

    process = Popen(df_command, stdout=subprocess_PIPE)
    p_out, err = process.communicate()

    if err:
        raise Warning("Warning: " + err)

    partition_list = []
    p_out = p_out.splitlines()[1:]
    for line in p_out:
        tmp = line.decode().split(' ')
        part_stats = []
        for col in tmp:
            if col != '':
                part_stats.append(col)
        partition_list.append(part_stats)

    return partition_list

def parse_disk_stats(part_list):
    """ docstring
    """
    ## output looks like so, indexed starting at 0:
    ## device size used avail avail% mount-point
    perf_data = ""
    result_string = ""
    limiter = ""
    result_code = 0

    debug("I found " + str(len(part_list)) + " partitions")
    for partition in part_list:
        pcapacity = int(partition[4][:-1])
        mount_point = " ".join(partition[5:])
        max_space = int(partition[1][:-1]) if (OS_TYPE == "Linux") else int(partition[1])
        used_space = int(partition[2][:-1]) if (OS_TYPE == "Linux") else int(partition[2])
        warn_space = (0.01 * WARN_PERCENT) * max_space
        crit_space = (0.01 * CRIT_PERCENT) * max_space

        debug("Partition " + mount_point + " is at " + str(pcapacity) + "% full")
        if pcapacity >= CRIT_PERCENT:
            if result_code < 2:
                result_code = 2
            result_string = mount_point + " is at " + str(pcapacity) + "% full" + limiter + result_string
            limiter = ", "
        elif pcapacity >= WARN_PERCENT:
            if result_code < 1:
                result_code = 1
            result_string += limiter + mount_point + " is at " + str(pcapacity) + "% full"
            limiter = ", "
        else:
            pass
        perf_data += mount_point + "=" + str(used_space) + ";" + str(warn_space) + ";" + str(crit_space) + ";0;" + str(max_space) + " "

    result_head = ""

    if result_code == 0:
        result_head = "Success: Disk space is OK"
    elif result_code == 1:
        result_head = "Warning: "
    elif result_code == 2:
        result_head = "Critical: "
    else:
        result_head = "Unknown: unable to determine status for host: "

    output = result_head + result_string + " | " + perf_data

    return result_code, output

def main():
    """ Basic Python script to run from command line
    """
    global OS_TYPE
    init_opts()
    OS_TYPE = os_system()
    debug("OS is: " + OS_TYPE)

    partition_list = get_disk_stats()
    status, report = parse_disk_stats(partition_list)

    print(report)
    exit(status)

if __name__ == '__main__':
    main()
