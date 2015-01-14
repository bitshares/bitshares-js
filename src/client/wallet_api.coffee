{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
{TransactionBuilder} = require '../wallet/transaction_builder'
{Aes} = require '../ecc/aes'
{ExtendedAddress} = require '../ecc/extended_address'
{ChainInterface} = require '../blockchain/chain_interface'
{BlockchainAPI} = require '../blockchain/blockchain_api'

config = require '../wallet/config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'

###*
    Mimics bitshares_client RPC calls as close as possible. 
    Any functions matching an RPC method will be automatically
    matched and called in place of the native RPC call.
###
class WalletAPI
    
    constructor:(@wallet, @rpc)->
        @blockchain_api = new BlockchainAPI @rpc
        @chain_interface = new ChainInterface @blockchain_api
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            throw new LE 'wallet.not_found', [wallet_name]
        
        @transaction_ledger = new TransactionLedger @wallet_db
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
    
    ###* @return promise: {string} public key ###
    account_create:(account_name, private_data)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.account_create account_name, private_data
    
    get_account:(account_name)->
        @wallet.get_account account_name
    
    _transaction_builder:()->
        LE.throw "wallet.must_be_opened" unless @wallet
        LE.throw 'wallet.must_be_unlocked' unless @wallet.aes_root
        new TransactionBuilder(
            @wallet, @rpc, @transaction_ledger, @wallet.aes_root
        )
    
    ###* TITAN ###
    transfer:( 
        amount, asset_symbol, 
        from_name, to_name
        memo_message = "", selection_method = ""
    )->
        @transfer_from(
            amount, asset_symbol, 
            from_name, from_name, to_name
            memo_message, selection_method
        )
    
    transfer_from:(
        amount_to_transfer, asset_symbol, 
        paying_account_name, from_account_name, to_account_name
        memo_message = "", selection_method = ""
    )->
        
        LE.throw "wallet.must_be_opened" unless @wallet
        defer = q.defer()
        asset = @chain_interface.get_asset(asset_symbol)
        payer = @wallet.get_account paying_account_name
        sender = @wallet.get_account from_account_name
        recipient = @wallet.get_account to_account_name
        try
            q.all([asset, payer, sender, recipient]).spread (asset, payer, sender, recipient)=>
                unless asset
                    error = new LE 'blockchain.unknown_asset', [asset]
                    defer.reject error
                    return
            
                amount = ChainInterface.to_ugly_asset amount_to_transfer, asset
                builder = @_transaction_builder()
                builder.deposit_asset(
                    payer, recipient, amount
                    memo_message, selection_method, sender.owner_key
                )
                @_sign_and_send(builder).then (record)->
                    defer.resolve record 
            .done()
        catch error
            defer.reject error
        defer.promise
        
    ###* Transfer to a public address (non TITAN) ##
    transfer_to_address:(
        amount
        asset_symbol
        from
        to_address
        memo_message = ""
        vote_method = ""#vote_recommended"
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        defer = q.defer()
        @chain_interface.get_asset(asset_symbol).then(
            (asset)=>
                unless asset
                    error = new LE 'blockchain.unknown_asset', [asset]
                    defer.reject error
                    return
                builder = @ransaction_builder()
                builder.wallet_transfer_to_address(
                    amount, asset, from, to_address
                    memo_message, vote_method
                ).then(
                    (signed_trx)=>
                        @broadcast defer, signed_trx
                    (error)->
                        defer.reject error
                ).done()
            (error)->
                defer.reject error
        ).done()
        defer.promise
    ###
    
    account_register:(
        account_name
        pay_with_account
        public_data = null
        delegate_pay_rate = -1
        account_type = 'titan_account'
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        defer = q.defer()
        @chain_interface.valid_unique_account(account_name).then ()=>
            builder = @_transaction_builder()
            builder.account_register(
                account_name
                pay_with_account
                public_data
                delegate_pay_rate
                account_type
            )
            @_sign_and_send(builder).then (record)->
                defer.resolve record
            .done()
        , (error)->
            defer.reject error
        .done()
        defer.promise
    
    #account_retract:(account_to_update, pay_from_account)->
    #   record = @wallet.retract_account( account_to_update, pay_from_account, true );
    #   @wallet.cache_transaction( record );
    #   @network_broadcast_transaction( record.trx );
    #   record
        
    broadcast_transaction:(defer, signed_trx)->
        #console.log 'signed_trx',JSON.stringify signed_trx,null,2
        @rpc.request("blockchain_broadcast_transaction", [signed_trx]).then(
            (result)->
                # returns void
                defer.resolve signed_trx
            (error)->
                defer.reject error
        ).done()
    
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
    
    list_my_accounts:->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.list_my_accounts()
    
    account_yield:->
        console.log 'WARN: account_yield is not implemented'
        []
        
    dump_private_key:(account_name)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.dump_private_key account_name
     
    ###* @return {promise} [
        [
            account_name,[ [asset_id,amount] ]
        ]
    ] ###
    account_balance:(account_name)->
        ###
            LE.throw "wallet.must_be_opened" unless @wallet
            @wallet.get_spendable_account_balances account_name
        _account_balance:(account_name)->
        ###
        LE.throw "wallet.must_be_opened" unless @wallet
        totals_by_account={}
        total=(account_name, asset_id, balance)->
            totals = totals_by_account[account_name]
            unless totals
                totals = {}
                totals_by_account[account_name] = totals
            
            amount = totals[asset_id]
            amount = 0 unless amount
            totals[asset_id] = amount + balance
        
        by_account=(account_name)=>
            defer = q.defer()
            builder = @_transaction_builder()
            builder.get_account_balance_records(account_name).then (balance_records)=>
                for record in balance_records
                    #balance_id = record[0]
                    rec = record[1]
                    asset_id = rec.condition.asset_id
                    balance = builder.get_spendable_balance(rec)
                    total account_name, asset_id, balance
                defer.resolve()
            .done()
            defer.promise
        
        account_name = null if account_name is ""
        p=[]
        if account_name
            p.push by_account(account_name)
        else
            for account in @wallet.list_my_accounts()
                p.push by_account account.name
        
        defer = q.defer()
        q.all(p).then (records)->
            account_balances = []
            for account_name in Object.keys totals_by_account
                totals = totals_by_account[account_name]
                balences = []
                for asset_id in Object.keys totals
                    balance = totals[asset_id]
                    balences.push [asset_id, balance]
                account_balances.push [
                    account_name
                    balences
                ]
            defer.resolve account_balances
        defer.promise
    
    #wallet_account_yield
    
    #batch wallet_check_vote_proportion
    
    ### Query by asset symbol .. 
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
    
    _sign_and_send:(builder)->
        defer = q.defer()
        builder.finalize().then ()=>
            builder.sign_transaction()
            record = builder.get_transaction_record()
            p = []
            @wallet.save_transaction record
            p.push @blockchain_api.broadcast_transaction(record.trx)
            ###
            for notice in builder.encrypted_notifications()
                p.push @mail_client.send_encrypted_message(
                    notice,from_account_name
                    to_account_name
                    recipient.owner_key
                )
            ###
            ### cpp
            notices = builder->encrypted_notifications()
            for notice in notices
                mail.send_encrypted_message(
                    notice, sender, receiver, 
                    sender.owner_key
                )
                # a second copy for one's self
                mail.send_encrypted_message(
                    notice, sender, sender, 
                    sender.owner_key
                )
            ###
            q.all(p).then ()->
                defer.resolve record
        .done()
        defer.promise
    
exports.WalletAPI = WalletAPI
