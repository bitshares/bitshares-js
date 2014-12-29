{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{Aes} = require '../ecc/aes'
{ExtendedAddress} = require '../ecc/extended_address'
{ChainInterface} = require '../blockchain/chain_interface'
{config} = require '../wallet/config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'

###*
    Mimics bitshares_client RPC calls as close as possible. 
    Any functions matching an RPC method will be automatically
    matched and called in place of the native RPC call.
###
class WalletAPI
    
    constructor:(@wallet, @rpc)->
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            throw new LE 'wallet.not_found', [wallet_name]
        
        @wallet = new Wallet wallet_db, @rpc
        return
    
    create: (wallet_name = "default", new_password, brain_key)->
        Wallet.create wallet_name, new_password, brain_key
        @open wallet_name
        @wallet.unlock config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC, new_password
        return
        
    close:->
        @wallet = null
        return
        
    #get_info: ->
    #    unlocked: @wallet.unlocked()
        
    validate_password: (password)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.validate_password password
        return
    
    unlock:(timeout_seconds = config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC, password)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.unlock timeout_seconds, password
        return
        
    lock:->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.lock()
        return
        
    locked: ->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.locked()
        
    account_create:(account_name, private_data)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.account_create account_name, private_data
    
    account_register:(
        account_name
        pay_from_account
        public_data = null
        delegate_pay_rate = -1
        account_type = 'titan_account'
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.account_register(
            account_name
            pay_from_account
            public_data
            delegate_pay_rate
            account_type
        )
    
        
    #<account_name> <pay_from_account> [public_data] [delegate_pay_rate] [account_type]
    


    ###*
        Save a new wallet and return a WalletDb object.  Resolves as an error 
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
        unlocked: not @wallet?.locked() #if @wallet then not @wallet.locked() else null
        name: @wallet.wallet_db?.wallet_name
        transaction_fee:@wallet.get_transaction_fee()
        
    get_setting:(key)->
        LE.throw "wallet.must_be_opened" unless @wallet
        value = @wallet.get_setting key
        return key: key, value: value
        
    set_setting:(key, value)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.set_setting key, value
        
    get_account:(name)->
        LE.throw "wallet.must_be_opened" unless @wallet
        account = @wallet.get_account name
        unless account.registration_date
            account.registration_date = "1970-01-01T00:00:00"
        account
    
    list_accounts:->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.list_accounts()
        
    dump_private_key:(account_name)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.dump_private_key account_name
        
    #wallet_account_balance
    
    #wallet_account_yield
    
    #batch wallet_check_vote_proportion
    
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
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.account_transaction_history(
            account_name
            asset_id
            limit
            start_block_num
            end_block_num
        )
        
        
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