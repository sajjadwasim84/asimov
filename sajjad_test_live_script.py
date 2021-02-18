#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
from sys import exit
from os import geteuid
from pyslurm import node, job
from time import sleep
USERID = int(geteuid())
MAX_PERCENT = 0.19
WAIT_PERIOD = 360
def get_total_gpu_resource(node_dict) -> int:
    """ return the total of available gpu resource
    """
    grestotal=0
    if len(node_dict) <= 0:
        return 0
    else:
        for nodeinfo in node_dict.values():
            gpucount=0
            nodestate = 'DOWN'
            nodegres = ['gpu:0']
            try:
                nodestate = nodeinfo['state']
                nodegres = nodeinfo['gres']
            except KeyError:0.19
                pass
            if ('DOWN' in nodestate) or ('DRAIN' in nodestate):
                continue
            elif type(nodegres) is list:
                for gres in nodegres:
                    if 'gpu' in gres:
                        gpucount=gres.split(':')[1]
            grestotal+=int(gpucount)
    return grestotal
def get_my_gpu_resource(job_dict) -> int:
    """
    """
    global USERID
    grestotal=0
    if len(job_dict) <= 0:
        return 0
    else:
        for jobinfo in job_dict.values():
            gpucount = 0
            jobuser = -1
            jobstate = 'PENDING'
            jobgres = ['gpu:0']
            try:
                jobuser = int(jobinfo['user_id'])
                jobgres = jobinfo['gres']
                jobstate = jobinfo['job_state']
            except KeyError:
                pass
            if (jobuser == USERID) and (jobstate == 'RUNNING'):
                if type(jobgres) is list:
                    for gres in jobgres:
                        if 'gpu' in gres:
                            gpucount = int(gres.split(":")[1])
            grestotal+=gpucount
    return grestotal
def limit_job_submissions(job_dict) -> None:
    """ submit jobs until reached max limit, then wait until below limit
    """
    slurmjob = job()
    # set up some slurm timeout defaults
    slurm_alloc_timeout = 3
    jobwait_time_period = WAIT_PERIOD
    # set some values here, or stuff them into an array in job_dict or something
    partition = "1080Ti"
    ntasks = "1"
    nodes = "1"
    ntasks_per_node = "1"
    gres = "gpu:1"
    output = "output_file_%j.log"
    for jobname, jobcommand in job_dict.items():
        under_limit = False
        while not under_limit:
            total_resource = get_total_gpu_resource(node().get())
            my_resource = get_my_gpu_resource(job().get())
            under_limit = (total_resource * MAX_PERCENT > my_resource)
            if not under_limit:
                print("too many jobs, waiting...")
                sleep(jobwait_time_period)
        # submit the job to slurm
        job_opts = {"partition" : partition, "ntasks" : ntasks, "nodes" : nodes, "ntasks-per-node" : ntasks_per_node, "gres" : gres, "output" : output, "job-name" : jobname, "wrap" : jobcommand}
        job_id = slurmjob.submit_batch_job(job_opts)
        print("running job %s with jobid %d" % (jobname, job_id))
        # allow slurm time to alloc resources to calculate new total
        sleep(slurm_alloc_timeout)
def main():
    """ The main function
    """
    job_dict = {
        'testjob1': '/bin/hostname; sleep 40 && echo done1',
        'testjob2': '/bin/hostname; sleep 30 && echo done2',
        'testjob3': '/bin/hostname; sleep 20 && echo done3',
        'testjob4': '/bin/hostname; sleep 10 && echo done4'
        }
    limit_job_submissions(job_dict)
if __name__ == "__main__":
    """ Start
    """
    main()
else:
    print("This program does not support importing")
    exit(-1)
#__END__#
