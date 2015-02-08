config = require './config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'
localStorage = require '../common/local_storage'

###* 
    Chain interface is generally the interface that is useful for both chain 
    database and pending chain state PLUS general helper functions that don't 
    depend on the current chain state.
###
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
    get_asset:(name_or_id, refresh_cache = false)->
        cache_key = 'chain-asset-'+name_or_id
        unless refresh_cache
            asset_string = localStorage.getItem cache_key
            if asset_string
                defer = q.defer()
                defer.resolve JSON.parse asset_string
                return defer.promise
        
        @blockchain_api.get_asset(name_or_id).then (asset)=>
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
    ###* Default fee is in the base asset ID ###
    convert_base_asset_amount:(asset_name_or_id = 0, amount)->
        throw new Error "amount is required" unless amount
        throw new Error "amount should be an integer" if amount.amount 
        defer = q.defer()
        if asset_name_or_id is 0
            defer.resolve
                asset_id: 0
                amount: amount
            return defer.promise
        
        target_asset = @get_asset asset_name_or_id
        base_asset = @get_asset 0
        q.all([target_asset, base_asset]).spread (target_asset, base_asset)=>
            if target_asset.id is 0
                asset_id: 0
                amount: amount
            else
                @blockchain_api.market_status(target_asset.symbol, base_asset.symbol).then (market)->
                    feed_price = market.current_feed_price
                    if market.current_feed_price is 0
                        asset_id: 0
                        amount: amount
                    else
                        asset_id: target_asset.id
                        amount: amount * feed_price

exports.ChainInterface = ChainInterface
