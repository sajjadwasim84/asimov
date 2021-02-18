object Host "server9" {
    import "generic-host"
    address = "172.19.44.104"

    // a single variable example
    vars.hello_world_text = "single text variable"

}


apply Service "hello_world_service_dictionary" {
    import "generic-service"

    check_command = "hello_world_command"
    vars += host.vars.hello_world_dict

    assign where host.vars.hello_world_dict
}


object CheckCommand "hello_world_command" {
    command = [ CustomPluginDir + "/hello_world.bash" ]
