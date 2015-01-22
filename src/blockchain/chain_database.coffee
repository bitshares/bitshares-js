localStorage = require '../common/local_storage'
bts_address_prefix = (require '../config').bts_address_prefix

class ChainDatabase

    constructor: (@wallet_db, @rpc) ->
    
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
    
    sync_assets:()->
        
    sync_transactions:(account_name)->
        addresses = ((keys)->
            addresses = {}
            for key in keys
                addresses[key.account_address]=yes
            Object.keys addresses
        )(@_account_keys account_name)
        return if addresses.length is 0
        
        ## last block tracking involves merging with old transactions (not implemented)
        #address_last_block_map = (->
        #    str = localStorage.getItem "#{bts_address_prefix}_address_last_block_map"
        #    if str
        #        JSON.parse str
        #    else
        #        {}
        #)()
        
        batch_args = for address in addresses
            [
                "blockchain_list_address_transactions"
                address
                block=0 #address_last_block_map[address] or 0
            ]
        defer = q.defer()
        @rpc.request("batch", batch_args).then (batch_result)=>
            balance_ids = {}
            for i in [0...batch_result.result.length] by 1
                result = batch_result.result[i]
                address = batch_args[i][1]
                transactions = for record in result
                    trx_id = record[0]
                    block_timestamp = record[1][0]
                    trx = record[1][1]
                    #last_block = 0
                    block_num = trx.chain_location.block_num
                    #last_block = Math.max last_block, block_num
                    {
                        trx_id: trx_id
                        block_num: block_num
                        block_timestamp: block_timestamp
                        is_confirmed: block_num >= 0
                        is_virtual: false
                        #is_market: false
                        trx: trx
                    }
                if transactions.length > 0
                    localStorage.setItem "transactions-"+address, JSON.stringify transactions,null,0
                    #address_last_block_map[address] = last_block
                    
                    # balance ids lead us to the sender
                    for tx in transactions
                        for op in tx.trx.operations
                            continue unless op.type is "withdraw_op_type"
                            balance_id = op.data.balance_id
                            balances_ids[balance_id]=on
            
            @_index_balanceids(Object.keys balances_ids).then ->
                defer.resolve()
            .done()
            
            #localStorage.setItem(
            #    "#{bts_address_prefix}_address_last_block_map"
            #    JSON.stringify address_last_block_map,null,0
            #)
        .done()
        defer.promise
    
    _storage_balanceids:(balance_id_map)->
        if balance_id_map
            localStorage.setItem(
                "#{bts_address_prefix}_balanceid_readonly_map"
                JSON.stringify transactions,null,0
            )
            return
        else
            str = localStorage.getItem "#{bts_address_prefix}_balanceid_readonly_map"
            if str then JSON.parse str else {}
    
    _index_balanceids:(balances_ids)->
        balance_id_map = @_storage_balanceids()
        batch_args = for balances_id in balances_ids
            #already saved, these values below are all read-only
            continue if balance_id_map[balances_id]
            [
                "blockchain_get_balance"
                balances_id
            ]
        @rpc.request("batch", batch_args).then (batch_result)=>
            for i in [0...batch_result.result.length] by 1
                balance = batch_result.result[i]
                continue unless balance.condition.type is "withdraw_signature_type"
                balance_id = batch_args[i][1]
                balance_id_map[balance_id]=
                    # only read-only
                    owner: balance.condition.data.owner
                    asset_id: balance.condition.asset_id
            
            @_storage_balanceids balance_id_map
            return
    
    _add_ledger_entries:(transactions)->
        sender = null
        recipient = null
        balance_id = null
        balanceid_readonly = @_storage_balanceids()
        for tx in transactions
            tx.ledger_entries = entries = []
            for op in transaction.trx.operations
                if (
                    op.type is "deposit_op_type" and 
                    op.data.condition.type is "withdraw_signature_type"
                )
                    to = op.data.condition.data.owner
                    amount = op.data.amount
                    asset_id = op.data.condition.asset_id
                    balance = balances[asset_id] or 0
                    balances[asset_id] = balance + amount
                
                if op.type is "withdraw_op_type"
                    balance_id = op.data.balance_id
                    sender = balanceid_readonly[balance_id]?.owner
                    unless sender
                        console.log "ERROR chain_database::_add_ledger_entries did not find balance record #{balance_id}"
                        return
            
            sender = balanceid_readonly[balance_id]?.owner
            unless recipient and sender
                console.log "ERROR chain_database::_add_ledger_entries is unable to determine sender '#{sender}' and recipient '#{recipient}' in transaction:",transaction
                return
            
            sender = (@wallet_db.get_account_for_address sender)?.name or sender
            recipient = (@wallet_db.get_account_for_address recipient)?.name or recipient
            for asset_id in Object.keys balances
                entries.push
                    from_account: sender
                    to_account: recipient
                    amount:
                        amount: balances[asset_id]
                        asset_id: asset_id
                    #memo: "To: XTSCZMSz..."
                    #memo_from_account: null
    
    _add_fee_entries:(transactions)->
        for tx in transactions
            tx.fee = (->
                balances = {}
                for op in transaction.trx.operations
                    if op.type is "deposit_op_type" and op.data.condition.type is "withdraw_signature_type"
                        amount = op.data.amount
                        asset_id = op.data.condition.asset_id
                        balance = balances[asset_id] or 0
                        balances[asset_id] = balance - amount
                        
                    if op.type is "withdraw_op_type"
                        balance_id = op.data.balance_id
                        asset_id = balanceid_readonly[balance_id]?.asset_id
                        unless asset_id
                            console.log "ERROR chain_database::_add_ledger_entries did not find balance record #{balance_id}"
                            return
                        balance = balances[asset_id] or 0
                        balances[asset_id] = balance + amount
                balances = Object.keys balances
                if balances.length isnt 1
                    console.log "ERROR chain_database::_add_ledger_entries can't cal fee, transaction has more than one asset type in its remaning balance",transaction.trx
                    return
                balances[0]
            )()
            
    
    account_transaction_history:(
        account_name
        asset_id=0
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        account_name = null if account_name is ""
        if asset_id is "" then asset_id = 0
        unless /^\d+$/.test asset_id
            throw "asset_id should be a number, instead got: #{asset_id}"
        
        if end_block_num isnt -1
            unless start_block_num <= end_block_num
                throw new Error "start_block_num #{start_block_num} <= end_block_num #{end_block_num}"
        
        include_asset=(entry)->
            return true unless asset_id
            amount = entry.amount
            amount.asset_id is asset_id #and amount.amount > 0
        
        history = []
        for key in @_account_keys account_name
            transactions_string = localStorage.getItem "transactions-"+key.account_address
            continue unless transactions_string
            transactions = JSON.parse transactions_string
            
            @_add_ledger_entries transactions
            #?? @_decrypt_memos transactions
            @_add_fee_entries transactions
            
            # tally from day 0 (this does not cache running balances)
            @transaction_ledger.format_transaction_history transactions
            # now we can filter
            for tx in transactions
                continue if tx.block_num < start_block_num
                if end_block_num isnt -1
                    continue if tx.block_num > end_block_num
                
                has_asset = no
                for entry in tx.ledger_entries
                    continue unless include_asset entry
                    has_asset = yes
                history.push tx if has_asset
        
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
        history

exports.ChainDatabase = ChainDatabase
