object Host "server9" {
    import "generic-host"
    address = "172.19.44.104"
    // a single variable example
    vars.hello_aaron_text = "single text variable"
}

apply Service "hello_service" {
    import "generic-service"
    check_command = "hello_arron"
    assign where host.vars.hello_aaron_text
}


object CheckCommand "hello_aaron" {
    command = [ CustomPluginDir + "/hello_aaron.bash" ]
    arguments = {
     "text" = {
         value = "$hello_aaron_text$"
         description = "the text we are repeating"
         skip_key = true
     }
 }
}
