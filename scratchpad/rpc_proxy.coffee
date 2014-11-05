class RpcProxy
    
    net = require 'net'
    
    class RpcBuffer

        constructor: (@run_callback) ->
            @payload = ""

        save: (msg) ->
            msg = msg.toString() unless typeof msg is 'string'
            @payload += msg
            #console.log 'save',msg
            if /}$/.test @payload.trim()
                #console.log "run_callback",@payload
                @run_callback @payload
                @payload = ""
            else
                if /}\n+{/.test @payload
                    s = @payload.split /}\n*{/
                    # incomplete
                    @payload = s[s.length]
                    # completed messages
                    for cmd in s[0...-1]
                        #console.log "run_callback*",cmd
                        @run_callback cmd

    constructor: (@local_port, @remote_port, @remote_host) ->
        local_server = net.createServer (local_connection) =>
            @local_connection = local_connection
            @local_connection.on 'data', (msg) =>
                @remote_buffer.save msg

        @remote_connection = net.createConnection @remote_port, @remote_host
        @remote_connection.on 'data', (msg) =>
            @local_buffer.save msg

        @remote_buffer = new RpcBuffer (msg) =>
            console.log ">>", msg
            @remote_connection.write msg

        @local_buffer = new RpcBuffer (msg) =>
            console.log "<<", msg
            @local_connection.write msg

        local_server.listen @local_port
        #remote_connection.on 'connect', () =>

new RpcProxy 45000, 33000