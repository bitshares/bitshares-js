{config} = require './config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'

class ChainInterface
    
    constructor:(@rpc)->
    
    ChainInterface.is_valid_account_orThrow=(account_name)->
        unless ChainInterface.is_valid_account_name account_name
            LE.throw 'wallet.invalid_account_name',[account_name]
            
    ChainInterface.is_valid_account_name=(account_name)->
        return false unless account_name
        return false if account_name.length < config.BTS_BLOCKCHAIN_MIN_NAME_SIZE
        return false if account_name.length > config.BTS_BLOCKCHAIN_MAX_NAME_SIZE
        return false unless /^[a-z]/i.test(account_name) # starts with alpha
        return false unless /[a-z0-9]$/i.test(account_name)
        return false if /[A-Z]$/.test(account_name)
        
        subname = account_name
        supername = ""
        dot = account_name.indexOf '.'
        if dot isnt -1
            subname = account_name.substring 0, dot
            supername = account_name.substring dot+1
        return false unless /[a-z0-9]$/i.test(subname) or /[A-Z]$/.test(subname)
        return false unless /[a-z0-9-\.]$/i.test subname
        return true if supername is ""
        is_valid_acccount_name supername
        
    valid_unique_account:(account_name)->
        defer = q.defer()
        try
            ChainInterface.is_valid_account_orThrow account_name
            @rpc.request("blockchain_get_account",[account_name]).then (resp)=>
                if resp
                    error = new LE 'wallet.blockchain_account_already_exists', [account_name]
                    defer.reject error
                else
                    defer.resolve()
            .done()
        catch error
            console.log error
            defer.reject error
        defer.promise
    

exports.ChainInterface = ChainInterface