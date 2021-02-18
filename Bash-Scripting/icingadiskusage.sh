object Host "server9" {
  import "generic-host"
  address = "172.19.44.104"
  address6 = "::1"

  vars.local_disks["diskspace_ssh"] = {
    diskspace_ssh = [ "/", "/tmp", "/var", "/home" ]
  }


}




object CheckCommand "diskspace_ssh" {
    import "push_ssh"

    vars.crit_percent = 90
    vars.warn_percent = 75
    vars.pushed_command = CustomPluginDir + "/check_diskspace.py"
    vars.pushed_options = "--warning=$crit_percent$ --critical=$crit_percent$"
}




apply Service "disk_space_ssh" {
  import "normal-service"

  display_name = "Disk Space"

  check_command = "diskspace_ssh"

  assign where host.name != NodeName && host.vars.os == "Linux"
}

/* apply Dependency "diskhealth_depends" for (service_name => config in host.vars.disk) to Service {  */
apply Dependency "diskspace_depends" to Service {
  parent_service_name = "ssh"
  disable_checks = true
  disable_notifications = true

  states = [ OK ]

  assign where service.check_command == "diskspace_ssh"
}


object ServiceGroup "diskspace_group" {
  display_name = "Disk Space Checks"

  assign where match("diskspace*", service.check_command)
}
