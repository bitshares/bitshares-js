{Transaction} = require '../blockchain/transaction'
{RegisterAccount} = require '../blockchain/register_account'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{Withdraw} = require '../blockchain/withdraw'
{Deposit} = require '../blockchain/deposit'
{WithdrawCondition} = require '../blockchain/withdraw_condition'
{WithdrawSignatureType} = require '../blockchain/withdraw_signature_type'
{SignedTransaction} = require '../blockchain/signed_transaction'
{Operation} = require '../blockchain/operation'
{MemoData} = require '../blockchain/memo_data'

{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{Signature} = require '../ecc/signature'
{ExtendedAddress} = require '../ecc/extended_address'

LE = require('../common/exceptions').LocalizedException
config = require '../config'
hash = require '../ecc/hash'
q = require 'q'
types = require '../blockchain/types'
type_id = types.type_id

BTS_BLOCKCHAIN_MAX_MEMO_SIZE = 19

class TransactionBuilder
    
    constructor:(@wallet, @rpc, @aes_root)->
        throw new Error 'wallet is a required parameter' unless @wallet
        @blockchain_api = new BlockchainAPI @rpc
        now = new Date().toISOString().split('.')[0]
        @transaction_record =
            trx: {}
            ledger_entries: []
            created_time: now
            received_time: now
        @signatures = []
        @required_signatures = {}
        @outstanding_balances = {}
        #@account_balance_records = {}
        #@notices = []
        @operations = []
        @order_keys = {}
        @slate_id = null
    
    ### @return record with private journal entries ###
    get_transaction_record:()->
        throw new Error 'call finalize first' unless @finalized
        record = @transaction_record
        record.trx.expiration = @expiration.toISOString().split('.')[0]
        record.trx.slate_id = @slate_id
        record.trx.operations = ops = []
        for op in @operations
            op.toJson(o = {})
            ops.push o
        
        record.trx.signatures = sigs = []
        sigs.push sig.toHex() for sig in @signatures
        
        record
    
    get_binary_transaction:()->
        throw new Error 'call finalize first' unless @finalized
        return @binary_transaction if @binary_transaction
        throw new Error 'call sign_transaction first'
    
    ### @return public transaction for broadcast ###
    get_signed_transaction:()->
        throw new Error 'call finalize first' unless @finalized
        return @signed_transaction if @signed_transaction
        throw new Error 'call sign_transaction first'
    
    deposit_asset:(
        payer, recipient, amount
        memo, vote_method
        memo_sender #BTS Public Key String
        use_stealth_address
        fee
    )->
        throw new Error 'missing payer' unless payer?.name
        throw new Error 'missing recipient' unless recipient?.name
        throw new Error 'missing amount' unless amount?.amount
        
        #TODO
        #if recipient.is_retracted #active_key() == public_key_type()
        #    LE.throw 'blockchain.account_retracted',[recipient.name]
        
        unless amount and amount.amount > 0
            LE.throw 'Invalid amount', [amount]
        
        if memo?.length > BTS_BLOCKCHAIN_MAX_MEMO_SIZE
            LE.throw 'chain.memo_too_long'
        
        recipientActivePublic = @wallet.getActiveKey recipient.name
        payerActivePublic = @wallet.getActiveKey payer.name
        
        unless memo_sender
            memo_sender = @wallet.lookup_active_key payer.name
        
        titan_one_time_key = null
        if recipient.meta_data?.type? is "public_account"
            @deposit(
                recipientActivePublic, amount, 
                0 #@wallet.select_slate trx, amount.asset_id, vote_method
            )
        else
            one_time_key = @wallet.getNewPrivateKey payer.name
            titan_one_time_key = one_time_key.toPublicKey()
            memoSenderPrivate = @wallet.getPrivateKey memo_sender
            memoSenderPublic = memoSenderPrivate.toPublicKey()
            @deposit_to_account(
                recipientActivePublic, amount
                memoSenderPrivate, memo
                0 # @wallet.select_slate_id trx, amount.asset_id, vote_method
                memoSenderPublic
                one_time_key, 0 # memo_flags_enum from_memo
                use_stealth_address
            )
        
        @transaction_record.fee = fee
        @_deduct_balance payer.owner_key, fee, payer
        @_deduct_balance payer.owner_key, amount, payer
        
        @transaction_record.ledger_entries.push ledger_entry =
            from_account: payer.owner_key
            to_account: recipient.owner_key
            amount: amount
            memo: memo
        if memo_sender isnt payerActivePublic.toBtsPublic()
            ledger_entry.memo_from_account = memo_sender
        ###
        # mailbox notification for titan
        memo_signature= =>
            private_key = @wallet.get_private_key memo_sender
            Signature.sign memo, private_key
        
        @notices.push
            transaction_notice:  new TransactionNotice(
                null, new Buffer memo
                titan_one_time_key
                memo_signature()
            )
            recipient_active_key: recipientActivePublic
        ###
    ###
    # mailbox notification for titan
    encrypted_notifications:->
        signed_transaction = @get_signed_transaction()
        messages = []
        for notice in notices
            notice.transaction_notice.signed_transaction = signed_transaction
            
        for notice in @notices
            # chnage generate_new_one_time_key to deterministic (better security)
            one_time_key = @wallet_db.generate_new_one_time_key @aes_root
            mail = new Mail(
                1 #transaction_notice
                notice.recipient_active_key.toBlockchainAddress()
                0 #nonce
                new Date()                notice.transaction_notice.toBuffer()
            )
            aes = one_time_key.sharedAes notice.recipient_active_key
            encrypted_mail = new EncryptedMail(
                one_time_key.toPublicKey()
                aes.encrypt mail.toBuffer()
            )
            messages.push encrypted_mail
        messages
    ###
    order_key_for_account:(account_address, account_name)->
        order_key = @order_keys[account_address]
        unless order_key
            order_key = @wallet.getNewPublicKey account_name
            order_keys[account_address] = order_key
        order_key
    
    deposit:(recipientPublic, amount, slate_id)->
        deposit = new Deposit amount.amount, new WithdrawCondition(
            amount.asset_id, slate_id
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType new Buffer recipientPublic.toBtsAddy()
        )
        @operations.push new Operation deposit.type_id, deposit
    
    deposit_to_account:(
        receiver_Public, amount
        from_Private, memo_message, slate_id
        memo_Public, one_time_Private, memo_type
        use_stealth_address = true
    )->
        #TITAN used for memos even if it is not used for the transfer...
        memo = @encrypt_memo_data(
            one_time_Private, receiver_Public, from_Private,
            memo_message, memo_Public, memo_type
        )
        owner =
            if use_stealth_address
                memo.owner
            else
                receiver_Public.toBlockchainAddress()
        
        withdraw_condition = =>
            new WithdrawCondition(
                amount.asset_id, slate_id
                type_id(types.withdraw, "withdraw_signature_type"), 
                new WithdrawSignatureType(
                    owner, memo.one_time_key
                    memo.encrypted_memo_data
                )
            )
        deposit = new Deposit amount.amount, withdraw_condition()
        @operations.push new Operation deposit.type_id, deposit
        memo.receiver_address_Public
    
    encrypt_memo_data:(
        one_time_Private, to_Public, from_Private,
        memo_message, memo_Public, memo_type
    )->
        secret_Public = ExtendedAddress.deriveS_PublicKey(
            one_time_Private, to_Public
        )
        memo_content=->
            check_secret = from_Private.sharedSecret secret_Public.toUncompressed()
            new MemoData(
                memo_Public
                check_secret
                new Buffer memo_message
                memo_type
            )
        
        owner: secret_Public.toBlockchainAddress()
        one_time_key: one_time_Private.toPublicKey()
        encrypted_memo_data: (->
            aes = one_time_Private.sharedAes to_Public
            aes.encrypt memo_content().toBuffer()
        )()
        receiver_address_Public: secret_Public
    
    ###
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
    ###
    account_register:(
        account_to_register
        pay_from_account
        public_data=""
        delegate_pay_rate = -1
        account_type
        fee
    )->
        LE.throw "wallet.must_be_opened" unless @wallet
        as_delegate = no
        if delegate_pay_rate isnt -1
            throw new Error "delegate account registration is not implemented"
            as_delegate = yes
        
        owner_key = @wallet.getOwnerKey account_to_register
        active_key = @wallet.getActiveKey account_to_register
        unless owner_key
            LE.throw "create_account_before_register"
        
        pay_from_OwnerKey = @wallet.getOwnerKey pay_from_account
        unless pay_from_OwnerKey
            LE.throw "blockchain.unknown_account", pay_from_account
        
        meta_data = null
        if account_type is "public_account"
            type_id = RegisterAccount.type[account_type]
            if type_id is undefined
                throw new Error "Unknown account type: #{account_type}"
            meta_data=
                type: type_id
                data: new Buffer("")
        
        if delegate_pay_rate > 100
            LE.throw 'wallet.delegate_pay_rate_invalid', [delegate_pay_rate]
        
        register = new RegisterAccount(
            new Buffer account_to_register
            public_data
            owner_key
            active_key
            delegate_pay_rate
            meta_data
        )
        @operations.push new Operation register.type_id, register
        
        account_segments = account_to_register.split '.'
        if account_segments.length > 1
            throw new Error 'untested'
            ###
            parents = account_segments.slice 1
            for parent in parents
                account = @wallet.get_chain_account parent
                unless account
                    LE.throw 'wallet.need_parent_for_registration', [parent]
                
                #continue if account.is_retracted #pay_from_OwnerKey == public_key
                @wallet.has_private_key account
                @required_signatures[@wallet.lookup_active_key parent] = on
            ###
        
        @_deduct_balance pay_from_OwnerKey.toBtsPublic(), fee 
        
        if delegate_pay_rate isnt -1
            #calc and add delegate fee
            throw new Error 'not implemented'
        
        @transaction_record.ledger_entries.push ledger_entry =
            from_account: pay_from_OwnerKey.toBtsPublic()
            to_account: owner_key.toBtsPublic()
            amount: {amount:0, asset_id: 0}
            memo: "register " + account_to_register + (if as_delegate then " as a delegate" else "")
            memo_from_account:null
        
        @transaction_record.fee = fee
        
    withdraw_to_transaction:(
        amount_to_withdraw
        from_account_name
    )->
        defer = q.defer()
        throw new Error 'missing from account' unless from_account_name
        amount_remaining = amount_to_withdraw.amount
        withdraw_asset_id = amount_to_withdraw.asset_id
        ###
        owner_private=(balance_record)=>
            id = balance_record[0]
            balance = balance_record[1]
            if balance.snapshot_info?.original_address
                activePrivate = @wallet.getActivePrivate from_account_name
                unless activePrivate
                    throw new Error "account '#{from_account_name}' is missing active private key"
                return activePrivate
            
            throw new Error "... correct one_time_public path \t"+JSON.stringify balance_record
            #one_time_public = balance_record[1].memo.one_time_public
            #sender_private = @wallet.getActivePrivate @aes_root, from_account_name
            #ExtendedAddress.private_key_child sender_private, one_time_public
        ###
        @get_account_balance_records(from_account_name).then(
            (key_balances)=>
                balance_records = key_balances.balance_records
                key_records = key_balances.key_records
                withdraws = []
                
                #console.log 'balance records',JSON.stringify balance_records,null,4
                for i in [0...balance_records.length] by 1
                    balance_record = balance_records[i]
                    continue if balance_record.length is 0
                    #balance_amount = @get_extended_balance(balance_record[1])
                    balance_amount = balance_record[1].balance
                    #continue unless balance_amount
                    balance_id = balance_record[0]
                    balance_asset_id = balance_record[1].condition.asset_id
                    balance_owner = balance_record[1].condition.data.owner
                    #unless @wallet.hasPrivate balance_owner
                    #    console.log "ERROR: balance record without matching private key",balance_record
                    continue if balance_amount <= 0
                    continue if balance_asset_id isnt withdraw_asset_id
                    if amount_remaining > balance_amount
                        withdraw = new Withdraw(
                            Address.fromString(balance_id).toBuffer()
                            balance_amount
                        )
                        @operations.push new Operation withdraw.type_id, withdraw
                        @required_signatures[key_records[i].public_key] = on
                        amount_remaining -= balance_amount
                    else
                        withdraw = new Withdraw(
                            Address.fromString(balance_id).toBuffer()
                            amount_remaining
                        )
                        @operations.push new Operation withdraw.type_id, withdraw
                        amount_remaining = 0
                        @required_signatures[key_records[i].public_key] = on
                        break
                    
                if amount_remaining isnt 0
                    available = amount_to_withdraw.amount - amount_remaining
                    error = new LE 'wallet.insufficient_funds', amount_to_withdraw.amount, available
                    defer.reject error
                    return
                defer.resolve()
            (error)->
                defer.reject error
        ).done()
        defer.promise
        
    get_extended_balance:(balance_record)-> # renamed from get_spendable_balance
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
                    console.log "WARN: get_extended_balance() bug in calcuating vesting balance",error,error.stack
            else
                console.log "WARN: get_extended_balance() called on unsupported withdraw type: " + balance_record.condition.type
        return
    
    ###* @return key_records:[key_records],blance_records:[blance_records]
    ###
    get_account_balance_records:(account_name, extended = false)->
        throw new Error 'account_name is required' unless account_name
        my_keys = @wallet.get_my_key_records account_name
        defer = q.defer()
        unless my_keys
            defer.resolve()
            return defer.promise

        owner_keys_params = []
        owner_keys_params.push [key.public_key] for key in my_keys
        try
            @rpc.request("batch", ["blockchain_list_key_balances", owner_keys_params]).then(
                (batch_result)=>
                    #@account_balance_records[account_name]=
                    balance_records = []
                    for balances in batch_result.result
                        if balances.length is 0
                            balance_records.push []
                            continue
                        
                        for balance in balances
                            if balance[1].condition.type is "withdraw_signature_type"
                                balance_records.push balance
                            else
                                balance_records.push []
                        
                    #if true
                    defer.resolve 
                        key_records:my_keys
                        balance_records:balance_records
                    
                    return
                (error)->
                    defer.reject error
            )
        catch error
            defer.reject error
        defer.promise
    
    blockchain_lookup_balances:(balances, extended = false)->
        defer = q.defer()
        batch_ids = []
        batch_ids.push [id, 1] for id in balances
        @rpc.request("batch", ["blockchain_list_balances", batch_ids]).then(
            (batch_balances)=>
                ###
                blockchain_list_key_balances= = [[
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
                for balances in batch_balances.result
                    for balance in balances
                        continue unless extended or
                            balance[1].condition.type is "withdraw_signature_type"
                        balance_records.push balance
                defer.resolve balance_records
            (error)->
                defer.reject error
        ).done()
        ###
        @blockchain_api.request("get_pending_transactions").then(
            (result)->
                # TODO need example output to complete...
                console.log '... result',JSON.stringify result
                defer.resolve result
            (error)->
                defer.reject error
        )
        ###
        defer.promise
        
    finalize:()->
        defer = q.defer()
        throw new Error 'already finalized' if @finalized
        @finalized = true
        throw new Error 'empty transaction' if @operations.length is 0
        if (Object.keys @outstanding_balances).length is 0
            throw new Error 'nothing to finalize'
        
        #slate = @wallet.select_delegate_vote 'vote_recommended'
        #if slate.supported_delegates.length > 0 and not @blockchain.get_delegate_slate slate_id
        #    trx.define_delegate_slate(slate);
        #else
        #    slate_id = 0
        
        p = []
        for address in Object.keys @outstanding_balances
            #account_rec = asset_id: amount.asset_id, amount: amount
            rec = @outstanding_balances[address]
            continue if rec.amount is 0
            balance = {amount:rec.amount, asset_id: rec.asset_id}
            account = @wallet.get_account_for_address address         #address->ownerkey lookup
            
            if rec.amount > 0
                depositAddress = @order_key_for_account address, account.name
                @deposit depositAddress, balance
            else
                balance.amount = -rec.amount
                p.push @withdraw_to_transaction balance, account.name
        
        for k in Object.keys @outstanding_balances
            delete @outstanding_balances[k]
        
        @expiration = @wallet.get_trx_expiration()
        q.all p
    
    sign_transaction:() ->
        unless @transaction_record.trx
            throw new Error 'call finalize first'
        
        if @signatures.length isnt 0
            throw new Error 'already signed'
        
        chain_id_buffer = new Buffer config.chain_id, 'hex'
        @binary_transaction = new Transaction(
            expiration = @expiration
            @slate_id
            @operations
        )
        trx_buffer = @binary_transaction.toBuffer()
        trx_sign = Buffer.concat([trx_buffer, chain_id_buffer])
        #console.log 'digest',hash.sha256(trx_sign).toString('hex')
        for public_key in Object.keys @required_signatures
            try
                private_key = @wallet.getPrivateKey public_key
                #console.log '...sign by', private_key.toPublicKey().toBtsPublic()
                @signatures.push(
                    Signature.signBuffer trx_sign, private_key
                )
            catch error
                console.log "WARNING unable to sign for address #{private_key.toPublicKey().toBtsPublic()}", error
        
        @signed_transaction = new SignedTransaction(
            @binary_transaction, @signatures
        )
    
    ###
    # 
    _pay_fee:->
        available_balances = @_all_positive_balances()
        required_fee = { amount:0, asset_id: -1 }
        # see if one asset can pay fee
        for asset_id in Object.keys available_balances
            amount = available_balances[asset_id]
            _required_fee = @wallet.get_transaction_fee(asset_id).then (amt)=>
                if @wallet.asset_can_pay_fee(asset_id) and amount >= _required_fee.amount
                    required_fee = _required_fee
                    @transaction_record.fee = required_fee
                    defer.resolve()
                    return
        
        if required_fee.asset_id isnt -1
            @transaction_record.fee = required_fee
            for address in @outstanding_balances
                #account_rec = asset_id: amount.asset_id, amount: amount
                rec = @outstanding_balances[address]
                continue if rec.asset_id isnt required_fee.asset_id
                if required_fee.amount > rec.amount
                    required_fee.amount -= rec.amount
                    delete @outstanding_balances[address]
                    # not enough, look for more
                    continue
                
                # fee is paied in full
                rec.amount -= required_fee.amount
                return
        else
            if @_withdraw_fee_other_asset()
                return
        
        LE.throw 'wallet.unable_to_pay_fee'
            
    # nonempty if there’s a margin position closed and the collateral is returned
    _all_positive_balances:->
        balances = {}
        for address in Object.keys @outstanding_balances
            #account_rec = asset_id: amount.asset_id, amount: amount
            rec = @outstanding_balances[address]
            continue unless rec.amount > 0
            balance = balances[rec.asset_id]
            balances[rec.asset_id] = 0 unless balance
            balances[rec.asset_id] += -1 * rec.amount
        return balances
            
    # typical case where the fee will get paid
    _withdraw_fee_other_asset:->
        throw new Error 'not implemented @wallet.get_account_balances'
        account_balances = @wallet.get_account_balances "", false
        for address in Object.keys @outstanding_balances
            #account_rec = asset_id: amount.asset_id, amount: amount
            rec = @outstanding_balances[address]
            account = @wallet_db.lookup_key rec.address
            balances = account_balances[account.name]
            continue unless balances
            for balance in balances
                fee = @wallet.get_transaction_fee balance.asset_id
                continue if fee.asset_id isnt balance.asset_id or fee.amount > balance.amount
                @_deduct_balance address, fee, key.account
                @transaction_record.fee = fee
                return true
        return false
    ###
    
    # manually tweak an account's balance in this transaction
    _deduct_balance:(address, amount)->
        unless amount.amount >= 0
            throw new Error "amount must be positive"
        record = @outstanding_balances[address]
        unless record
            @outstanding_balances[address] = record =
                address:address
                asset_id: amount.asset_id
                amount: 0
        record.amount -= amount.amount
        
    # manually tweak an account's balance in this transaction
    _credit_balance:(address, amount)->
        unless amount.amount >= 0
            throw new Error "amount must be positive"
        record = @outstanding_balances[address]
        unless record
            @outstanding_balances[address] = record =
                address:address
                asset_id: amount.asset_id
                amount: 0
        record.amount += amount.amount

exports.TransactionBuilder = TransactionBuilder
