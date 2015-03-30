{Transaction} = require '../blockchain/transaction'
{RegisterAccount} = require '../blockchain/register_account'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{Withdraw} = require '../blockchain/withdraw'
{Deposit} = require '../blockchain/deposit'
{Short} = require '../blockchain/short'
{Ask} = require '../blockchain/ask'
{Bid} = require '../blockchain/bid'
{ChainInterface} = require '../blockchain/chain_interface'
{WithdrawCondition} = require '../blockchain/withdraw_condition'
{WithdrawSignatureType} = require '../blockchain/withdraw_signature_type'
{SignedTransaction} = require '../blockchain/signed_transaction'
{Operation} = require '../blockchain/operation'
{MemoData} = require '../blockchain/memo_data'
{Util} = require '../blockchain/market_util'

{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{Signature} = require '../ecc/signature'
{ExtendedAddress} = require '../ecc/extended_address'

LE = require('../common/exceptions').LocalizedException
config = require '../config'
hash = require '../ecc/hash'
BigInteger = require 'bigi'
q = require 'q'
types = require '../blockchain/types'
lookup_type_id = types.type_id
ByteBuffer = require 'bytebuffer'
Long = ByteBuffer.Long

BTS_BLOCKCHAIN_MAX_MEMO_SIZE = 19

class TransactionBuilder
    
    ###*
        Warning, the expiration starts now.  It is used for deterministic
        one-time-keys.
    ###
    constructor:(@wallet, @rpc, @aes_root)->
        throw new Error 'wallet is a required parameter' unless @wallet
        @expiration = @wallet.get_trx_expiration()
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
        #@notices = []
        @operations = []
        #@order_keys = {}
        @slate_id = null
    
    ### @return record with private journal entries ###
    get_transaction_record:()->
        throw new Error 'call finalize first' unless @finalized
        record = @transaction_record
        record.record_id = @binary_transaction.id().toString 'hex'
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
    
    account_register:(
        account_to_register
        pay_from_account
        public_data=""
        delegate_pay_rate = -1
        account_type
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        as_delegate = no
        if delegate_pay_rate isnt -1
            throw new Error "delegate account registration is not implemented"
            as_delegate = yes
        
        owner_key = @wallet.getOwnerKey account_to_register
        active_key = @wallet.getActiveKey account_to_register
        unless owner_key
            LE.throw "jslib_create_account_before_register"
        
        pay_from_ActiveKey = @wallet.getActiveKey pay_from_account
        unless pay_from_ActiveKey
            LE.throw "jslib_blockchain.unknown_account", [pay_from_account]
        
        meta_data = null
        if account_type is "public_account"
            type_id = RegisterAccount.type[account_type]
            if type_id is undefined
                throw new Error "Unknown account type: #{account_type}"
            meta_data=
                type: type_id
                data: new Buffer("")
        
        if delegate_pay_rate > 100
            LE.throw 'jslib_wallet.delegate_pay_rate_invalid', [delegate_pay_rate]
        
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
                    LE.throw 'jslib_wallet.need_parent_for_registration', [parent]
                
                #continue if account.is_retracted #pay_from_ActiveKey == public_key
                @wallet.has_private_key account
                @required_signatures[@wallet.lookup_active_key parent] = on
            ###
        
        if delegate_pay_rate isnt -1
            #calc and add delegate fee
            throw new Error 'not implemented'
        
        @transaction_record.ledger_entries.push ledger_entry =
            from_account: pay_from_ActiveKey.toBtsPublic()
            to_account: active_key.toBtsPublic()
            amount: {amount:0, asset_id: 0}
            memo: "register " + account_to_register + (if as_delegate then " as a delegate" else "")
            memo_from_account:null
        
        return

    deposit_asset:(
        payer, recipient, amount
        memo="", vote_method
        memo_sender #BTS Public Key String
        use_stealth_address
    )->
        throw new Error 'missing payer' unless payer?.name
        throw new Error 'missing recipient' unless recipient
        throw new Error 'missing amount' unless amount?.amount
        
        recipientActivePublic = if typeof recipient is 'string'
            PublicKey.fromBtsPublic recipient
        else
            #TODO
            #if recipient.is_retracted #active_key() == public_key_type()
            #    LE.throw 'jslib_blockchain.account_retracted',[recipient.name]
            @wallet.getActiveKey recipient.name
        
        unless amount and amount.amount > 0
            LE.throw 'jslib_Invalid amount', [amount]
        
        if memo?.length > BTS_BLOCKCHAIN_MAX_MEMO_SIZE
            LE.throw 'jslib_chain.memo_too_long'
        
        payerActivePublic = @wallet.getActiveKey payer.name
        unless memo_sender
            memo_sender = @wallet.lookup_active_key payer.name
        
        titan_one_time_key = null
        #if recipient.meta_data?.type? is "public_account"
        #    @deposit(
        #        recipientActivePublic, amount, 
        #        0 #@wallet.select_slate trx, amount.asset_id, vote_method
        #    )
        #else
        #    one_time_key
        exp_seconds = Math.floor @expiration.getTime() / 1000
        one_time_key = @wallet.getNewPrivateKey payer.name, exp_seconds
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
        @_deduct_balance payer.active_key, amount
        @transaction_record.ledger_entries.push ledger_entry =
            from_account: payer.active_key
            to_account: recipientActivePublic.toBtsPublic()
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
    
    submit_short:(
        from_account
        short_collateral_string
        collateral_asset
        interest_rate_string
        quote_asset
        price_limit_string
    )->
        interest_rate_price = (->
            price = Util.to_ugly_price(
                interest_rate_string, collateral_asset, quote_asset
                _needs_satoshi_conversion = no
            )
            price.ratio = price.ratio.divide(
                BigInteger "100"
            )
            price
        )()
        limit_price = Util.to_ugly_price(
            price_limit_string, collateral_asset, quote_asset
            _needs_satoshi_conversion = yes
        )
        if (
            limit_price.quote_asset_id isnt undefined and
            limit_price.base_asset_id isnt undefined
        ) and not (
            interest_rate_price.quote_asset_id is limit_price.quote_asset_id and
            interest_rate_price.base_asset_id is limit_price.base_asset_id
        )
            throw new Error(
                "Interest rate and price limit do not have compatible units."
                interest_rate_price
                limit_price
            )
        short_collateral = Util.to_ugly_asset(
            short_collateral_string, collateral_asset
        )
        @_deduct_balance from_account.active_key, short_collateral
        from_public = PublicKey.fromBtsPublic from_account.active_key
        short = new Short(
            short_collateral.amount
            interest_rate_price
            from_public.toBlockchainAddress()
            limit_price
        )
        @operations.push new Operation short.type_id, short
        return
    
    submit_ask:(
        from_account
        quantity_string
        quantity_asset
        quote_price_string
        quote_price_asset
    )->
        if quantity_asset.asset_id isnt quote_price_asset.asset_id
            throw Error "Unmatched asset types"
        
        sell_quantity = Util.to_ugly_asset(
            quantity_string, quantity_asset
        )
        ask_price = Util.to_ugly_price(
            quote_price_string, quantity_asset, quote_price_asset
            _needs_satoshi_conversion = yes
        )
        
        @_deduct_balance from_account.active_key, sell_quantity
        from_public = PublicKey.fromBtsPublic from_account.active_key
        ask = new Ask(
            sell_quantity.amount
            ask_price
            from_public.toBlockchainAddress()
        )
        @operations.push new Operation ask.type_id, ask
        return
    
    submit_bid:(
        from_account
        quantity_string
        quantity_asset
        quote_price_string
        quote_price_asset
    )->
        buy_quantity = Util.to_ugly_asset(
            quantity_string, quantity_asset
        )
        pay_price = Util.to_ugly_price(
            quote_price_string, quantity_asset, quote_price_asset
            _needs_satoshi_conversion = yes
        )
        cost = if quantity_asset.asset_id is quote_price_asset.asset_id
            buy_quantity
        else
            Util.asset_multple_price buy_quantity, pay_price
        
        throw new Error "Unlike assets" unless cost.asset_id is pay_price.quote
        @_deduct_balance from_account.active_key, buy_quantity
        from_public = PublicKey.fromBtsPublic from_account.active_key
        bid = new Bid(
            buy_quantity.amount
            pay_price
            from_public.toBlockchainAddress()
        )
        @operations.push new Operation bid.type_id, bid
        return
    
    cancel_order:(order)->
        owner_account = @wallet.get_account_for_address(
            order.market_index.owner
        )
        unless owner_account
            throw new Error "Unable to find account for address #{order.market_index.owner}"
        
        @required_signatures[owner_account.active_key] = on
        balance = Util.get_balance_asset order
        
        order_object = switch order.type
            when 'ask_order'
                Ask.fromJson order
            when 'bid_order'
                Bid.fromJson order
            when 'short_order'
                Short.fromJson order
            else
                throw new Error "Unimplemented cancel for #{order}"
        
        price = order_object.order_price
        owner = order_object.owner
        switch order.type
            when 'ask_order'
                ask = new Ask -1 * balance.amount, price, owner
                @operations.push new Operation ask.type_id, ask
            when 'bid_order'
                bid = new Bid -1 * balance.amount, price, owner
                @operations.push new Operation bid.type_id, bid
            when 'short_order'
                short = new Short -1 * balance.amount, price, owner
                @operations.push new Operation short.type_id, short
            else
                throw new Error "Unimplemented cancel for #{order}"
        @_credit_balance owner_account.active_key, balance
        return
    
    pay_network_fee:(payer_account, fee_asset)->
        unless payer_account.active_key
            throw new Error "expecting payer to be an account object"
        unless @transaction_record.fee
            @transaction_record.fee=[]
        
        @transaction_record.fee.push fee_asset
        @_deduct_balance payer_account.active_key, fee_asset
    
    pay_collector_fee:(payer_account, recepient_account, fee_asset)->
        unless payer_account.active_key
            throw new Error "expecting payer to be an account object"
        
        @deposit_asset payer_account, recepient_account, fee_asset
    
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
    
    #order_key_for_account:(account_address, account_name)->
    #    order_key = @order_keys[account_address]
    #    unless order_key
    #        order_key = @wallet.getNewPublicKey account_name
    #        order_keys[account_address] = order_key
    #    order_key
    
    deposit:(owner, amount, slate_id = null)->
        deposit = new Deposit amount.amount, new WithdrawCondition(
            amount.asset_id, slate_id
            lookup_type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType owner
        )
        @operations.push new Operation deposit.type_id, deposit
        return
    
    deposit_to_account:(
        receiver_Public, amount
        from_Private, memo_message, slate_id
        memo_Public, one_time_Private, memo_type
        use_stealth_address = false
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
                lookup_type_id(types.withdraw, "withdraw_signature_type")
                new WithdrawSignatureType(
                    owner, memo.one_time_key
                    memo.encrypted_memo_data
                )
            )
        
        deposit = new Deposit amount.amount, withdraw_condition()
        @operations.push new Operation deposit.type_id, deposit
        memo.receiver_address_Public
        return
    
    encrypt_memo_data:(
        one_time_Private, to_Public, from_Private,
        memo_message, memo_Public, memo_type
    )->
        secret_Public = ExtendedAddress.deriveS_PublicKey(
            one_time_Private, to_Public
        )
        memo_content=->
            check_secret = null# from_Private.sharedSecret secret_Public.toUncompressed()
            MemoData.fromCheckSecret(
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
    
    withdraw_to_transaction:(
        amount_to_withdraw
        from_account_name
        key_balances
    )->
        defer = q.defer()
        throw new Error 'missing from account' unless from_account_name
        amount_remaining = amount_to_withdraw.amount
        withdraw_asset_id = amount_to_withdraw.asset_id

        for public_key in Object.keys key_balances
            for balance_record in key_balances[public_key]
                balance_amount = balance_record[1].balance
                #continue unless balance_amount
                balance_id = balance_record[0]
                balance_asset_id = balance_record[1].condition.asset_id
                balance_owner = balance_record[1].condition.data.owner
                
                unless @wallet.getPrivateKey public_key
                    console.log "ERROR: balance owner #{balance_owner} without matching private key",balance_record
                    continue
                
                continue if balance_amount <= 0
                continue if balance_asset_id isnt withdraw_asset_id
                if amount_remaining > balance_amount
                    withdraw = new Withdraw(
                        Address.fromString(balance_id).toBuffer()
                        balance_amount
                    )
                    @operations.push new Operation withdraw.type_id, withdraw
                    @required_signatures[public_key] = on
                    amount_remaining -= balance_amount
                    balance_record[1].balance -= balance_amount
                else
                    withdraw = new Withdraw(
                        Address.fromString(balance_id).toBuffer()
                        amount_remaining
                    )
                    @operations.push new Operation withdraw.type_id, withdraw
                    @required_signatures[public_key] = on
                    amount_remaining = 0
                    balance_record[1].balance = 0
                    break
            break if amount_remaining is 0
        
        if amount_remaining isnt 0
            available = amount_to_withdraw.amount - amount_remaining
            throw new LE 'jslib_wallet.insufficient_funds', amount_to_withdraw.amount, available
    
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
    
    ###* @return key_records:[key_records],blance_records:[blance_records] ###
    get_account_balance_records:(account_name, extended = false)->
        throw new Error 'account_name is required' unless account_name
        my_keys = @wallet.get_my_key_records account_name
        defer = q.defer()
        if my_keys.length is 0
            defer.resolve {}
            return defer.promise

        public_key_params = []
        public_key_params.push [key.public_key] for key in my_keys
        try
            ((public_key_params)=>
                @rpc.request("batch", ["blockchain_list_key_balances", public_key_params]).then(
                    (batch_result)->
                        batch_result = batch_result.result
                        balance_records = {}
                        for i in [0...batch_result.length] by 1
                            balances = batch_result[i]
                            continue if balances.length is 0
                            public_key = public_key_params[i]
                            balances_for_key = balance_records[public_key] = []
                            for balance in balances
                                if balance[1].condition.type is "withdraw_signature_type"
                                    balances_for_key.push balance
                        defer.resolve balance_records
                        return
                    (error)->
                        defer.reject error
                )
            )(public_key_params)
        catch error
            defer.reject error
        defer.promise
    
    ###* @return {promise} ###
    finalize:()->
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
        
        # resolve balance records first or else the same 
        # balance record could end up over-spent
        key_balances= =>
            who_owes= =>
                account_names = {}
                for key in Object.keys @outstanding_balances
                    rec = @outstanding_balances[key]
                    continue if rec.amount > 0
                    address = key.split('\t')[0]
                    account = @wallet.get_account_for_address address
                    unless account
                        throw new Error "Missing account for address #{address}"
                    account_names[account.name]=on
                Object.keys account_names
            key_balances = {}
            q.all(
                for account_name in who_owes()
                    @get_account_balance_records(account_name).then (balances)=>
                        key_balances[account_name] = balances
            ).then ->
                key_balances
        
        key_balances().then (key_balances)=>
            for key in Object.keys @outstanding_balances
                address = key.split('\t')[0]
                #account_rec = asset_id: amount.asset_id, amount: amount
                rec = @outstanding_balances[key]
                continue if rec.amount is 0
                balance = {amount:rec.amount, asset_id: rec.asset_id}
                account = @wallet.get_account_for_address address
                unless account
                    throw new Error "Missing account for address #{address}"
                
                if rec.amount > 0
                    depositAddress = PublicKey.fromBtsPublic(
                        account.active_key
                    ).toBlockchainAddress() #@order_key_for_account...
                    @deposit depositAddress, balance
                else
                    balance.amount = -rec.amount
                    @withdraw_to_transaction balance, account.name, key_balances[account.name]
            
            for k in Object.keys @outstanding_balances
                delete @outstanding_balances[k]
            
            return
    
    _transaction:->
        new Transaction(
            expiration = @expiration
            @slate_id
            @operations
        )
    
    sign_transaction:() ->
        unless @transaction_record.trx
            throw new Error 'call finalize first'
        
        if @signatures.length isnt 0
            throw new Error 'already signed'
        
        chain_id_buffer = new Buffer config.chain_id, 'hex'
        @binary_transaction = @_transaction()
        trx_buffer = @binary_transaction.toBuffer()
        trx_sign = Buffer.concat([trx_buffer, chain_id_buffer])
        #console.log 'digest',hash.sha256(trx_sign).toString('hex')
        for public_key in Object.keys @required_signatures
            try
                private_key = @wallet.getPrivateKey public_key
                #console.log '... sign by', private_key.toPublicKey().toBtsPublic()
                @signatures.push(
                    Signature.signBuffer trx_sign, private_key
                )
            catch error
                console.log "WARNING unable to sign for address #{private_key.toPublicKey().toBtsPublic()}", error
        
        @signed_transaction = new SignedTransaction(
            @binary_transaction, @signatures
        )
    
    # manually tweak an account's balance in this transaction
    _deduct_balance:(public_key, amount)->
        unless public_key
            throw new Error "missing public key"
        unless amount.amount >= 0
            throw new Error "amount #{amount.amount} must be positive"
        
        @required_signatures[public_key] = on
        record = @outstanding_balances[public_key + "\t" + amount.asset_id]
        unless record
            @outstanding_balances[public_key + "\t" + amount.asset_id] = record =
                address:public_key
                asset_id: amount.asset_id
                amount: 0
        record.amount -= amount.amount
        return
        
    # manually tweak an account's balance in this transaction
    _credit_balance:(public_key, amount)->
        unless public_key
            throw new Error "missing public key"
        unless amount.amount >= 0
            throw new Error "amount #{amount.amount} must be positive"
        record = @outstanding_balances[public_key + "\t" + amount.asset_id]
        unless record
            @outstanding_balances[public_key + "\t" + amount.asset_id] = record =
                address:public_key
                asset_id: amount.asset_id
                amount: 0
        record.amount += amount.amount
        return

exports.TransactionBuilder = TransactionBuilder
