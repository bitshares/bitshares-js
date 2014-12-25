#$q = require 'q'
{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
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
    
    constructor: (@wallet, @wallet_db, @transaction_ledger) -> #, @rpc = null
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            throw new LE 'wallet.not_found', [wallet_name]
        
        @wallet_db = wallet_db
        @wallet = new Wallet wallet_db
        @transaction_ledger = new TransactionLedger @wallet_db
        return
    
    create: (wallet_name = "default", new_password, brain_key)->
        Wallet.create wallet_name, new_password, brain_key
        @open(wallet_name)
        @wallet.unlock config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC, new_password
        return
        
    close:->
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
        @wallet_db.validate_password password
        @aes_root = Aes.fromSecret password
        unlock_timeout_id = setTimeout ()=>
            @lock()
        ,
            timeout_seconds * 1000
        return
        
    lock:->
        @aes_root = undefined
        return
        
    locked: ->
        @aes_root is undefined

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
        
    account_create:(account_name, private_data)->
        unless Wallet.is_valid_account account_name
            LE.throw 
    
    list_accounts:->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        accounts = @wallet_db.list_accounts()
        accounts.sort (a, b)->
            a.name < b.name
        accounts
        
    ### Query by asset symbol (if needed).. Better if the caller can provide the asset_id instead
    account_transaction_history:(
        account_name=""
        asset=""
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        account_name = null if account_name is ""
        asset = null if asset is ""
        asset = 0 unless asset
        @rpc.request("blockchain_get_asset_id", [asset]).then(result)=>
            @account_transaction_history2(
                account_name
                result.id
                limit
                start_block_num
                end_block_num
            ).then(
                ...
            )
    ###
    
    account_transaction_history:(
        account_name=""
        asset_id=0
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        unless @wallet_db
            LE.throw "wallet.must_be_opened"
        
        account_name = null if account_name is ""
        unless /^\d+$/.test asset_id
            throw "asset_id should be a number, instead got: #{asset_id}"
            
        history = @transaction_ledger.get_transaction_history(
            account_name
            start_block_num
            end_block_num
            asset_id
        )
        history.sort (a,b)->
            if (
                a.is_confirmed and
                b.is_confirmed and
                a.block_num isnt b.block_num
            )
                return a.block_num < b.block_num
                
            if a.timestamp isnt b.timestamp
                return a.timestamp < b.timestamp
                
            a.trx_id < b.trx_id
        
        return history if limit is 0 or Math.abs(limit) >= history.length
        return history.slice 0, limit if limit > 0
        history.slice history.length - -1 * limit, history.length 
        
        
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