#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# $Id: extend_slurm_job_by_reservation 2 2017-01-01 12:00:00Z aaron $ (baidu)
#....................................................................
# This is a default template to begin writing a simple python script
# You can add a description of your script in this box
#....................................................................
#
from sys import exit
from pyslurm import job, reservation
from pyslurm import getpwnam
from datetime import datetime
from subprocess import Popen, STDOUT

GLOBALS={}
def debug(message):
    """ print out debug messages when the debug flag is on
    """
    if GLOBALS['verbose']:
        print(message)

def parse_opts():
    """ Parse the arguments passed to the script for evaluating
    """
    from argparse import ArgumentParser

    parser = ArgumentParser(description='This script enables updating the time limit on jobs on a reservation by reservation name ')
    parser.add_argument('--verbose', '-v', action='store_true', help="be verbose")
    parser.add_argument('--dry-run', '-n', action='store_true', help="don't actually do anything, just say what would be done")
    parser.add_argument('reservation', action='store', help="the name of the reservation")

    cli_args = parser.parse_args()
    GLOBALS['verbose'] = cli_args.verbose
    GLOBALS['dry_run'] = cli_args.dry_run
    GLOBALS['resname'] = cli_args.reservation

def get_slurm_time(res_time) -> str:
    """ translate res_time to slurm time
    """
    pass

def parse_userlist(user_list) -> list:
    users = list()
    for user in user_list:
        users.append(getpwnam(user).pw_uid)
    return users

def parse_nodelist(node_string) -> list:
    """ parse a nodelist
    """
    node_list = []
    if node_string == None:
        return None
    elif node_string == "":
        return []
    elif '[' in node_string:
        prefix_string, remainders = node_string.split('[',1)
        current_node_string, remaining_nodes = remainders.split(']',1)
        if ',' in prefix_string:
            prefix_list = prefix_string.split(',')
            current_prefix = prefix_list[-1]
            next_nodes = ",".join(prefix_list[0:-1])
            # recurse the nodes in the prefix list
            node_list += parse_nodelist(next_nodes)
        else:
            current_prefix = prefix_string
        # handle current list
        if ',' in current_node_string:
            current_node_list = current_node_string.split(',')
        else:
            current_node_list = [current_node_string]
        for node_item in current_node_list:
            if '-' in node_item:
                first_n, last_n = node_item.split('-')
                for nodenum in range(int(first_n), int(last_n)+1):
                    node_list.append(current_prefix + str(nodenum))
            else:
                node_list.append(current_prefix + node_item)
        # recurse the remaining nodes in the list
        node_list += parse_nodelist(remaining_nodes)
    elif ',' in node_string:
        node_items = node_string.split(',')
        for node_item in node_items:
            if node_item is not '':
                node_list.append(node_item)
    else:
        node_list = [node_string]
    return node_list

def get_timespan(total_seconds):
    """ return timespan as string formatted x
    """
    days, remainder = divmod(total_seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, seconds = divmod(remainder, 60)
    output_string = "%i-%i:%i:%i" % (days, hours, minutes, seconds)
    return output_string

def get_res_info(res_name) -> tuple:
    """ get the users, nodes in the reservation
    """
    debug("extend_slurmjob: Checking reservation named %s" % res_name)

    res_object = reservation().get()
    try:
        res_info = res_object[res_name]
    except KeyError as e:
        debug("extend_slurmjob debug: no reservation named %s" % e)
        exit(1)

    usernames = res_info['users']
    nodelist = res_info['node_list']

    end_time = res_info['end_time']

    users = parse_userlist(usernames)
    nodes = parse_nodelist(nodelist)

    return users, nodes, end_time

def get_jobs(userid, nodename) -> set:
    """
    """
    debug("extend_slurmjob: Checking user %s and node %s for jobs" % (userid, nodename) )
    job_list = set()
    job_obj = job().find_user(userid)
    for jobid in job_obj:
        nodelist = parse_nodelist(job_obj[jobid]['nodes'])
        if (nodelist is not None) and (nodename in nodelist):
            job_list.add(jobid)
    return job_list

def extend_jobs(joblist, res_end_time) -> None:
    """
    """
    for jobid in joblist:
        ## only get the head job for the slurm command
        job_data = job().find_id(jobid)[0]
        job_starttime = job_data['start_time']
        job_endtime = job_data['end_time']
        job_diff = res_end_time - job_endtime

        if job_diff > 0:
            job_starttime_obj = datetime.fromtimestamp(job_starttime)
            res_endtime_obj = datetime.fromtimestamp(res_end_time)
            time_diff = res_endtime_obj - job_starttime_obj
            end_time_string = get_timespan(time_diff.total_seconds())

            debug("extend_slurmjob: Extending job %i" % jobid)
            command = ['/usr/bin/scontrol', 'update', 'jobid=%i' % jobid, 'timelimit=%s' % end_time_string]
            try:
                debug("extend_slurmjob debug: exec '/usr/bin/scontrol update jobid=%i timelimit=%s'" % (jobid, end_time_string))
                p_out = Popen(command, stdin=None, stderr=STDOUT, shell=False)
                outdata, errdata = p_out.communicate()
            except Exception as e:
                debug('extend_slurmjob debug: error setting job time limit for job %i: %s' % (jobid, str(e)) )
                debug('extend_slurmjob debug: error data %s' % errdata)
                continue
            debug('extend_slurmjob debug: output was %s' % str(outdata) )
        else:
            debug("extend_slurmjob: Job %i does not need extending, endtime of %s is after res end time %s" % (jobid, (job_endtime + job_diff), res_end_time) )

def main():
    """ The main function: you can call your functions from here
    """
    users, nodes, res_end_time = get_res_info(GLOBALS['resname'])
    joblist = set()
    for user in users:
        for node in nodes:
            joblist = joblist.union( get_jobs(user, node) )
    ## got all jobs, send them to the job extender
    if bool(joblist):
        extend_jobs(joblist, res_end_time)

if __name__ == "__main__":
    """ Start our script when called; exit when imported
    """
    parse_opts()
    main()
else:
    print("This program does not support importing")
    exit(-1)
#__END__#

