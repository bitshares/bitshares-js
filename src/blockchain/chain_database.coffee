{Storage} = require '../common/storage'
{PublicKey} = require '../ecc/key_public'
{ExtendedAddress} = require '../ecc/extended_address'
{TransactionLedger} = require '../wallet/transaction_ledger'
{ChainInterface} = require '../blockchain/chain_interface'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{MemoData} = require '../blockchain/memo_data'
q = require 'q'
Long = (require 'bytebuffer').Long

class ChainDatabase

    sync_accounts_lookahead = 11
    sync_accounts_timeout_id = null
    sync_transactions_timeout_id = null
    
    constructor: (@wallet_db, @rpc, chain_id, relay_fee_collector) ->
        @transaction_ledger = new TransactionLedger()
        @chain_id = chain_id.substring 0, 10
        @storage = new Storage @wallet_db.wallet_name + "_" + @chain_id
        # basic unit tests will not provide an rpc object
        if @rpc and not @rpc.request
            throw new Error 'expecting rpc object'
        @blockchain_api = new BlockchainAPI @rpc
        if relay_fee_collector
            # make this account available for ledger and fee entries
            active_key = ChainInterface.get_active_key relay_fee_collector.active_key_history
            @relay_fee_address = PublicKey.fromBtsPublic(active_key).toBtsAddy()
    
    delete: ->
        len = @storage.length()
        for i in [0...len] by 1
            @storage.removeItemOrThrow @storage.key i
        return
    
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
                    @sync_accounts(
                        aes_root, sync_accounts_lookahead
                        algorithm = 'standard'
                    ).then (found)->
                        unless found
                            sync_accounts_lookahead = 1
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
                    @sync_transactions().then (new_trx_id_map)=>
                        @check_pending_transactions new_trx_id_map
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
    
    sync_accounts:(aes_root, lookahead, algorithm)->
        next_accounts = @wallet_db.guess_next_account_keys(
            aes_root
            lookahead
            algorithm
        )
        batch_params = []
        batch_params.push [next_account.public] for next_account in next_accounts
        ((algorithm, next_accounts)=>
            @rpc.request("batch", [
                "blockchain_get_account"
                batch_params
            ]).then (batch_result)=>
                batch_result = batch_result.result
                found = no
                for i in [0...batch_result.length] by 1
                    account = batch_result[i]
                    console.log '... chaindb sync accounts',next_accounts[i],(
                        if account then 'found' else 'not found'
                    )
                    continue unless account
                    next_account = next_accounts[i]
                    # update the account index, create private key entries etc...
                    try
                        @wallet_db.generate_new_account(
                            aes_root, @blockchain_api
                            account.name
                            account.private_data
                            next_account
                            algorithm
                        )
                        found = yes
                    catch e
                        console.log "ERROR",e.stack
                found
        )(algorithm, next_accounts)
    
    sync_transactions:(account_name)->
        addresses = @_account_addresses account_name
        if addresses.length is 0
            return
        
        get_last_unforked_block_num= =>
            blocknum_hash_storage=(blocknum_hash)=>
                if blocknum_hash
                    @storage.setItem(
                        "blocknum_hash"
                        JSON.stringify blocknum_hash,null,0
                    )
                    return
                else
                    str = @storage.getItem "blocknum_hash"
                    if str then JSON.parse str else [1, undefined]
            
            blocknum_hash = blocknum_hash_storage()
            defer = q.defer()
            ((blocknum_hash)=>
                @blockchain_api.get_block_hash(blocknum_hash[0]).then (hash)=>
                    try
                        if blocknum_hash[1] and hash.id isnt blocknum_hash[1].id
                            console.log "INFO, fork detected",blocknum_hash[1],hash.id
                            defer.resolve 1
                            return
                    catch
                        console.log "ERROR testing hash id"
                    
                    # no fork, so jump to the head
                    @rpc.request('get_info').then (info)=>
                        info = info.result
                        block_num = info.blockchain_head_block_num
                        ((block_num)=>
                            @blockchain_api.get_block_hash(block_num).then (hash)=>
                                blocknum_hash_storage [block_num, hash]
                                defer.resolve block_num
                                return
                        )(block_num)
            )(blocknum_hash)
            defer.promise
        
        get_last_unforked_block_num().then (block_num) =>
            p = @_sync_transactions(addresses, block_num)
            p.done() if p
    
    _sync_transactions:(addresses, last_unforked_block_num)->
        address_last_block_map_storage=(address_last_block_map)=>
            if address_last_block_map
                @storage.setItem(
                    "address_last_block_map"
                    JSON.stringify address_last_block_map,null,0
                )
                return
            else
                str = @storage.getItem "address_last_block_map"
                if str then JSON.parse str else {}
        
        address_last_block_map = address_last_block_map_storage()
        batch_args = for address in addresses
            last_block = address_last_block_map[address]
            next_block = if last_block then last_block + 1 else 1
            if(
                last_unforked_block_num < next_block and
                last_unforked_block_num isnt 1
            )
                throw new Error "Only full refresh on fork is supported"
            
            next_block = Math.min last_unforked_block_num, next_block
            # "next_block - 1" is to adjust for the "filter_before" parameter
            [address, next_block - 1]
        
        @rpc.request("batch", [
            "blockchain_list_address_transactions"
            batch_args
        ]).then (batch_result)=>
            batch_result = batch_result.result
            trx_ids = {}
            balance_ids = {}
            balance_ids_dirty = no
            for i in [0...batch_result.length] by 1
                result = batch_result[i]
                address = batch_args[i][0]
                next_block = batch_args[i][1] + 1
                transactions = for trx_id in Object.keys result
                    trx_ids[trx_id] = on
                    value = result[trx_id]
                    block_timestamp = value.timestamp
                    transaction = value.trx
                    block_num = transaction.chain_location.block_num
                    trx_id: trx_id
                    block_num: block_num
                    timestamp: block_timestamp
                    is_confirmed: block_num > 0
                    is_virtual: false
                    trx: transaction.trx
                
                address_last_block_map[address] = last_unforked_block_num
                if transactions.length > 0
                    if next_block isnt 1
                        existing_transactions = JSON.parse @storage.getItem(
                            "transactions-"+address
                        )
                        if existing_transactions
                            existing_transactions.push tx for tx in transactions
                            transactions = existing_transactions
                    
                    @storage.setItem(
                        "transactions-"+address
                        JSON.stringify transactions,null,0
                    )
                    
                    # balance ids will tell us who the sender was
                    for transaction in transactions
                        for op in transaction.trx.operations
                            continue unless op.type is "withdraw_op_type"
                            balance_id = op.data.balance_id
                            balance_ids[balance_id]=on
                            balance_ids_dirty = yes
            
            @_index_balanceid_readonly Object.keys balance_ids if balance_ids_dirty
            address_last_block_map_storage address_last_block_map
            return trx_ids
    
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
    
    summarize_op_type:(type)->
        if /_op_type$/.test type
            summary = type.substring 0, type.length - "_op_type".length
            summary.toUpperCase()
        else
            ""
    
    _add_ledger_entries:(
        transaction, account_address
        aes_root, balanceid_readonly
    )->
        sender = null
        recipient = null
        balance_id = null
        transaction.ledger_entries = entries = []
        account_promises = []
        has_from = no
        
        total_by_asset=(map, asset_id, amount)->
            total = map[asset_id] or Long.ZERO
            map[asset_id] = total.add amount
            
        deposits = {}
        for op in transaction.trx.operations
            memo = undefined
            amount = undefined
            if (
                op.type is "deposit_op_type" and 
                op.data.condition.type is "withdraw_signature_type" and
                # fees are implied so simply exclude relay_fee_address
                op.data.condition.data.owner isnt @relay_fee_address
            )
                amount = Long.fromString ""+op.data.amount
                asset_id = op.data.condition.asset_id
                recipient = op.data.condition.data.owner
                memo = op.data.condition.data.memo
            
            else if op.type is "ask_op_type"
                amount = Long.fromString ""+op.data.amount
                asset_id = op.data.ask_index.order_price.base_asset_id
                recipient = op.data.ask_index.owner
            
            continue unless amount
            total_by_asset deposits, asset_id, amount
            entries.push entry = {}
            
            if memo
                try 
                    memo_data = @_decrypt_memo(
                        memo
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
                    #console.log 'chain_database._decrypt_memo',e
            else
                entry.memo = @summarize_op_type op.type
            
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
                amount: amount.toString()
                asset_id: asset_id
        
        withdraws = {}
        for op in transaction.trx.operations
            amount = sender = undefined
            if op.type is "withdraw_op_type"
                balance_id = op.data.balance_id
                sender = balanceid_readonly[balance_id]?.owner
                asset_id = balanceid_readonly[balance_id]?.asset_id
                amount = Long.fromString ""+op.data.amount
            else if op.type is "bid_op_type"
                # negate back to positive
                amount = (Long.fromString ""+op.data.amount).negate()
                asset_id = op.data.bid_index.order_price.quote_asset_id
                sender = op.data.bid_index.owner
            else if op.type is "cover_op_type"
                amount = (Long.fromString ""+op.data.amount).negate()
                asset_id = op.data.cover_index.order_price.quote_asset_id
                sender = op.data.cover_index.owner
            
            continue unless amount
            total_by_asset withdraws, asset_id, amount
            entries.push entry = {}
            entry.from_account = sender
            entry.to_account = ""
            if entry.from_account
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
                amount: amount.toString()
                asset_id: asset_id
            entry.memo = @summarize_op_type op.type
            entry.memo_from_account = null
        
        subtract_by_asset=(asset1, asset2)->
            map={}
            for asset_id in Object.keys asset1
                total_by_asset map, asset_id, asset1[asset_id]
            for asset_id in Object.keys asset2
                total_by_asset map, asset_id, asset2[asset_id].negate()
            for asset_id in Object.keys map
                total = map[asset_id]
                delete map[asset_id] if total.compare(Long.ZERO) is 0
            map
        
        fees = subtract_by_asset withdraws, deposits
        if (keys = Object.keys fees).length is 1
            asset_id=keys[0]
            transaction.fee=
                amount:fees[asset_id].toString()
                asset_id:asset_id
        else
            console.error "ERROR: transaction contains #{(Object.keys fees).length} asset fee balances",fees,transaction
        
        q.all account_promises
    
    _decrypt_memo:(titan_memo, account_address, aes_root)->
        account = @wallet_db.get_account_for_address account_address
        return null unless account
        active_private = @wallet_db.getActivePrivate aes_root, account.name 
        return null unless active_private
        
        otk_public = PublicKey.fromBtsPublic titan_memo.one_time_key
        ciphertext = titan_memo.encrypted_memo_data
        
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
    
    pending_transactions=undefined
    get_pending_transactions:->
        if pending_transactions
            defer = q.defer()
            defer.resolve pending_transactions
            return defer.promise
        
        @storage.get("transactions-pending").then (pending_transaction_string)=>
            unless pending_transaction_string
                return {
                    trx_map:{}
                    trx_address_map:{}
                }
            pending_transactions = JSON.parse pending_transaction_string
            now_time = Date.now().getTime()
            for trx_id in Object.keys pending_transactions.trx_map
                transaction = pending_transactions.trx_map[trx_id]
                # block_num 0 or undefined is pending
                continue if transaction.block_num
                expiration = new Date transaction.expiration
                if now_time >= expiration.getTime()
                    @delete_pending_transaction trx_id
                    continue
                return
            pending_transactions
    
    delete_pending_transaction:(trx_id)->
        transaction = pending_transactions.trx_map[trx_id]
        delete pending_transactions.trx_map[trx_id]
        for address in @addresses_for_transaction transaction
            ids = pending_transactions.trx_address_map[address]
            delete ids[trx_id]
        return
    
    check_pending_transactions:(non_pending_trx_id_map={})->
        @get_pending_transactions().then (pending_transactions)=>
            trx_ids = Object.keys pending_transactions
            return unless trx_ids.length
            for trx_id in trx_ids
                if non_pending_trx_id_map[trx_id]
                    @delete_pending_transaction trx_id
                    continue
                batch_args.push [trx_id]
            return unless batch_args.length
            @rpc.request(
                "batch",["blockchain_get_transaction", batch_args]
            ).then (batch_result)->
                for i in [0...batch_result.result.length] by 1
                    result = batch_result.result[i]
                    continue unless result
                    trx_id = result[0]
                    trx = result[1]
                    pending_transactions.trx_map[trx_id].chain_location =
                        block_num: trx.chain_location.block_num
                    return
                return
    
    ###* 
      Saves a new pending transaction.  Also has the effect of cleaning out
      transactions that are no longer pending (has a non-zero block_num or expired)
    ###
    save_pending_transaction:(record)->
        ((record)=>
            @get_pending_transactions().then (pending_transactions)=>
                transaction = record.trx
                transaction_id = record.record_id
                pending_transactions.trx_map[transaction_id]=transaction
                addresses = @addresses_for_transaction transaction
                for address in addresses
                    ids = pending_transactions.trx_address_map[address]
                    unless ids
                        pending_transactions.trx_address_map[address] = ids = {}
                    ids[transaction_id]=on
                
                for trx_id in Object.keys pending_transactions.trx_map
                    # block_num 0 or undefined is pending
                    continue unless pending_transactions.trx_map[trx_id].block_num
                    @delete_pending_transaction trx_id
                
                pending_transaction_string = JSON.stringify pending_transactions,null,0
                @storage.set "transactions-pending",pending_transaction_string
        )(record)
    
    addresses_for_transaction:(transaction)->
        recipient=[]
        sender=[]
        push=(array, value)-> array.push value if value
        balance_id_map = @_storage_balanceid_readonly()
        for op in @transaction.operations
            if (
                op.type is "deposit_op_type" and 
                op.data.condition.type is "withdraw_signature_type"
            )
                push recipient, op.data.condition.data.owner
            
            if op.type is "withdraw_op_type"
                balance_id = op.data.balance_id
                owner = balance_id_map[balance_id]?.owner
                console.log 'WARN, missing balance_id' unless owner
                push sender, owner
            
            push recipient, op.data.ask_index?.owner
            push sender, op.data.bid_index?.owner
            push sender, op.data.cover_index?.owner
        
        recipients:recipient
        senders:sender
    
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
                
                if op.type is "ask_op_type"
                    return asset_id is op.data.ask_index.order_price.base_asset_id
                
                if op.type is "bid_op_type"
                    return asset_id is op.data.bid_index.order_price.quote_asset_id
                
                if op.type is "cover_op_type"
                    return asset_id is op.data.cover_index.order_price.quote_asset_id
            
            return no
        
        history = []
        add_ledger_promise = []
        for account_address in @_account_addresses account_name
            pending_transactions = if start_block_num is 0 and pending_transactions
                ids = pending_transactions.trx_address_map[account_address]
                for trx_id in Object.keys ids
                    pending_transactions.trx_map[trx_id]
            
            transactions_string = @storage.getItem "transactions-"+account_address
            transactions = if transactions_string
                JSON.parse transactions_string
            
            ## tally from day 0 (this does not cache running balances)
            #transactions = @transaction_ledger.format_transaction_history transactions
            
            check=(transaction)->
                return if transaction.block_num < start_block_num
                if end_block_num isnt -1
                    return if transaction.block_num > end_block_num
                
                return unless include_asset transaction
                transaction._tmp_account_address = account_address
                history.push transaction
            # filter
            check tx for tx in transactions if transactions
            if pending_transactions
                for trx_id in Object.keys pending_transactions.trx_map
                    check pending_transactions.trx_map[trx_id]
                return
        
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
        
        ((history)=>
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
        )(history)
    
exports.ChainDatabase = ChainDatabase
