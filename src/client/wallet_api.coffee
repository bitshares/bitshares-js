$q = require 'q'
{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{Aes} = require '../ecc/aes'
LE = require('../common/exceptions').LocalizedException

class WalletAPI
    
    constructor: (@wallet, @rpc = null) ->
        @wallet_db = @wallet.wallet_db
    
    ###* open from persistent storage ###
    open:(wallet_name = "default")->
        defer = $q.defer()
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            defer.reject new LE 'wallet.not_found', [wallet_name]
        else
            @wallet_db = wallet_db
            @wallet = Wallet.fromWalletDb wallet_db
        defer.resolve @wallet
        defer.promise
    
    close:()-> $q (resolve,reject)->
        defer = $q.defer()
        @wallet_db = null
        @wallet = null
        defer.resolve()
        defer.promise
        
    #get_info: ->
    #    unlocked: @wallet.unlocked()
        
    validate_password: (password)->
        defer = $q.defer()
        unless @wallet_db
            defer.reject new LE "wallet.must_be_opened"
            return defer.promise
        
        try
            @wallet_db.validate_password password
            defer.resolve()
        catch error
            defer.reject(error)
        
        defer.promise
    
    unlock:(timeout_seconds, password)->
        defer = $q.defer()
        try
            unlock_timeout_id = @wallet.unlock(timeout_seconds, password)
            defer.resolve(unlock_timeout_id)
        catch error
            defer.reject(error)
        defer.promise
        
    lock:->
        defer = $q.defer()
        @wallet.lock()
        defer.resolve()
        defer.promise

    ###* 
        @return {promise}
        
        Save a new wallet and resovles with a WalletDb object.  Resolves as an error 
            if wallet exists or is unable to save in local                                     storage.
    ###            
    backup_restore_object:(wallet_object, wallet_name)->
        defer = $q.defer()
        if WalletDb.open wallet_name
            defer.reject new LE 'wallet.already_exists', [wallet_name]
            return defer.promise
        try
            wallet_db = new WalletDb wallet_object, wallet_name
            wallet_db.save()
            defer.resolve wallet_db
        catch error
            le = new LE 'wallet.save_error', [wallet_name, error], error
            defer.reject le
            throw le
        defer.promise
    
exports.WalletAPI = WalletAPI