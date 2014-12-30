#{PublicKey} = require '../ecc/key_public'
#{Address} = require '../ecc/address'

{Transaction} = require '../blockchain/transaction'
{WithdrawCondition} = require '../blockchain/withdraw_condition'

class TransactionLedger
    
    constructor:(@wallet_db)->
    
    ###* @return {array} WithdrawCondition ###
    getWithdrawConditions:(account_name)->
        wcs = []
        account = @wallet_db.lookup_account account_name
        to = @wallet_db.transaction_to[account.owner_key]
        return balance_ids unless to
        for record in to
            continue unless tx = record.trx
            #console.log 'tx',JSON.stringify tx,null,4
            for op in tx.operations
                #console.log 'op',JSON.stringify op,null,4
                continue unless op.type is 'deposit_op_type'
                condition = op.data.condition
                unless condition.type is 'withdraw_signature_type'
                    console.log "WARN: unsupported balance record #{balance.condition.type}"
                    continue
                wcs.push WithdrawCondition.fromJson op.data.condition
        wcs
        
    get_transaction_history:(
        account_name = null
        start_block_num = 0
        end_block_num = 0
        asset_id = null
    )->
        if end_block_num isnt -1
            unless start_block_num <= end_block_num
                throw new Error "start_block_num #{start_block_num} <= end_block_num #{end_block_num}"
        
        balances={}
        
        tally=(account, asset_id, amount)=>
            balances[account] = {} unless balances[account]
            if balances[account][asset_id]
                balances[account][asset_id] += amount
            else
                balances[account][asset_id] = amount
            #console.log account, asset_id, amount,balances[account]
            return
            
        balance_struct=(account)->
            #console.log account, balances[account]
            for asset_id in Object.keys balances[account]
                [
                    asset_id
                    {
                        asset_id: asset_id
                        amount: balances[account][asset_id]
                    }
                ]
                
        include_asset=(entry)->
            return true unless asset_id
            amount = entry.amount
            amount.asset_id is asset_id and 
            amount.amount > 0
        
        history = []
        transactions = @wallet_db.get_transactions()
        
        for tx in transactions
            has_asset = no
            # tally all blocks even if they are not in the query
            for entry in tx.ledger_entries
                continue unless include_asset entry
                has_asset = yes
                from_account = entry.from_account_name
                to_account = entry.to_account_name
                amt = entry.amount
                if from_account
                    tally from_account, amt.asset_id, - amt.amount
                    #//Subtract fee once on the first entry
                    #if( !trx.is_virtual && !any_from_me )
                    tally from_account, tx.fee.asset_id, - tx.fee.amount
                    
                if to_account
                    tally to_account, amt.asset_id, amt.amount
                    
                ###
                TODO
                fee_asset_id = tx.fee.asset_id
                // Special case to subtract fee if we canceled a bid
                if( !trx.is_virtual && trx.is_market_cancel && amount_asset_id != fee_asset_id )
                    running_balances[ fee_asset_id ] -= trx.fee;
                ###
            
            continue unless has_asset
            continue if tx.block_num < start_block_num
            if end_block_num isnt -1
                continue if tx.block_num > end_block_num
            
            for entry in tx.ledger_entries
                continue unless include_asset entry
                from_account = entry.from_account_name
                to_account = entry.to_account_name
                continue unless to_account or from_account
                running_balances = entry.running_balances = []
                if from_account
                    running_balances.push [from_account, balance_struct from_account]
                if to_account
                    running_balances.push [to_account, balance_struct to_account ]
            
            history.push @to_pretty_tx tx
        history
        
    #get_pending_transaction_errors:->
    
    to_pretty_tx:(tx)->
        pretty_tx = {}
        pretty_tx.is_virtual = tx.is_virtual
        pretty_tx.is_confirmed = tx.is_confirmed
        pretty_tx.is_market = tx.is_market
        #pretty_tx.is_market_cancel = not tx.is_virtual and tx.is_market and Transaction.is_cancel(tx.operations)
        #(Transaction.fromJson tx).id()
        pretty_tx.trx_id = tx.record_id #tx.is_virtual ? tx.record_id : tx.id()
        pretty_tx.block_num = tx.block_num
            
        pretty_tx.ledger_entries = []
        for entry in tx.ledger_entries
            pretty_tx.ledger_entries.push pe = {}
            unless pe.from_account = entry.from_account_name
                pe.from_account = entry.from_account
            unless pe.to_account = entry.to_account_name
                pe.to_account = entry.to_account
                
            if pe.from_account
                if entry.memo_from_account_name
                    pe.from_account += " as " + entry.memo_from_account_name
            else
                pe.from_account =
                    if tx.is_virtual and tx.block_num <= 0 then "GENESIS"
                    else if tx.is_market then "MARKET"
                    else if tx.is_virtual and tx.block_num is 933804 then "SHAREDROP"
                    else "UNKNOWN"
            unless pe.to_account
                pe.to_account =
                    if tx.is_market then "MARKET"
                    else "UNKNOWN"
            if pe.from_account is pe.to_account
                if entry.memo.indexOf("withdraw pay") is 0
                    pe.from_account = "NETWORK"
            if entry.memo.indexOf("yield") is 0
                pe.from_account = "NETWORK"
                console.log "WARN: to_account for yield (#{pe.to_account}) may need resolving"
            else if entry.memo.indexOf("burn") is 0 then pe.to_account = "NETWORK"
            #console.log 'pe',pe
            (->
                from = pe.from_account or ""
                to = pe.to_account or ""
                if from.indexOf("SHORT") is 0 and to.indexOf("SHORT") is 0
                    pe.to_account = to.replace /^.{5}/, "MARGIN"
                else if from.indexOf("MARKET") is 0 and to.indexOf("SHORT") is 0
                    pe.to_account = to.replace /^.{5}/, "MARGIN"
                else if from.indexOf("SHORT") is 0 and to.indexOf("MARKET") is 0
                    pe.from_account = from.replace /^.{5}/, "MARGIN"
                else if from.indexOf("SHORT") is 0 and to.indexOf("payoff") is 0
                    pe.to_account = to.replace /^.{5}/, "MARGIN"
                else if from.indexOf("SHORT") is 0 and to.indexOf("cover") is 0
                    pe.from_account = from.replace /^.{5}/, "MARGIN"
            )()
            pe.amount = entry.amount
            pe.memo = entry.memo
            pe.running_balances = entry.running_balances
        
        pretty_tx.fee = tx.fee
        pretty_tx.timestamp =
            if tx.created_time < tx.received_time
                tx.created_time 
            else 
                tx.received_time
        pretty_tx.expiration_timestamp = tx.trx.expiration
        #console.log JSON.stringify pretty_tx, null, 4
        pretty_tx

exports.TransactionLedger = TransactionLedger