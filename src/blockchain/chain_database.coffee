localStorage = require '../common/local_storage'

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
    
    _sync_transactions:(account_name)->
        keys = @_account_keys account_name
        
        addresses = []
        for key in keys
            addresses.push key.account_address
        
        return if addresses.length is 0
        batch_args = for address in addresses
            [
                "blockchain_list_address_transactions"
                address
                block=0
            ]
        
        @rpc.request("batch", batch_args).then (batch_result)=>
            for i in [0...batch_result.result.length] by 1
                result = batch_result.result[i]
                address = batch_args[i][1]
                transactions = for record in result
                    result[1][1].trx
                localStorage.setItem address, JSON.stringify transactions,null,0
                #block_num = result[1][1].chain_location.block_num
    
    get_transactions:(
        account_name
        start_block_num = 0
        end_block_num = 0
        asset_id = null
        transactions
    )->
        if end_block_num isnt -1
            unless start_block_num <= end_block_num
                throw new Error "start_block_num #{start_block_num} <= end_block_num #{end_block_num}"
        
        keys = @_account_keys account_name
        include_asset=(entry)->
            return true unless asset_id
            amount = entry.amount
            amount.asset_id is asset_id and 
            amount.amount > 0
        
        for key in keys
            transactions_string = localStorage.getItem key.account_address
            continue unless transactions
            transactions = JSON.parse transactions_string
            for tx in transactions
                continue if tx.block_num < start_block_num
                if end_block_num isnt -1
                    continue if tx.block_num > end_block_num
                
            [key, transactions]
            
        
        
    account_transaction_history:( # account_transaction_history
        account_name
        asset_id=0
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        defer = q.defer()
        account_name = null if account_name is ""
        if asset_id is "" then asset_id = 0
        unless /^\d+$/.test asset_id
            throw "asset_id should be a number, instead got: #{asset_id}"
        
        @_sync_transactions(account_name).then ()=>
            transactions = @get_transactions(
                account_name
                start_block_num
                end_block_num
                asset_id
            )
            history = @transaction_ledger.format_transaction_history transactions
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
            defer.resolve history
        defer.promise

module.exports = ChainDatabase