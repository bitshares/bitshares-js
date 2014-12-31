{Transaction} = require '../blockchain/transaction'
{RegisterAccount} = require '../blockchain/register_account'
{Withdraw} = require '../blockchain/withdraw'
{Deposit} = require '../blockchain/deposit'
{WithdrawCondition} = require '../blockchain/withdraw_condition'
{WithdrawSignatureType} = require '../blockchain/withdraw_signature_type'
{Operation} = require '../blockchain/operation'
{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{Signature} = require '../ecc/signature'
{SignedTransaction} = require '../blockchain/signed_transaction'

LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
config = require '../config'
hash = require '../ecc/hash'
q = require 'q'
types = require '../blockchain/types'
type_id = types.type_id

class TransactionBuilder
    
    constructor:(@wallet_db, @rpc, @transaction_ledger)->
    
    
    wallet_transfer:(
        amount
        asset
        from_name
        receiver_public
        memo_message
        vote_method
        aes_root
    )->
        sender_private = @wallet_db.getActivePrivate from_name
        child_account_index = 1 #move to wallet_db
        otk_private = ExtendedAddress.private_key sender_private, child_account_index
        
        owner = ExtendedAddress.derivePublic_outbound otk_private, receiver_public
        to_address = Address.fromBuffer(owner.toBuffer()).toString()
        
    
    wallet_transfer_to_address:(
        amount
        asset
        from_name
        to_address
        memo_message
        vote_method
        aes_root
    )->
        defer = q.defer()
        sender_private = null # non titan
        LE.throw 'wallet.invalid_amount', [amount] unless amount > 0
        LE.throw 'chain.unknown_asset', [asset] unless asset.id >= 0
        from_account = @wallet_db.lookup_account from_name
        LE.throw 'wallet.account_not_found', [from] unless from_account
        try
            Address.fromString to_address
        catch error
            LE.throw 'wallet.invalid_public_key', [to_address], error
        EC.throw "Un-implemented vote method: #{vote_method}" unless vote_method is ""
            
        owner_key = @wallet_db.getOwnerKey from_name
        unless owner_key
            EC.throw "Sender account '#{from_name}' is missing"
            
        precise_amount = amount * asset.precision
        asset_to_transfer = asset_id: asset.id, amount: precise_amount
        
        sender_private = @wallet_db.getActivePrivate aes_root, from_name
        LC.throw "wallet.account_without_private_key", [from_name] unless sender_private
        sender_public = sender_private.toPublicKey()
        
        fees = @wallet_db.get_transaction_fee()
        
        promises = []
        operations = []
        required_signatures = []
        
        if fees.asset_id is asset.id
            asset_amount = 
                asset_id: fees.asset_id
                amount: fees.amount + precise_amount
            
            promises.push @withdraw_operations(
                asset_amount
                from_name
                operations
                required_signatures
                sender_private
            )
        else
            promises.push @withdraw_operations(
                asset_to_transfer
                from_name
                operations
                required_signatures
                sender_private
            )
            promises.push @withdraw_operations(
                fees
                from_name
                operations
                required_signatures
                sender_private
            )
        
        q.all(promises).then(
            ()=>
                #slate_id = my->select_slate( trx, asset_to_transfer.asset_id, selection_method )
                slate_id = 0
                
                operations.push @deposit_operation to_address, asset_to_transfer, slate_id
                record = {}
                sign_transaction = @sign_transaction(
                    aes_root
                    required_signatures
                    @transaction slate_id, operations
                )
                sign_transaction.toJson record.trx = {}
                
                record.ledger_entries = [
                    from_account: sender_public.toBtsPublic()
                    to_account:null
                    amount: asset_to_transfer
                    memo: memo_message
                    memo_from_account: null
                ]
                record.fee = fees
                record.created_time = new Date().toISOString().split('.')[0]
                #record.received_time = new Date().toISOString().split('.')[0]
                record.extra_addresses = [to_address]
                defer.resolve record
            (error)->
                defer.reject error
        ).done()
        defer.promise
    
    account_register:(
        account_name
        pay_from_account
        public_data=null
        delegate_pay_rate = -1
        account_type = "titan_account"
    )->
        defer = q.defer()
        LE.throw "wallet.must_be_opened" unless @wallet_db
        if delegate_pay_rate isnt -1
            EC.throw 'Not implemented'
        
        owner_key = @wallet_db.getOwnerKey account_name
        unless owner_key
            EC.throw "Create account before registering"
        
        active_key = @wallet_db.getActiveKey account_name
        unless active_key
            EC.throw "Unknown pay_from account #{pay_from_account}"
        
        meta_data = null
        if account_type
            type_id = RegisterAccount.type[account_type]
            if type_id is undefined
                EC.throw "Unknown account type: #{account_type}"
            meta_data=
                type: type_id
                data: new Buffer("")
        if delegate_pay_rate > 100
            LE.throw 'wallet.delegate_pay_rate_invalid', [delegate_pay_rate]
        
        operations = []
        public_data = "" unless public_data
        register = new RegisterAccount(
            new Buffer account_name
            new Buffer public_data
            owner_key
            active_key
            delegate_pay_rate
            meta_data
        )
        operations.push new Operation register.type_id, register
        
        required_signatures = []
        account_segments = account_name.split '.'
        if account_segments.length > 1
            EC.throw 'Not implemented'
            ###
            parents = account_segments.slice 1
            for parent in parents
                account = @wallet_db.lookup_account parent
                unless account
                    LE.throw 'wallet.need_parent_for_registration', [parent]
                
                #continue if account.is_retracted #active_key == public_key
                @wallet_db.has_private_key account
                required_signatures.push @wallet_db.lookup_active_key parent
            ###
        
        fees = @wallet_db.get_transaction_fee()
        
        #if delegate_pay_rate isnt -1
            #calc and add delegate fee
        @withdraw_to_transaction(
            fees
            pay_from_account
            required_signatures
        ).then(
            (withdraws)=>
                #entry = {}
                #entry.from_account = ""
                for withdraw in withdraws
                    operations.push new Operation withdraw.type_id, withdraw
                
                defer.resolve @transaction slate_id, operations
            (error)->
                defer.reject error
                
        ).done()
        defer.promise
        
    transaction:(slate_id, operations) ->
        exp = @wallet_db.get_trx_expiration()
        new Transaction(
            expiration = exp.getTime()
            slate_id = null
            operations
        )
    
    sign_transaction:(aes_root, required_signatures, transaction) ->
        private_keys = []
        for required_signature in required_signatures
            console.log 'required_signature',required_signature
            private_key = @wallet_db.getPrivateKey aes_root, required_signature
            EC.throw "Missing private key for address #{required_signature}" unless private_key
            private_keys.push private_key
        
        trx_buffer = transaction.toBuffer()
        chain_id_buffer = new Buffer(config.chain_id, 'hex')
        trx_sign = Buffer.concat([trx_buffer, chain_id_buffer])
        sigs = []
        for pk in private_keys
            sigs.push Signature.signBuffer trx_sign, pk
        new SignedTransaction transaction, sigs
        
    deposit_operation:(to_address, asset_to_transfer, slate_id = null, titan_memo = null) ->
        otk = memo = null
        if titan_memo
            otk = PublicKey.fromBtsPublic titan_memo.one_time_key
            memo = titan_memo.encrypted_memo_data
        
        wc = new WithdrawCondition(
            asset_to_transfer.asset_id
            slate_id
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType(
                Address.fromString(to_address).toBuffer()
                otk, memo
            )
        )
        deposit = new Deposit asset_to_transfer.amount, wc
        new Operation deposit.type_id, deposit
    
    withdraw_operations:(asset_amount, from_name, operations, signatures, sender_private)->
        defer = q.defer()
        @withdraw_to_transaction(
            asset_amount
            from_name
            signatures
            sender_private
        ).then(
            (withdraws)=>
                for withdraw in withdraws
                    operations.push new Operation withdraw.type_id, withdraw
                defer.resolve()
            (error)->
                defer.reject error
                
        ).done()
        defer.promise
    
    withdraw_to_transaction:(
        amount_to_withdraw
        from_account_name
        required_signatures
        sender_private # for titan
    )->
        defer = q.defer()
        asset_id = amount_to_withdraw.asset_id
        amount = amount_to_withdraw.amount
        owner=(balance_record)=>
            id = balance_record[0]
            balance = balance_record[1]
            if balance.snapshot_info?.original_address
                return @wallet_db.lookup_active_key from_account_name
                
            #owner_private = ExtendedAddress.private_key_child sender_private, trx1_one_time_key
            console.log 'not implemented: balance_record',balance_record
        
        @get_account_balance_records(from_account_name).then(
            (balances)=>
                #console.log balances,'b'
                withdraws = []
                amount_remaining = amount
                for record in balances
                    rec_balance_id = record[0]
                    rec_asset_id = record[1].condition.asset_id
                    rec_amount = record[1].balance
                    rec_owner = record[1].condition.data.owner
                    #continue if balance = record.get_spendable_balance( _blockchain->get_pending_state()->now() ) < 0
                    continue if rec_amount <= 0
                    continue if rec_asset_id isnt asset_id
                    if amount_remaining > rec_amount
                        withdraws.push new Withdraw(
                            Address.fromString(rec_balance_id).toBuffer()
                            rec_amount
                        )
                        required_signatures.push owner record
                        amount_remaining -= balance
                    else
                        withdraws.push new Withdraw(
                            Address.fromString(rec_balance_id).toBuffer()
                            amount_remaining
                        )
                        amount_remaining = 0
                        required_signatures.push owner record
                        break
                    
                if amount_remaining isnt 0
                    available = amount - amount_remaining
                    error = new LE 'wallet.insufficient_funds', amount, available
                    defer.reject error
                    return
                
                defer.resolve withdraws
            (error)->
                defer.reject error
        ).done()
        defer.promise
        
    get_account_balance_records:(account_name)->
        defer = q.defer()
        #EC.throw "Account not found #{account_name}"
        balances = []
        balances.push (=>
            # genesis credit
            account = @wallet_db.lookup_account account_name
            owner_public = PublicKey.fromBtsPublic account.owner_key
            owner_pts = owner_public.toPtsAddy()
            owner_pts
        )()
        wcs = @transaction_ledger.getWithdrawConditions account_name
        balances.push wc.getBalanceId() for wc in wcs
        console.log 'balances',balances
        @blockchain_lookup_balances(balances).then(
            (balance_records)->
                console.log 'balance_records',JSON.stringify balance_records,null,4
                defer.resolve balance_records
            (error)->
                defer.reject error
        ).done()
        defer.promise
    
    blockchain_lookup_balances:(balances)->
        defer = q.defer()
        batch_ids = []
        batch_ids.push [id] for id in balances
        @rpc.request("batch", ["blockchain_list_address_balances", batch_ids]).then(
            (batch_balances)->
                ###
                blockchain_list_address_balances= = [[
                  "XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP"
                  {
                    condition:
                      asset_id: 0
                      slate_id: 0
                      type: "withdraw_signature_type"
                      data:
                        owner: "XTSD5rYtofD6D4UHJH6mo953P5wpBfMhdMEi"
                        memo: null
                
                    balance: 99009900990
                    restricted_owner: null
                    snapshot_info:
                      original_address: "Po3mqkgMzBL4F1VXJArwQxeWf3fWEpxUf3"
                      original_balance: 99009900990
                
                    deposit_date: "1970-01-01T00:00:00"
                    last_update: "2014-10-07T10:55:00"
                  }
                ]]
                ###
                # or [] (no genesis claim)
                balance_records = []
                for balances in batch_balances
                    for balance in balances
                        #console.log 'balance',balance
                        unless balance[1].condition.type is "withdraw_signature_type"
                            console.log "WARN: unsupported balance record #{balance[1].condition.type}"
                            continue
                        balance_records.push balance
                    defer.resolve balance_records
            (error)->
                defer.reject error
        ).done()
        ###
        @rpc.request("blockchain_get_pending_transactions",[]).then(
            (result)->
                # TODO need example output to complete...
                console.log 'get_account_balance_records',result
                defer.resolve balance_records
            (error)->
                defer.reject error
        ).done()
        ###
        defer.promise

exports.TransactionBuilder = TransactionBuilder