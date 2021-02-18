# admin-scripts

This is a repo in which we'll store scripts and code that helps us with
admin tasks on the cluster or otherwise.

These scripts should be broken down into categories based on management
tasks they help to accomplish.

Node Scripts
=================

node_power_control.bash
  - a script to help manage ipmi power commands to a host

node_slurm_restart.bash
  - a script to help hup slurm on a node and reset it to idle

resume_drained_nodes.bash
  - a script to automatically resume nodes that fail due to specific known errors

scrub_slurm_users_svail.bash
  - a script to show/remove extraneous slurm users from svail cluster


Other Scripts
=================

sync_to_io.bash
  - a script to automate the process of syning files from data-0 to the io-nodes

diskquota.bash
  - a script to show the current users diskquota for extant mounts

create_user_global.bash
  - a new script to create a user on both svail and asimov clusters


deprecated:
=================

ipa_create_user.bash
  - a script to create user entries in IPA with an existing passwd entry

