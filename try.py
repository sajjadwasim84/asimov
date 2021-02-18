#!/usr/bin/env python

import pyslurm
def display(node_dict):
    for k,v in node_dict.items():
        print(k,':',v)
        print('===========')
        print("{0} :".format(key))
        for part_key in sorted(value.items()):

Nodes = pyslurm.node()
node_dict = Nodes.get()

display(node_dict)
