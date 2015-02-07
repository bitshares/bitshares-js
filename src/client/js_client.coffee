{WalletAPI} = require '../client/wallet_api'
{RelayNode} = require '../net/relay_node'
q = require 'q'

class JsClient
    
    constructor:(@rpc, @Growl)->
        @rpc_pass_through =
            request: @rpc.request
        relay_node = new RelayNode @rpc_pass_through
        relay_node.init() #get it started..
        @rpc.request = (method, params, error_handler) =>
            @request method, params, error_handler
        
        @wallet_api = new WalletAPI @rpc, @rpc_pass_through, relay_node
        @log_hide=
            blockchain_get_info: on
            wallet_get_info: on
            blockchain_get_security_state:on
            wallet_account_transaction_history: off
            blockchain_list_address_transactions: off
            get_config:on
        
        @aliases=((def)-># add aliases
            aliases = {}
            for method in def.methods
                if method.aliases
                    for alias in method.aliases
                        aliases[alias] = method.method_name
            
            alias=(cmd, alias_array)->
                aliases[a]=cmd for a in alias_array
            
            alias 'blockchain_get_info', [
                "get_info","getconfig", "get_config"
                "config", "blockchain_get_config"
            ]
            aliases
        )(WalletAPI.libraries_api_wallet)
    
    request: (method, params, error_handler) =>
        defer = q.defer()
        ret = null
        err = null
        promise = null
        api_group = null
        
        if method is 'execute_command_line' # console
            params = params[0]
            i = params.indexOf ' '
            if i isnt -1
                method = params.substring 0, i
                params = params.substring i
                # parameters by space with optional double quotes (if quoted will not split)
                params = params.match /(".*?")|(\S+)/g
                for i in [0...params.length] by 1
                    p = params[i]
                    p = p.replace /^"/, ''
                    p = p.replace /"$/, ''
                    params[i] = p
            else
                method = params
                params = []
        
        method = @aliases[method] or method 
        
        # function for local implementation
        fun = (=>
            prefix_index = method.indexOf '_'
            return null if prefix_index is -1
            api_group = method.substring 0, prefix_index
            api_function = method.substring prefix_index + 1
            switch api_group
                when 'wallet'
                    @wallet_api[api_function]
                when 'blockchain'
                    # blockchain_get_info has wallet attributes in it
                    if api_function is 'get_info'
                        @wallet_api['blockchain_get_info']
        )()
        
        handle_response=(intercept=true) =>
            unless @log_hide[method] or (method is "batch" and @log_hide[params[0]])
                type = if intercept then "intercept" else "pass-through"
                error_label = if err then "error:" else ""
                error_value = if err then (if err.stack then err.stack else (JSON.stringify err)) else ""
                return_label = if ret then "return:" else ""
                return_value = if ret then ret else "" # stringify will produce too much output
                console.log "[BitShares-JS] #{api_group}\t#{type}\t", method, params,return_label,return_value,error_label,error_value
            
            if err
                err = message:err unless err.message
                err = data:error: err
                defer.reject err
                error_handler err if error_handler
            else
                ret = null if ret is undefined
                defer.resolve result:ret
            
            return
        
        if not fun and method.match /^wallet_/
            err = new Error 'Not Implemented'
            @Growl.error "", 'Not Implemented'
            handle_response()
            return defer.promise
        
        if fun #and false # false to disable bitshares-js but keep logging
            try
                ret = fun.apply(@wallet_api, params)
                if ret?["then"]
                    promise = ret

            catch error
                message = if error.message then error.message else error
                err = error
                #error = message:error unless error.message
                if message.match /^wallet.not_found/
                    @event 'wallet.not_found'
                else if message.match /^wallet.must_be_opened/
                    @event 'wallet.must_be_opened'
            finally
                handle_response() unless promise
            
            if promise
                #console.log 'promise',method
                p = ret.then (result)->
                    ret = result
                    handle_response()
                    return
                , (error)->
                    err = error
                    handle_response()
                    return
                # were missing exceptions, maybe this is better now that
                # it uses bitshares-js q package
                if p['fail']
                    p.fail()
                else if p['done']
                    p.done()
        else # proxy
            #console.log '[BitShares-JS] pass-through\t',method,params
            this_error_handler=(error)->
                err = error
                handle_response intercept=false
            try
                promise = @rpc_pass_through.request method, params, this_error_handler
                promise.then(
                    (response)->
                        ret = response.result
                        handle_response intercept=false
                        return
                    (error)->
                        err = error
                        handle_response intercept=false
                        return
                )
            catch error
                err = error
                handle_response intercept=false
        
        defer.promise
    
    events:{}
    event:(name, callback)->
        if callback
            throw 'event already registered' if @events[name]
            @events[name]=callback
        else
            @events[name]?()
    
exports.JsClient = JsClient