{Transaction} = require '../blockchain/transaction'
{RegisterAccount} = require '../blockchain/register_account'
{Withdraw} = require '../blockchain/withdraw'
{Deposit} = require '../blockchain/deposit'
{WithdrawCondition} = require '../blockchain/withdraw_condition'
{WithdrawSignatureType} = require '../blockchain/withdraw_signature_type'
{SignedTransaction} = require '../blockchain/signed_transaction'
{Operation} = require '../blockchain/operation'

{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{Signature} = require '../ecc/signature'
{ExtendedAddress} = require '../ecc/extended_address'

LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
config = require '../config'
hash = require '../ecc/hash'
q = require 'q'
types = require '../blockchain/types'
type_id = types.type_id

BTS_BLOCKCHAIN_MAX_MEMO_SIZE = 19

class TransactionBuilder
    
    constructor:(@wallet, @rpc, @transaction_ledger, @aes_root)->
        @mail_trx_notices = []
        #@signed_transaction = {}
        now = new Date().toISOString().split('.')[0]
        @transaction_record =
            ledger_entries: []
            created_time: now
            received_time: now
            
        @outstanding_balances = {}
        @operations = []
        @order_keys = {}
    
    deposit_asset:(
        payer, recipient, amount
        memo_message, vote_method
        memo_sender_public #BTS Public Key String
    )->
        unless payer and recipient and amount
            EC.throw 'missing required parameter'
        
        if recipient.is_retracted #active_key() == public_key_type()
            LE.throw 'blockchain.account_retracted',[recipient.name]
        
        unless amount and amount.amount > 0
            LE.throw 'Invalid amount', [amount]
        
        if memo_message?.length > BTS_BLOCKCHAIN_MAX_MEMO_SIZE
            LE.throw 'chain.memo_too_long'
        
        recipientActivePublic = @wallet.getActiveKey recipient.name
        payerActivePublic = @wallet.getActiveKey payer.name
        
        unless memo_sender_public
            console.log JSON.stringify payer,'bk'
            memo_sender_public = @wallet.lookup_active_key payer.name
        memoSenderPrivate = @wallet.getPrivateKey memo_sender_public
        
        oneTimePublic = null
        operations = []
        if recipient.meta_data?.type? is "public_account"
            @deposit(
                recipientActivePublic, amount, 
                0 #@wallet.select_slate trx, amount.asset_id, vote_method
            )
        else
            oneTimePrivate = @wallet.getNewPrivateKey payer.name
            oneTimePublic = oneTimePrivate.getPublicKey()
            @deposit_to_account( # trx
                recipientActivePublic, amount
                memoSenderPrivate, memo
                0 # @wallet.select_slate_id trx, amount.asset_id, vote_method
                oneTimePrivate, 'from_memo'
            )
        
        @_deduct_balance payer.owner_key, amount, payer
        
        @transaction_record.ledger_entries.push ledger_entry =
            from_account: payer.owner_key
            to_account: recipient.owner_key
            amount: amount
            memo: memo_message
        if memo_sender_public isnt payerActivePublic
            ledger_entry.memo_from_account = memo_sender_public
        
        @mail_trx_notices.push (=>
            sig = Signature.sign memo_message, memoSenderPrivate
            [
                extended_memo: memo
                one_time_private: oneTimePrivate
                memo_signature: sig
            ,
                recipientActivePublic
            ]
        )()
    
    finalize:()->
        EC.throw 'empty transaction' if @operations.length is 0
        #slate = @wallet.select_delegate_vote 'vote_recommended'
        #if slate.supported_delegates.length > 0 and not @blockchain.get_delegate_slate slate_id
        #    trx.define_delegate_slate(slate);
        #else
        #    slate_id = 0
        
        @transaction.fee = @_pay_fee()
        
        slate_id = 0
        for key in Object.keys @outstanding_balances
            #key = address:address, asset_id: amount.asset_id, account: account
            amount_value = @outstanding_balances[key]
            continue if amount_value is 0
            balance = {amount:amount_value, asset_id: key.asset_id}
            account_name = key.account.name
            #address->ownerkey lookup 
            
            if amount_value > 0
                depositAddress = @order_key_for_account key.address, account_name
                @deposit depositAddress, balance, slate_id
            else
                balance.amount = -amount_value
                @withdraw_to_transaction balance, account_name, required_signatures
        
        return record
        
    order_key_for_account:(account_address, account_name)->
        #todo, why cache until client re-start?  why not always or never?
        order_key = @order_keys[account_address]
        unless order_key
            order_key = @wallet.getNewPublicKey account_name
            order_keys[account_address] = order_key
        return order_key
    
    _pay_fee:->
        available_balances = @_all_positive_balances()
        required_fee = { amount:0, asset_id: -1 }
        # see if one asset can pay fee
        for asset_id in Object.keys available_balances
            amount = available_balances[asset_id]
            required_fee = @wallet.get_transaction_fee asset_id
            if @wallet.asset_can_pay_fee(asset_id) and amount >= required_fee.amount
                @transaction_record.fee = required_fee
                break
        
        if required_fee.asset_id isnt -1
            @transaction_record.fee = required_fee
            for key in @outstanding_balances
                #key = address:address, asset_id: asset_id, account: account
                continue if key.asset_id isnt required_fee.asset_id
                amount = @outstanding_balances[key]
                if required_fee.amount > amount
                    required_fee.amount -= amount
                    @outstanding_balances[key] = 0
                    # not enough, look for more
                    continue
                
                # fee is paied in full
                @outstanding_balances[key] -= required_fee.amount
                return
        else
            if @_withdraw_fee_desperate()
                return
        
        LE.throw 'wallet.unable_to_pay_fee'
            
    _all_positive_balances:->
        balances = {}
        for key in Object.keys @outstanding_balances
            #key = address:address, asset_id: asset_id, account: account
            amount = @outstanding_balances[key]
            continue unless amount > 0
            balance = balances[key.asset_id]
            balances[key.asset_id] = 0 unless balance
            balances[key.asset_id] += amount
        return balances
            
    _withdraw_fee_desperate:->
        get_account_balance_records
        balances = @wallet.get_account_balances "", false
        for key in Object.keys @outstanding_balances
            #key = address:address, asset_id: amount.asset_id, account: account
            amount = @outstanding_balances[key]
            holder_address = key.address # BTS Addy
            holder_account = @wallet.lookup_account_by_address holder_address
            balances_amount = balances[holder_account.name]
            continue unless balances_amount
            for balance in balances
                fee = @wallet.get_transaction_fee balance.asset_id
                continue unless fee.asset_id is balance.asset_id and fee.amount <= balance.amount
                @_deduct_balance holder_address, fee, account
                @transaction_record.fee = fee
                return true
        return false
    
    deposit:(recipientPublic, amount, slate_id)->
        deposit = new Deposit amount.amount, new WithdrawCondition(
            amount.asset_id, slate_id
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType recipientPublic.toBtsAddy()
        )
        @operations.push new Operation deposit.type_id, deposit
    
    deposit_to_account:(
        recipientPublic, amount
        memoSenderPrivate, memo, slate_id
        oneTimePrivate, memo_type
    )->
        EC.throw 'not implemented' if memo
        
        memoSenderPublic = memoSenderPrivate.toPublicKey()
        ###
        receiver_address = WithdrawTypes.encrypt_memo_data(
            oneTimePrivate, recipientPublic, memoSenderPrivate,
            memo, memoSenderPublic, memo_type
        )###
        encrypted_memo_data = ""
        
        wws = new WithdrawSignatureType(
            recipientPublic.toBtsAddy()
            oneTimePublic, encrypted_memo_data
        )
        wc = new WithdrawCondition(
            amount.asset_id, slate_id
            type_id(types.withdraw, "withdraw_signature_type"), 
            wws
        )
        deposit = new Deposit amount.amount, wc
        @operations.push new Operation deposit.type_id, deposit

    sign:->
        
        record
    
    wallet_transfer:(
        amount, asset
        from_name, to_public
        memo_message, vote_method
    )->
        defer = q.defer()
        if memo_message?.length > BTS_BLOCKCHAIN_MAX_MEMO_SIZE
            LE.throw 'chain.memo_too_long' 
        
        otk_private = @wallet.generate_new_account_child_key(
            @aes_root
            from_name
        )
        owner = ExtendedAddress.derivePublic_outbound otk_private, to_public
        one_time_public = otk_private.toPublicKey()
        sender_private = @wallet.getActivePrivate @aes_root, from_name
        aes = sender_private.sharedAes one_time_public
        encrypted_memo = if memo_message then aes.encrypt memo_message else ""
        @_transfer(
            amount
            asset
            from_name
            owner.toBtsAddy()
            memo_message
            encrypted_memo
            vote_method
            one_time_public
            to_public
        ).then(
            (result)->defer.resolve result
            (error)->defer.reject error
        ).done()
        defer.promise
    
    _transfer:(
        amount
        asset
        from_name
        to_address
        memo_message
        encrypted_memo
        vote_method
        one_time_public = null
        to_public = null
    )->
        defer = q.defer()
        
        LE.throw 'wallet.invalid_amount', [amount] unless amount > 0
        LE.throw 'blockchain.unknown_asset', [asset] unless asset.id >= 0
        from_account = @wallet.lookup_account from_name
        LE.throw 'wallet.account_not_found', [from] unless from_account
        try
            Address.fromString to_address
        catch error
            LE.throw 'wallet.invalid_public_key', [to_address], error
        EC.throw "Un-implemented vote method: #{vote_method}" unless vote_method is ""
            
        owner_key = @wallet.getOwnerKey from_name
        unless owner_key
            EC.throw "Sender account '#{from_name}' is missing"
            
        precise_amount = amount * asset.precision
        asset_to_transfer = asset_id: asset.id, amount: precise_amount
        
        fees = @wallet.get_transaction_fee()
        
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
            )
        else
            promises.push @withdraw_operations(
                asset_to_transfer
                from_name
                operations
                required_signatures
            )
            promises.push @withdraw_operations(
                fees
                from_name
                operations
                required_signatures
            )
        
        q.all(promises).then(
            ()=>
                #slate_id = my->select_slate( trx, asset_to_transfer.asset_id, selection_method )
                slate_id = 0
                
                operations.push @deposit_operation to_address, asset_to_transfer, slate_id, one_time_public, encrypted_memo
                record = {}
                sign_transaction = @sign_transaction(
                    required_signatures
                    @transaction slate_id, operations
                )
                sign_transaction.toJson record.trx = {}
                
                record.ledger_entries = [
                    from_account: @wallet.lookup_owner_key from_name
                    to_account: if to_public then to_public.toBtsPublic() else null
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
        LE.throw "wallet.must_be_opened" unless @wallet
        if delegate_pay_rate isnt -1
            EC.throw 'Not implemented'
        
        owner_key = @wallet.getOwnerKey account_name
        unless owner_key
            EC.throw "Create account before registering"
        
        active_key = @wallet.getActiveKey account_name
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
                account = @wallet.lookup_account parent
                unless account
                    LE.throw 'wallet.need_parent_for_registration', [parent]
                
                #continue if account.is_retracted #active_key == public_key
                @wallet.has_private_key account
                required_signatures.push @wallet.lookup_active_key parent
            ###
        
        fees = @wallet.get_transaction_fee()
        
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
                
                defer.resolve @transaction slate_id=0, operations
            (error)->
                defer.reject error
                
        ).done()
        defer.promise
        
    transaction:(slate_id, operations) ->
        exp = @wallet.get_trx_expiration()
        new Transaction(
            expiration = exp.getTime()
            slate_id = null
            operations
        )
    
    sign_transaction:(required_signatures, transaction) ->
        trx_buffer = transaction.toBuffer()
        chain_id_buffer = new Buffer config.chain_id, 'hex'
        trx_sign = Buffer.concat([trx_buffer, chain_id_buffer])
        #console.log 'digest',hash.sha256(trx_sign).toString('hex')
        sigs = []
        for private_key in required_signatures
            #console.log 'sign by', private_key.toPublicKey().toBtsPublic()
            sigs.push Signature.signBuffer trx_sign, private_key
        new SignedTransaction transaction, sigs
    
    deposit_operation:(
        to_address
        asset_to_transfer
        slate_id = null
        one_time_public = null
        encrypted_memo_data
    ) ->
        #FC_ASSERT( amount.amount > 0, "amount: ${amount}", ("amount",amount) );
        #operations.push_back( deposit_operation( owner, amount, slate_id ) );
        wc = new WithdrawCondition(
            asset_to_transfer.asset_id
            slate_id
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType(
                Address.fromString(to_address).toBuffer()
                one_time_public, encrypted_memo_data
            )
        )
        deposit = new Deposit asset_to_transfer.amount, wc
        new Operation deposit.type_id, deposit
    
    withdraw_operations:(asset_amount, from_name, operations, signatures)->
        defer = q.defer()
        @withdraw_to_transaction(
            asset_amount
            from_name
            signatures
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
    )->
        defer = q.defer()
        amount_remaining = amount_to_withdraw.amount
        withdraw_asset_id = amount_to_withdraw.asset_id
        owner_private=(balance_record)=>
            id = balance_record[0]
            balance = balance_record[1]
            if balance.snapshot_info?.original_address
                return @wallet.getActivePrivate @aes_root, from_account_name
            
            console.log 'correct one_time_public path', balance_record
            one_time_public = balance_record.memo.one_time_public
            sender_private = @wallet.getActivePrivate @aes_root, from_account_name
            ExtendedAddress.private_key_child sender_private, one_time_public
        
        @get_account_balance_records(from_account_name).then(
            (balance_records)=>
                #console.log balance_records,'b'
                withdraws = []
                
                #console.log 'balance records',JSON.stringify balance_records,null,4
                for record in balance_records
                    balance_amount = @get_spendable_balance(record[1])
                    continue unless balance_amount
                    balance_id = record[0]
                    balance_asset_id = record[1].condition.asset_id
                    balance_owner = record[1].condition.data.owner
                    
                    continue if balance_amount <= 0
                    continue if balance_asset_id isnt withdraw_asset_id
                    if amount_remaining > balance_amount
                        withdraws.push new Withdraw(
                            Address.fromString(balance_id).toBuffer()
                            balance_amount
                        )
                        required_signatures.push owner_private record
                        amount_remaining -= balance_amount
                    else
                        withdraws.push new Withdraw(
                            Address.fromString(rec_balance_id).toBuffer()
                            amount_remaining
                        )
                        amount_remaining = 0
                        required_signatures.push owner_private record
                        break
                    
                if amount_remaining isnt 0
                    available = amount_to_withdraw.amount - amount_remaining
                    error = new LE 'wallet.insufficient_funds', amount_to_withdraw.amount, available
                    defer.reject error
                    return
                
                defer.resolve withdraws
            (error)->
                defer.reject error
        ).done()
        defer.promise
        
    get_spendable_balance:(balance_record)->
        switch balance_record.condition.type
            when "withdraw_signature_type" or "withdraw_escrow_type" or "withdraw_multisig_type"
                return balance_record.balance
            when "withdraw_vesting_type"
                vc = balance_record.condition
                try
                    at_time = (new Date().getTime()) / 1000
                    vc_start = (new Date(vc.start_time).getTime()) / 1000
                    max_claimable = 0
                    if at_time >= vc_start + vc.duration
                        max_claimable = vc.original_balance
                    else
                        if at_time > vc_start
                            elapsed_sec = (at_time = vc_start)
                            if elapsed_sec <= 0 or elapsed_time >= vc.duration
                                throw new Error "elapsed '#{elapsed_sec}' is out of bounds"
                            max_claimable = (vc.original_balance * elapsed_sec) / vc.duration
                            if max_claimable < 0 or max_claimable >= vc.original_balance
                                throw new Error "max_claimable '#{max_claimable}; is out of bounds"
                    
                    claimed_so_far = vc.original_balance - balance_record.balance
                    if claimed_so_far < 0 or claimed_so_far > vc.original_balance
                        throw new Error "claimed_so_far '#{claimed_so_far}' is out of bounds"
                    
                    spendable_balance = max_claimable - claimed_so_far;
                    if spendable_balance < 0 or spendable_balance > vc.original_balance
                        throw new Error "spendable_balance '#{spendable_balance}' is out of bounds"
                    
                    return spendable_balance
                catch error
                    console.log "WARN: get_spendable_balance() bug in calcuating vesting balance",error,error.stack
            else
                console.log "WARN: get_spendable_balance() called on unsupported withdraw type: " + balance_record.condition.type
        return
                
        
    get_account_balance_records:(account_name)->
        defer = q.defer()
        #EC.throw "Account not found #{account_name}"
        owner_pts = (=>
            # genesis credit
            owner_public = @wallet.getOwnerKey account_name
            owner_public.toPtsAddy()
        )()
        try
            @rpc.request("blockchain_list_address_balances",[owner_pts]).then(
                (result)=>
                    balance_records = []
                    balance_records.push balance for balance in result if result
                    wcs = @wallet.getWithdrawConditions account_name
                    balance_ids = []
                    balance_ids.push wc.getBalanceId() for wc in wcs
                    #console.log 'balance_ids',balance_ids
                    if balance_ids.length is 0
                        defer.resolve balance_records
                        return
                    @blockchain_lookup_balances(balance_ids).then(
                        (result)->
                            balance_records.push balance for balance in result if result
                            defer.resolve balance_records
                    ).done()
            ).done()
        catch error
            defer.reject error
        defer.promise
    
    blockchain_lookup_balances:(balances)->
        defer = q.defer()
        batch_ids = []
        batch_ids.push [id, 1] for id in balances
        @rpc.request("batch", ["blockchain_list_balances", batch_ids]).then(
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
        
    # manually tweak an account's balance in this transaction
    _deduct_balance:(address, amount, account)->
        throw new Error "amount must be positive" unless amount.amount >= 0
        key = address:address, asset_id: amount.asset_id, account: account
        @outstanding_balances[key] = 0 unless @outstanding_balances[key] 
        @outstanding_balances[key] -= amount.amount
        
    # manually tweak an account's balance in this transaction
    _credit_balance:(address, amount, account)->
        throw new Error "amount must be positive" unless amount.amount >= 0
        key = address:address, asset_id: amount.asset_id, account: account
        @outstanding_balances[key] = 0 unless @outstanding_balances[key] 
        @outstanding_balances[key] += amount.amount

exports.TransactionBuilder = TransactionBuilder