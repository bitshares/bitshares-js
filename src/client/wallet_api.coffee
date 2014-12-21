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
        
    close:-> $q (resolve,reject)->
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
        return
        
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
            
    get_info:->
        open: if @wallet then true else false
        unlocked: not @wallet?.locked()#if @wallet then not @wallet.locked() else null
        name: @wallet_db?.wallet_name
        transaction_fee: "0.50000 XTS"#@wallet.transaction_fee()
        
    get_setting:(key)->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        @wallet_db.get_setting key
        
    set_setting:(key, value)->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        @wallet_db.set_setting key, value
        
    list_accounts:->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        accounts = @wallet_db.list_accounts()
        accounts.sort (a, b)->
            a.name < b.name
        accounts
    ###
    account_transaction_history #["", "", 0, 0, -1]
    account_yield
    account_balance
    batch wallet_check_vote_proportion [["acct",]]
        ret [
            negative_utilization:0
            utilization:0
        ]
    account_create ["bbbb", {gui_data: website:undefined}]
        ret result: "XTS6mF3osHjZANkoE65gBYdJff5qe75KLxnLV5wx5bD9QWSEhGrUW"
        
    get_account ["bbb"]
        result:active_key:"",akhistory,approved:0,id,index,is_my_account...
    ###
    
    
exports.WalletAPI = WalletAPI