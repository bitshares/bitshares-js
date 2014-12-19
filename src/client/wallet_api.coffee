$q = require 'q'
{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{Aes} = require '../ecc/aes'
{ExtendedAddress} = require '../ecc/extended_address'
LE = require('../common/exceptions').LocalizedException
config = require '../wallet/config'

###*
    Mimics bitshares_client RPC calls as close as possible. 
    Any functions matching an RPC method will be automatically
    matched and called in place of the native RPC call.
###
class WalletAPI
    
    constructor: (@wallet) -> #, @rpc = null
        @wallet_db = @wallet?.wallet_db
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        WalletDb.delete "default"
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            throw new LE 'wallet.not_found', [wallet_name]
        
        @wallet_db = wallet_db
        @wallet = Wallet.fromWalletDb wallet_db
        return
    
    create: (wallet_name = "default", new_password, brain_key)->
        @wallet = Wallet.create wallet_name, new_password, brain_key
        @wallet.unlock config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC, new_password
        return
        
    close:()-> $q (resolve,reject)->
        @wallet_db = null
        @wallet = null
        return
        
    #get_info: ->
    #    unlocked: @wallet.unlocked()
        
    validate_password: (password)->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        @wallet_db.validate_password password
        return
    
    unlock:(timeout_seconds, password)->
        unlock_timeout_id = @wallet.unlock timeout_seconds, password
        
    lock:->
        @wallet.lock()
        return

    ###* 
        Save a new wallet and resovles with a WalletDb object.  Resolves as an error 
        if wallet exists or is unable to save in local storage.
    ###            
    backup_restore_object:(wallet_object, wallet_name)->
        if WalletDb.open wallet_name
            LE.throw 'wallet.exists', [wallet_name]
        
        try
            wallet_db = new WalletDb wallet_object, wallet_name
            wallet_db.save()
            return wallet_db
        catch error
            LE.throw 'wallet.save_error', [wallet_name, error], error
            
    get_info:()->
        open: if @wallet then true else false
        unlocked: not @wallet?.locked()#if @wallet then not @wallet.locked() else null
        name: @wallet_db?.wallet_name
        transaction_fee: "0.50000 XTS"#@wallet.transaction_fee()
    
exports.WalletAPI = WalletAPI