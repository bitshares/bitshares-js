{Storage} = require '../common/storage'
{PublicKey} = require '../ecc/key_public'
{ExtendedAddress} = require '../ecc/extended_address'
{TransactionLedger} = require '../wallet/transaction_ledger'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{MemoData} = require '../blockchain/memo_data'
q = require 'q'

class ChainDatabase

    REGISTERED_ACCOUNT_LOOKAHEAD = 11
    
    sync_transactions_timeout_id = null
    sync_accounts_timeout_id = null
    
    constructor: (@wallet_db, @rpc, chain_id) ->
        @transaction_ledger = new TransactionLedger()
        @chain_id = chain_id.substring 0, 10
        @storage = new Storage @wallet_db.wallet_name + "_" + @chain_id
        # basic unit tests will not provide an rpc object
        if @rpc and not @rpc.request
            throw new Error 'expecting rpc object'
        @blockchain_api = new BlockchainAPI @rpc
    
    delete: ->
        len = @storage.length()
        for i in [0...len] by 1
            key = @storage.key i
            if key.indexOf(@wallet_db.wallet_name + "_" + @chain_id) is 0
                #console.log '... @storage.removeItem key', key
                @storage.removeItem key
    
    ###
        Watch for deterministic account keys beyond what was used to 
        see if any are registered from another computer wallet
        with the same key.  Also, this may be a restore.
    ###
    poll_accounts:(aes_root, shutdown=false)->
        if shutdown
            clearTimeout sync_accounts_timeout_id
            sync_accounts_timeout_id = null
        else
            # unless already polling
            unless sync_accounts_timeout_id
                sync_accounts_timeout_id = setTimeout ()=>
                        sync_accounts_timeout_id = null
                        @poll_accounts aes_root
                    ,
                        10*1000
                try
                    @sync_accounts aes_root
                catch e
                    console.log e,e.stack
    
    ###
        Watch for public transactions sent to any
        account in this database.
    ###
    poll_transactions:(shutdown=false)->
        throw new Error 'construct with rpc object' unless @rpc
        if shutdown
            clearTimeout sync_transactions_timeout_id
            sync_transactions_timeout_id = null
        else
            # unless already polling
            unless sync_transactions_timeout_id
                sync_transactions_timeout_id = setTimeout ()=>
                    sync_transactions_timeout_id = null
                    @poll_transactions()
                ,
                    10*1000
                try
                    @sync_transactions()
                catch e
                    console.log e,e.stack
    
    _account_keys:(account_name)->
        account_names = []
        if account_name
            account_names.push account_name
        else
            for account in @wallet_db.list_accounts just_mine=true
                account_names.push account.name
        
        keys=[]
        for account_name in account_names
            for key in @wallet_db.get_my_key_records account_name
                keys.push key
        keys
    
    _account_addresses:(account_name)->
        keys = @_account_keys account_name
        addresses = {}
        for key in keys
            addresses[key.account_address]=yes
        Object.keys addresses
    
    sync_accounts:(aes_root)->
        next_accounts = @wallet_db.guess_next_account_keys(
            aes_root
            REGISTERED_ACCOUNT_LOOKAHEAD
        )
        batch_params = []
        batch_params.push [next_account.public] for next_account in next_accounts
        @rpc.request("batch", [
            "blockchain_get_account"
            batch_params
        ]).then (batch_result)=>
            batch_result = batch_result.result
            for i in [0...batch_result.length] by 1
                account = batch_result[i]
                continue unless account
                next_account = next_accounts[i]
                # update the account index, create private key entries etc...
                try
                    @wallet_db.generate_new_account(
                        aes_root
                        account.name
                        account.private_data
                        _save = false
                        next_account
                    )
                    # sync direct account fields with the blockchain
                    @wallet_db.store_account_or_update account
                catch e
                    console.log "ERROR",e
            return
    
    sync_transactions:(account_name)->
        addresses = @_account_addresses account_name
        if addresses.length is 0
            #defer = q.defer()
            #defer.resolve()
            #return defer.promise
            return
        
        #address_last_block_map = (->
        #    str = @storage.getItem "address_last_block_map"
        #    if str
        #        JSON.parse str
        #    else
        #        {}
        #)()
        
        batch_args = for address in addresses
            [address, block=0] #address_last_block_map[address] or 0
        
        @rpc.request("batch", [
            "blockchain_list_address_transactions"
            batch_args
        ]).then (batch_result)=>
            batch_result = batch_result.result
            balance_ids = {}
            for i in [0...batch_result.length] by 1
                result = batch_result[i]
                address = batch_args[i][0]
                transactions = for trx_id in Object.keys result
                    value = result[trx_id]
                    block_timestamp = value.timestamp
                    transaction = value.trx
                    #last_block = 0
                    block_num = transaction.chain_location.block_num
                    #last_block = Math.max last_block, block_num
                    {
                        trx_id: trx_id
                        block_num: block_num
                        timestamp: block_timestamp
                        is_confirmed: block_num >= 0
                        is_virtual: false
                        #is_market: false
                        trx: transaction.trx
                    }
                
                if transactions.length > 0
                    @storage.setItem "transactions-"+address, JSON.stringify transactions,null,0
                    #address_last_block_map[address] = last_block
                    
                    # balance ids will tell us who the sender was
                    for transaction in transactions
                        for op in transaction.trx.operations
                            continue unless op.type is "withdraw_op_type"
                            balance_id = op.data.balance_id
                            balance_ids[balance_id]=on
            
            @_index_balanceid_readonly(Object.keys balance_ids)
            
            #@storage.setItem(
            #    "address_last_block_map"
            #    JSON.stringify address_last_block_map,null,0
            #)
    
    _storage_balanceid_readonly:(balance_id_map)->
        if balance_id_map
            @storage.setItem(
                "balanceid_readonly_map"
                JSON.stringify balance_id_map,null,0
            )
            return
        else
            str = @storage.getItem "balanceid_readonly_map"
            if str then JSON.parse str else {}
    
    _index_balanceid_readonly:(balance_ids)->
        balance_id_map = @_storage_balanceid_readonly()
        batch_args = for balances_id in balance_ids
            #already saved, these values below are all read-only

            continue if balance_id_map[balances_id]
            [  balances_id ]
        
        if batch_args.length is 0
            defer = q.defer()
            defer.resolve()
            return defer.promise
        
        @rpc.request("batch", ["blockchain_get_balance", batch_args]).then (batch_result)=>
            for i in [0...batch_result.result.length] by 1
                balance = batch_result.result[i]
                continue unless balance.condition.type is "withdraw_signature_type"
                balance_id = batch_args[i][0]
                balance_id_map[balance_id]=
                    # only read-only
                    owner: balance.condition.data.owner
                    asset_id: balance.condition.asset_id
            @_storage_balanceid_readonly balance_id_map
            return
    
    _add_ledger_entries:(transaction, account_address, aes_root, balanceid_readonly)->
        sender = null
        recipient = null
        balance_id = null
        transaction.ledger_entries = entries = []
        account_promises = []
        has_from = no
        for op in transaction.trx.operations
            if (
                op.type is "deposit_op_type" and 
                op.data.condition.type is "withdraw_signature_type"
            )
                amount = op.data.amount
                asset_id = op.data.condition.asset_id
                recipient = op.data.condition.data.owner
                entries.push entry = {}
                
                if op.data.condition.data.memo
                    try 
                        memo_data = @_decrypt_memo(
                            op.data.condition.data.memo
                            account_address, aes_root
                        )
                        if memo_data
                            has_from = yes
                            memo_from = memo_data.from.toBtsPublic()
                            entry.from_account = memo_from
                            defer = q.defer()
                            account_promises.push defer.promise
                            ((entry, defer)=>
                                @wallet_db.get_chain_account(
                                    entry.from_account, @blockchain_api
                                ).then (account) ->
                                    entry.from_account = account.name if account
                                    defer.resolve()
                                    return
                                , ()->
                                    #unknown account
                                    defer.resolve()
                                    return
                            )(entry, defer)
                            entry.memo = memo_data.message.toString()
                            entry.memo_from_account = memo_from
                    catch e
                        console.log 'chain_database._decrypt_memo',e
                
                entry.to_account = recipient
                if recipient
                    defer = q.defer()
                    account_promises.push defer.promise
                    ((entry, defer)=>
                        @wallet_db.get_chain_account(
                            entry.to_account, @blockchain_api
                        ).then (account) ->
                            entry.to_account = account.name if account
                            #console.log '... entry,account', entry,account
                            defer.resolve()
                            return
                        , (ex)->
                            #unknown account
                            #console.log ex,ex.stack
                            defer.resolve()
                            return
                    )(entry, defer)
                
                entry.amount=
                    amount: amount
                    asset_id: asset_id
        
        unless has_from
            for op in transaction.trx.operations
                if op.type is "withdraw_op_type"
                    balance_id = op.data.balance_id
                    sender = balanceid_readonly[balance_id]?.owner
                    asset_id = balanceid_readonly[balance_id]?.asset_id
                    amount = op.data.amount
                    entries.push entry = {}
                    entry.from_account = sender
                    entry.to_account = ""
                    if sender
                        defer = q.defer()
                        account_promises.push defer.promise
                        ((entry, defer)=>
                            @wallet_db.get_chain_account(
                                entry.from_account, @blockchain_api
                            ).then (account) ->
                                #console.log '... entry.from_account',entry.from_account
                                #console.log '... account',account
                                entry.from_account = account.name if account
                                defer.resolve()
                                return
                            , ()->
                                #unknown account
                                defer.resolve()
                                return
                        )(entry, defer)
                    
                    unless sender
                        console.log "WARN chain_database::_add_ledger_entries did not find balance record #{balance_id}"
                    entry.amount=
                        amount: amount
                        asset_id: asset_id
                    entry.memo = ""
                    entry.memo_from_account = null
        
        q.all account_promises
    
    _decrypt_memo:(titan_memo, account_address, aes_root)->
        otk_public = PublicKey.fromBtsPublic titan_memo.one_time_key
        ciphertext = titan_memo.encrypted_memo_data
        
        account = @wallet_db.get_account_for_address account_address
        active_private = @wallet_db.getActivePrivate aes_root, account.name 
        
        memo_data = (->
            aes = active_private.sharedAes otk_public
            memo_data = aes.decryptHex ciphertext
        )()
        if memo_data
            memo_buffer = new Buffer memo_data, 'hex'
            if memo_buffer.length > 0
                memo_data = MemoData.fromHex memo_data
                #console.log '... memo_data', memo_data
                return memo_data
        return null
        ###
        #secret_private = ExtendedAddress.private_key_child active_private, otk_public
        #owner = secret_private.toPublicKey().toBlockchainAddress()
        #console.log '... owner2', secret_private.toPublicKey().toBtsPublic()
        #console.log '... memo_from_account: account.name', account.name
        ###
    
    _add_fee_entries:(transaction, balanceid_readonly)->
        transaction.fee = (->
            balances = {}
            for op in transaction.trx.operations
                if op.type is "withdraw_op_type"
                    amount = op.data.amount
                    balance_id = op.data.balance_id
                    asset_id = balanceid_readonly[balance_id]?.asset_id
                    if asset_id is undefined
                        throw new Error "chain_database::_add_ledger_entries did not find balance record #{balance_id}"
                        return
                    balance = balances[asset_id] or 0
                    balances[asset_id] = balance + amount
                
                if op.type is "deposit_op_type" and op.data.condition.type is "withdraw_signature_type"
                    amount = op.data.amount
                    asset_id = op.data.condition.asset_id
                    balance = balances[asset_id] or 0
                    balances[asset_id] = balance - amount
            
            fee_balance = for asset_id in Object.keys balances
                balance = balances[asset_id]
                continue if balance is 0
                asset_id: asset_id
                amount: balance
                
            if fee_balance.length isnt 1
                err = "chain_database::_add_ledger_entries can't calc fee, transaction has more than one asset type in its remaning balance"
                console.log err, transaction, balances
                throw new Error err
                return
            
            fee_balance[0]
        )()
        return
    
    ###* @return promise [transaction] ###
    account_transaction_history:(
        account_name
        asset_id=-1
        limit=0
        start_block_num=0
        end_block_num=-1
        aes_root
    )->
        throw new Error "aes_root is required" unless aes_root
        account_name = null if account_name is ""
        if asset_id is "" then asset_id = -1
        unless /^-?\d+$/.test asset_id
            throw "asset_id should be a number, instead got: #{asset_id}"
        
        if end_block_num isnt -1
            unless start_block_num <= end_block_num
                throw new Error "start_block_num #{start_block_num} <= end_block_num #{end_block_num}"
        
        balanceid_readonly = @_storage_balanceid_readonly()
        
        include_asset=(transaction)->
            return yes if asset_id is -1
            for op in transaction.trx.operations
                if (
                    op.type is "deposit_op_type" and 
                    op.data.condition.type is "withdraw_signature_type"
                )
                    if asset_id is op.data.condition.asset_id
                        return yes
                
                if op.type is "withdraw_op_type"
                    balance_id = op.data.balance_id
                    if asset_id is balanceid_readonly[balance_id]?.asset_id
                        return yes
            return no
        
        history = []
        add_ledger_promise = []
        for account_address in @_account_addresses account_name
            transactions_string = @storage.getItem "transactions-"+account_address
            continue unless transactions_string
            transactions = JSON.parse transactions_string
            
            ## tally from day 0 (this does not cache running balances)
            #transactions = @transaction_ledger.format_transaction_history transactions
            
            # now filter
            for transaction in transactions
                continue if transaction.block_num < start_block_num
                if end_block_num isnt -1
                    continue if transaction.block_num > end_block_num
                
                continue unless include_asset transaction
                transaction._tmp_account_address = account_address
                history.push transaction
        
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
        
        history = if limit is 0 or Math.abs(limit) >= history.length
           history 
        else if limit > 0
            history.slice 0, limit
        else
            history.slice history.length - -1 * limit, history.length
        
        add_ledger_promises = []
        for transaction in history
            account_address = transaction._tmp_account_address
            delete transaction._tmp_account_address
            add_ledger_promises.push @_add_ledger_entries(
                transaction, account_address
                aes_root, balanceid_readonly
            )
            @_add_fee_entries transaction, balanceid_readonly
        
        defer = q.defer()
        q.all(add_ledger_promises).then =>
            pretty_history = []
            for tx in history 
                try
                    pretty_history.push @transaction_ledger.to_pretty_tx tx
                catch e
                    console.log e,e.stack
            defer.resolve pretty_history
        , (error)->
            defer.reject error
        defer.promise
    
exports.ChainDatabase = ChainDatabase
