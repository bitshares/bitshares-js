{WalletDb} = require '../wallet/wallet_db'
{WalletAPI} = require '../client/wallet_api'
{RelayNode} = require '../net/relay_node'
config = require '../config'
q = require 'q'

class JsClient
    
    constructor:(@rpc, @Growl)->
        @rpc_pass_through =
            request: @rpc.request
        
        @init_defer = q.defer()
        @rpc.request = (method, params, error_handler) =>
            @init_defer.promise.then =>
                @request method, params, error_handler
        
        relay_node = new RelayNode @rpc_pass_through
        relay_node.init().then => #get it started..
            config.bts_address_prefix = relay_node.base_asset_symbol
            config.chain_id = relay_node.chain_id
            @wallet_api = new WalletAPI @rpc, @rpc_pass_through, relay_node
            
            #keep last (in relay_node.init())
            @init_defer.resolve()
        
        @aliases=((def)-># add aliases
            aliases = {}
            for method in def.methods
                if method.aliases
                    for alias in method.aliases
                        aliases[alias] = method.method_name
            
            alias=(cmd, alias_array)->
                aliases[a]=cmd for a in alias_array
            

            aliases
        )(WalletAPI.libraries_api_wallet)
    
    init:->
        @init_defer.promise
    
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
            # general get_info has wallet attributes in it
            return @wallet_api['general_get_info'] if method is 'get_info'
            return null if prefix_index is -1
            api_group = method.substring 0, prefix_index
            api_function = method.substring prefix_index + 1
            switch api_group
                when 'wallet'
                    @wallet_api[api_function]
        )()
        
        # logging is per developer, listed in .gitignore, and may be undefined
        @rpc_hide = (->
            dev_private = require '../deploy/dev_private'
            dev_private.rpc_hide
        )()
        
        handle_response=(intercept=true) =>
            if @rpc_hide
                unless (
                    @rpc_hide.hide_all or
                    @rpc_hide[method] or
                    (
                        method is "batch" and
                        @rpc_hide[params[0]]
                    )
                )
                    type = if intercept then "intercept" else "pass-through"
                    error_label = if err then "error:" else ""
                    error_value = if err then (if err.stack then err.stack else (JSON.stringify err)) else ""
                    return_label = if ret then "return:" else ""
                    return_value = if ret then ret else "" # stringify will produce too much output
                    console.log "[BitShares-JS] #{api_group}\t#{type}\t", method, params,return_label,return_value,error_label,error_value
            
            if err
                err = message:err unless err.message
                @Growl.error "", err.message
                err = data:error: err
                defer.reject err
                error_handler err if error_handler
            else
                ret = null if ret is undefined
                defer.resolve result:ret
            
            return
        
        if not fun and method.match /^wallet_/
            err = new Error "Not Implemented [#{method}]"
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