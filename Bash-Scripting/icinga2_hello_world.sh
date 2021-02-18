object Host "server9" {
    import "generic-host"
    address = "172.19.44.104"

    vars.hello_world = {
        hello_world_text = "this is my output text"
    }
}

apply Service "hello_world_service" {
    import "generic-service"

    check_command = "hello_world_command"
    vars += config

    assign where host.vars.hello_world
}
