object Host "server9" {
  import "generic-host"
  address = "172.19.44.104"
  address6 = "::1"
   vars.printf[hello_world_command,"this is my first program"] = {

}



apply Service "hello_world_service" {
  import "normal-service"
  display_name = "First Program"
  check_command = "hello_world_command"
}


object CheckCommand "hello_world_command" {
    import "hello_world_service"
    var.printf ("hello world")
}
