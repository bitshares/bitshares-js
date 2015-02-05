{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
{TransactionBuilder} = require '../wallet/transaction_builder'
{Aes} = require '../ecc/aes'
{ExtendedAddress} = require '../ecc/extended_address'
{ChainInterface} = require '../blockchain/chain_interface'
{ChainDatabase} = require '../blockchain/chain_database'
{BlockchainAPI} = require '../blockchain/blockchain_api'

config = require '../wallet/config'
LE = require('../common/exceptions').LocalizedException
q = require 'q'

# merge from bitshares/libraries/api/wallet_api.json
libraries_api_wallet = require '../wallet/wallet_api.json'

###*
    Mimics bitshares_client RPC calls as close as possible. 
    Any functions matching an RPC method will be automatically
    matched and called in place of the native RPC call.
###
class WalletAPI
    
    constructor:(@rpc, @rpc_pass_through)->
        if @rpc and not @rpc.request
            throw new Error 'expecting rpc object'
        
        @blockchain_api = new BlockchainAPI @rpc
        @chain_interface = new ChainInterface @blockchain_api
    
    WalletAPI.libraries_api_wallet = libraries_api_wallet
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        wallet_db = WalletDb.open wallet_name
        unless wallet_db
            throw new LE 'wallet.not_found', [wallet_name]
        
        @_open_from_wallet_db wallet_db
        return
        
    _open_from_wallet_db:(wallet_db)->
        @wallet = new Wallet wallet_db, @rpc
        @transaction_ledger = new TransactionLedger()
        @chain_database = new ChainDatabase wallet_db, @rpc
        return @
    
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
    
    backup_create:()->
        LE.throw "wallet.must_be_opened" unless @wallet
        if window
            window.document.location = (
                'data:Application/octet-stream,' +
                encodeURIComponent(
                    JSON.stringify @wallet.wallet_db.wallet_object,null,4
                )
            )
        else
            throw 'not implemented'
        
        return "OK"
    
    ###* @return promise: {string} public key ###
    account_create:(account_name, private_data)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.account_create account_name, private_data
    
    _transaction_builder:()->
        LE.throw "wallet.must_be_opened" unless @wallet
        LE.throw 'wallet.must_be_unlocked' unless @wallet.aes_root
        new TransactionBuilder(
            @wallet, @rpc, @wallet.aes_root
        )
    
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
        asset = @chain_interface.get_asset(asset_symbol)
        payer = @wallet.get_chain_account paying_account_name
        sender = if paying_account_name is from_account_name then payer else @wallet.get_chain_account from_account_name
        recipient = @wallet.get_chain_account to_account_name
        q.all([asset, payer, sender, recipient]).spread (asset, payer, sender, recipient)=>
            unless asset
                error = new LE 'blockchain.unknown_asset', [asset]
                defer.reject error
                return
            
            # todo, catch insufficient funds error and try again with a fee asset_id of 0
            @wallet.get_transaction_fee(asset.id).then (fee)=>
                amount = ChainInterface.to_ugly_asset amount_to_transfer, asset
                builder = @_transaction_builder()
                builder.deposit_asset(
                    payer, recipient, amount
                    memo_message, selection_method, sender.owner_key
                    use_stealth_address = !recipient.meta_data?.type is "public_account"
                    fee
                )
                @_sign_and_send(builder).then (record)->
                    record
    
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
        account_type = 'public_account'
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        fee = @wallet.get_transaction_fee()
        account_check = @chain_interface.valid_unique_account account_name
        q.all([account_check, fee]).spread (account_check, fee)=>
            builder = @_transaction_builder()
            builder.account_register(
                account_name
                pay_with_account
                public_data
                delegate_pay_rate
                account_type
                fee
            )
            @_sign_and_send(builder).then (record)->
                record
    
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
    
    # blockchain_get_info has wallet attributes in it
    blockchain_get_info:->
        @rpc_pass_through('get_info').then (info)=>
            console.log '... info',JSON.stringify info
            info = info.result
            for key in Object.keys info
                if key.match /^wallet_/
                    console.log '... delete',JSON.stringify 'del'
                    delete info[key]
            info['wallet_open'] = if @wallet then true else false
            info['wallet_unlocked'] = not @wallet?.locked()
            info
            #info['wallet_unlocked_until']="xx hours in the future"
            #info['wallet_unlocked_until_timestamp']=(
            #    if not @wallet?.locked()
            #        @wallet.unlocked_until().toISOString().split('.')[0]
            #)
    
    get_transaction_fee:(symbol)->
        throw new Error 'symbol is required' unless symbol
        @wallet.get_transaction_fee 0
        #@chain_interface.get_asset(symbol).then (asset)=>
        #    @wallet.get_transaction_fee(asset.asset_id)
    
    get_setting:(key)->
        LE.throw "wallet.must_be_opened" unless @wallet
        value = @wallet.get_setting key
        return key: key, value: value
        
    set_setting:(key, value)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.set_setting key, value
        
    get_account:(name)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.get_chain_account name
    
    list_accounts:->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.list_accounts()
    
    list_my_accounts:->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.list_accounts just_mine=true
    
    account_yield:->
        console.log 'WARN: account_yield is not implemented'
        []
        
    dump_private_key:(account_name)->
        LE.throw "wallet.must_be_opened" unless @wallet
        @wallet.dump_private_key account_name
     
    account_balance_extended:(account_name)->
        @account_balance account_name, extended = true
    
    ###* @return {promise} [
        [
            account_name,[ [asset_id,amount] ]
        ]
    ] ###
    account_balance:(account_name, extended = false)->
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
            builder.get_account_balance_records(account_name, extended).then (key_records)->
                if (Object.keys key_records).length is 0
                    defer.resolve()
                    return
                for public_key in Object.keys key_records
                    for record in key_records[public_key]
                        continue if record.length is 0
                        rec = record[1]
                        asset_id = rec.condition.asset_id
                        total account_name, asset_id, if extended
                            builder.get_extended_balance rec
                        else
                            rec.balance
                defer.resolve()
            ,(error)->
                defer.reject error
            .done()
            defer.promise
        
        account_name = null if account_name is ""
        p=[]
        if account_name
            p.push by_account account_name
        else
            for account in @wallet.list_accounts just_mine=true
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
            
            defer.resolve account_balances.sort (a,b)->
                if a[0] < b[0] then -1 else if a[0] > b[0] then 1 else 0
        
        defer.promise
    
    #wallet_account_yield
    
    #batch wallet_check_vote_proportion
    
    account_transaction_history:(
        account_name=""
        asset=""
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        asset_id = if asset.match /^[0-9]$/
            parseInt asset
        else
            if asset is ""
                -1
        
        if asset_id
            return @wallet.account_transaction_history(
                account_name
                asset_id
                limit
                start_block_num
                end_block_num
            )
        
        @chain_interface.get_asset(asset_symbol).then (asset_lookup)=>
            LE.throw "blockchain.unknown_asset",[asset] unless asset_lookup
            asset_id = asset_lookup.id
            @wallet.account_transaction_history(
                account_name
                asset_id
                limit
                start_block_num
                end_block_num
            )
    
    market_order_list:->
        console.log 'WARN Not Implemented'
        []
    
    ###
    
    
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
        builder.finalize().then ()=>
            builder.sign_transaction()
            record = builder.get_transaction_record()
            #@wallet.save_transaction record
            #p = [] p.push 
            console.log '... record.trx',JSON.stringify record.trx,null,3
            @blockchain_api.broadcast_transaction(record.trx).then ->
                record
            ### For TITAN support:
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
            #q.all(p)
    
exports.WalletAPI = WalletAPI
