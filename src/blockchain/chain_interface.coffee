config = require './config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'
localStorage = require '../common/local_storage'

class ChainInterface
    
    constructor:(@blockchain_api)->
    
    ChainInterface.is_valid_account_orThrow=(account_name)->
        unless ChainInterface.is_valid_account_name account_name
            LE.throw 'wallet.invalid_account_name',[account_name]
        return
            
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
        
    ###* @return asset ###
    ChainInterface.to_ugly_asset=(amount_to_transfer, asset)->
        amount = amount_to_transfer
        amount *= asset.precision
        #example: 100.500019 becomes 10050001
        amount = parseInt amount.toString().split('.')[0]
        amount:amount
        asset_id:asset.id
    
    valid_unique_account:(account_name)->
        defer = q.defer()
        try
            ChainInterface.is_valid_account_orThrow account_name
            @blockchain_api.get_account(account_name).then (resp)->
                if resp
                    error = new LE 'blockchain.account_already_exists', [account_name]
                    defer.reject error
                else
                    defer.resolve()
            , (error)->
                defer.resolve error
            #.done() null ptr in browser
        catch error
            defer.reject error.stack
        defer.promise
    
    ###* Use cache or query ###
    get_asset:(symbol_name, refresh_cache = false)->
        cache_key = 'chain-asset-'+symbol_name
        unless refresh_cache
            asset_string = localStorage.getItem cache_key
            if asset_string
                defer = q.defer()
                defer.resolve JSON.parse asset_string
                return defer.promise
        
        @blockchain_api.get_asset(symbol_name).then (asset)=>
            unless asset
                return null
            unless asset.precision
                #ref: wallet::transfer_asset_to_address
                asset.precision = 1
                console.log 'INFO using default precision 1',asset
            asset_string = JSON.stringify asset,null,0
            localStorage.setItem cache_key, asset_string
            asset
    
    # refresh_assets:-> blockchain_list_assets probably once a day or if the user requests a refresh ...
        
    
    
exports.ChainInterface = ChainInterface
