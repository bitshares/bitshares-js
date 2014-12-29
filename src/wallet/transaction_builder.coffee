{Transaction} = require '../blockchain/transaction'
{RegisterAccount} = require '../blockchain/register_account'
{Withdraw} = require '../blockchain/withdraw'

LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause

class TransactionBuilder
    
    constructor:(@wallet_db, @rpc)->
    
    account_register:(
        account_name
        pay_from_account
        public_data=null
        delegate_pay_rate = -1
        account_type = "titan_account"
    )->
        LE.throw "wallet.must_be_opened" unless @wallet_db
        if delegate_pay_rate isnt -1
            EC.throw 'Not implemented'
        
        owner_key = @wallet_db.getOwnerKey account_name
        unless owner_key
            EC.throw "Create account before registering"
        
        active_key = @wallet_db.getActiveKey pay_from_account
        unless active_key
            EC.throw "Unknown pay_from account #{pay_from_account}"
        
        meta_data = null
        if account_type
            type_id = RegisterAccount.type[account_type]
            if type_id is undefined
                EC.throw "Unknown account type: #{account_type}"
            meta_data=
                type: type_id
                data: null
        if delegate_pay_rate > 100
            LE.throw 'wallet.delegate_pay_rate_invalid', [delegate_pay_rate]
        
        operations = []
        register = new RegisterAccount(
            account_name
            public_data
            owner_key
            active_key
            delegate_pay_rate
            meta_data
        )
        
        required_signatures = []
        pos = account_name.indexOf '.'
        unless pos is -1
            parent = account_name.substring pos+1
            account = @wallet_db.lookup_active_key parent
            if account
                LE.throw 'wallet.need_parent_for_registration', [parent]
            required_signatures.push account
        
        fees = @wallet_db.get_transaction_fee()
        #if delegate_pay_rate isnt -1
            #calc and add delegate fee
        withdraws = @withdraws_to_transaction(
            fees
            pay_from_account
            required_signatures
        )
        
        entry = {}
        entry.from_account = ""
            
        operations.push new Operation register.type_id, register
        for withdraw in withdraws
            operations.push new Operation withdraw.type_id, withdraw
        
        transaction = new Transaction(
            expiration = @wallet_db.get_trx_expiration().getTime()
            delegate_slate_id = null
            operations
        )
        trx_sign = ->
            trx_buffer = transaction.toBuffer()
            chain_id_buffer = new Buffer(config.chain_id, 'hex')
            Buffer.concat([trx_buffer, chain_id_buffer])
        trx_sign = trx_sign()
        console.log 'digest',hash.sha256(trx_sign).toString('hex')
        console.log 'sign key sender_private',sender_private.toHex()
        new SignedTransaction(
            transaction
            [ 
                Signature.signBuffer trx_sign, owner_private
            ]
        )
        ###
        # TODO, lookup with RPC calls so user can spend initial genesis claim
        balance_id = Address.fromString("XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP")

        enc_memo = new Buffer(enc_memo_hex, 'hex')
        ###
        
    withdraws_to_transaction:(
        amount_to_withdraw
        from_account_name
        signed_trx
        required_signatures
    )->
        withdraws = []
        amount_remaining = amount_to_withdraw
        balances = get_account_balance_records from_account_name
        for record in balances
            balance = record.get_spandable_balance blockchain.getPending_state.now()
            continue if balance.amount <= 0
            continue if balance.asset_id isnt amount_remaining.asset_id
            if amount_remaining.amount > balance.amount
                withdraws.push new Withdraw record.id(), balance.amount
                required_signatures.push record.owner()
                amount_remaining -= balance
            else
                withdraws.push new Withdraw record.id(), amount_remaining.amount
                required_signatures.insert record.owner()
                break
        withdraws
        

exports.TransactionBuilder = TransactionBuilder