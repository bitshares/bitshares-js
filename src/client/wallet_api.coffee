{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
{TransactionBuilder} = require '../wallet/transaction_builder'
{Aes} = require '../ecc/aes'
{ExtendedAddress} = require '../ecc/extended_address'
{ChainInterface} = require '../blockchain/chain_interface'
{ChainDatabase} = require '../blockchain/chain_database'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{Short} = require '../blockchain/short'
{PublicKey} = require '../ecc/key_public'
{Util} = require '../blockchain/market_util'
wallet_config = require '../wallet/config'
config = require '../config'

Long = (require 'bytebuffer').Long
LE = require('../common/exceptions').LocalizedException
secureRandom = require 'secure-random'
hash = require '../ecc/hash'
q = require 'q'

# merge from bitshares/libraries/api/wallet_api.json
libraries_api_wallet = require '../wallet/wallet_api.json'

###*
    Mimics bitshares_client RPC calls as close as possible. 
    Any functions matching an RPC method will be automatically
    matched and called in place of the native RPC call.
###
class WalletAPI
    
    constructor:(@rpc, @rpc_pass_through, @relay, @events)->
        if @rpc and not @rpc.request
            throw new Error 'expecting rpc object'
        
        @blockchain_api = new BlockchainAPI @rpc
        @chain_interface = new ChainInterface @blockchain_api, @relay.chain_id
        @login_guest()
    
    login_guest:->
        if config.guest_wallet
            WalletDb.delete "Guest"
        else
            if WalletDb.exists "Guest"
                @open "Guest"
                @unlock 9999999, "guestpass", guest = yes
                return
        
        rnd = if config.guest_wallet
            h = hash.sha256 config.guest_wallet
            delete config.guest_wallet
            h
        else
            secureRandom.randomBuffer 32
        
        epk = ExtendedAddress.fromSha512_zeroChainCode hash.sha512 rnd
        @_open_from_wallet_db WalletDb.create(
            "Guest", epk, rnd.toString('hex').substring 0, 10
            "guestpass", _save=false
            @events
        )
        @current_wallet_name = "Guest"
        @unlock 9999999, "guestpass", guest=yes
        @wallet.wallet_db.fake_account @wallet.aes_root, rnd
        @wallet.wallet_db.save()
        return
    
    WalletAPI.libraries_api_wallet = libraries_api_wallet
    
    ###* open from persistent storage ###
    open: (wallet_name = "default")->
        if @current_wallet_name is wallet_name
            return
        
        wallet_db = WalletDb.open wallet_name, @events
        unless wallet_db
            throw new LE 'jslib_wallet.not_found', [wallet_name]
        
        @_open_from_wallet_db wallet_db
        @current_wallet_name = wallet_name
        return
    
    _open_from_wallet_db:(wallet_db)->
        @transaction_ledger = new TransactionLedger()
        @chain_database = new ChainDatabase wallet_db, @rpc, @relay.chain_id, @relay.relay_fee_collector
        @wallet = new Wallet wallet_db, @rpc, @relay, @chain_database, @events
        return
    
    create: (wallet_name = "default", new_password, brain_key)->
        brain_key = undefined if brain_key is ""
        Wallet.create wallet_name, new_password, brain_key, true, @events
        @open wallet_name
        @unlock wallet_config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC, new_password
        # Find accounts created prior to March 14
        @chain_database.sync_accounts(
            @wallet.aes_root, 2, algorithm = 'online_wallet_2015_03_14'
        )
        return
    
    close:->
        @wallet = null
        return
    
    validate_password: (password)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        unless @wallet.validate_password password
            LE.throw 'jslib_wallet.invalid_password'
        return
    
    unlock:(
        timeout_seconds = wallet_config.BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC
        password
        guest=no
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.unlock timeout_seconds, password, guest
        return
    
    lock:->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.lock()
        @login_guest()
        return
        
    locked: ->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.locked()
    
    #account_set_favorite:(name, )->
    
    backup_create:()->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        if window
            window.document.location = (
                'data:Application/octet-stream,' +
                encodeURIComponent(
                    JSON.stringify @wallet.wallet_db.wallet_object,null,4
                )
            )
        else
            throw 'not implemented'
        
        return "OK"
    
    get_brainkey:->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        LE.throw 'jslib_wallet.must_be_unlocked' unless @wallet.aes_root
        @wallet.wallet_db.get_brainkey @wallet.aes_root, normalize = no
    
    ###* @return promise: {string} public key ###
    account_create:(account_name, private_data)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.account_create account_name, private_data
    
    ###* @return promise: {string} public key ###
    account_recover:(account_name)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.account_recover account_name
    
    _transaction_builder:()->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        LE.throw 'jslib_wallet.must_be_unlocked' unless @wallet.aes_root
        new TransactionBuilder(
            @wallet, @rpc, @wallet.aes_root
        )
    
    transfer:( 
        amount, asset_name_or_id, 
        from_name, to_name
        memo_message = "", selection_method = ""
    )->
        @transfer_from(
            amount, asset_name_or_id, 
            from_name, from_name, to_name
            memo_message, selection_method
        )
    
    transfer_from:(
        amount_to_transfer, asset_name_or_id, 
        paying_account_name, from_account_name, to_account_name_or_key
        memo_message = "", selection_method = ""
        fee_asset_name_or_id
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        asset = @chain_interface.get_asset asset_name_or_id
        payer = @wallet.get_chain_account paying_account_name
        sender = if paying_account_name is from_account_name
            payer
        else
            @wallet.get_chain_account from_account_name
        
        recipient = try
                PublicKey.fromBtsPublic to_account_name_or_key
                defer = q.defer()
                defer.resolve to_account_name_or_key
                defer.promise
            catch
                @wallet.get_chain_account to_account_name_or_key
        
        unless fee_asset_name_or_id
            fee_asset_name_or_id = asset_name_or_id
        
        q.all([
            asset, payer, sender, recipient
        ]).spread (
            asset, payer, sender, recipient
        )=>
            unless asset
                error = new LE 'jslib_blockchain.unknown_asset', [asset]
                defer.reject error
                return
            
            amount = Util.to_ugly_asset amount_to_transfer, asset
            builder = @_transaction_builder()
            builder.deposit_asset(
                payer, recipient, amount
                memo_message, selection_method, sender.active_key
                use_stealth_address = no#!recipient.meta_data?.type is "public_account"
            )
            @_finalize_and_send(builder, payer, fee_asset_name_or_id).then (record)->
                record
    
    transfer_to_address:(
        amount
        asset_symbol
        from
        to_address
        memo_message = ""
        vote_method = ""#vote_recommended"
    )->
        @transfer_from(
            amount
            asset_symbol
            from
            from
            to_address
            memo_message
            vote_method
        )
    
    account_register:(
        account_name
        pay_with_account
        public_data = null
        delegate_pay_rate = -1
        account_type = 'public_account'
        fee_asset_name_or_id = 0
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        account_check = @chain_interface.valid_unique_account account_name
        payer = @wallet.get_chain_account pay_with_account
        q.all([account_check, payer]).spread (account_check, payer)=>
            
            builder = @_transaction_builder()
            builder.account_register(
                account_name
                pay_with_account
                public_data
                delegate_pay_rate
                account_type
            )
            @_finalize_and_send(builder, payer, fee_asset_name_or_id).then (record)->
                record
    
    #account_retract:(account_to_update, pay_from_account)->
    #   record = @wallet.retract_account( account_to_update, pay_from_account, true );
    #   @wallet.cache_transaction( record );
    #   @network_broadcast_transaction( record.trx );
    #   record
        
    broadcast_transaction:(defer, signed_trx)->
        #console.log 'signed_trx',JSON.stringify signed_trx,null,2
        @rpc.request("blockchain_broadcast_transaction", [signed_trx]).then(
            (result)->
                # returns void
                defer.resolve signed_trx
            (error)->
                defer.reject error
        ).done()
    
    ###*
        Save a new wallet and return a WalletDb object.  Resolves as an error 
        if wallet exists or is unable to save in local storage.
    ###
    backup_restore_object:(wallet_object, wallet_name)->
        if WalletDb.open wallet_name, @events
            LE.throw 'jslib_wallet.exists', [wallet_name]
        
        try
            wallet_db = new WalletDb wallet_object, wallet_name, @events
            wallet_db.save()
            return wallet_db
        catch error
            LE.throw 'jslib_wallet.save_error', [wallet_name, error], error
            
    get_info:->
        @get_transaction_fee().then (fee)=>
            open: if @wallet then true else false
            unlocked: not @wallet?.locked() #if @wallet then not @wallet.locked() else null
            name: @wallet.wallet_db?.wallet_name
            transaction_fee:fee
            transaction_scanning:true
            scan_progress: "100.00 %"
    
    # general get_info has wallet attributes in it
    general_get_info:->
        @rpc_pass_through.request('get_info').then (info)=>
            info = info.result
            for key in Object.keys info
                if key.match /^wallet_/
                    delete info[key]
            info['wallet_open'] = if @wallet then true else false
            info['wallet_unlocked'] = not @wallet?.locked()
            
            info
            #info['wallet_unlocked_until']="xx hours in the future"
            #info['wallet_unlocked_until_timestamp']=(
            #    if not @wallet?.locked()
            #        @wallet.unlocked_until().toISOString().split('.')[0]
            #)
    
    get_transaction_fee:(asset_name_or_id = 0)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @relay.init().then =>
            q.all([
                @chain_interface.convert_base_asset_amount(
                    asset_name_or_id
                    @relay.network_fee_amount +
                    @relay.relay_fee_amount
                )
            ]).spread (total_fee)=>
                asset_id: total_fee.asset_id
                amount: total_fee.amount
    
    set_transaction_fee:(fee_amount)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        q.all([
            @chain_interface.get_asset(0)
            @get_transaction_fee(0)
        ]).spread (base_asset, fee)->
            if fee.amount isnt fee_amount * base_asset.precision
                throw new Error "Rejected attempt to change fee, this is set by your light-weight API provider"
    
    get_setting:(key)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        value = @wallet.get_setting key
        return key: key, value: value
        
    set_setting:(key, value)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.set_setting key, value
        
    get_account:(name)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.get_chain_account name, refresh=true
    
    list_accounts:->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.list_accounts()
    
    account_yield_warned:off
    account_yield:->
        unless @account_yield_warned
            console.log 'WARN: account_yield is not implemented'
            @account_yield_warned = on
        []
    
    dump_private_key:()->
        LE.throw "Instead use: wallet_dump_account_private_key"
    
    dump_account_private_key:(account_name, key_type)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.dump_account_private_key account_name, key_type
     
    ###* @return {promise} ###
    account_balance:(account_name, extended = false)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        totals_by_account={}
        total=(account_name, asset_id, balance)->
            totals = totals_by_account[account_name]
            unless totals
                totals = {}
                totals_by_account[account_name] = totals
            
            amount = totals[asset_id]
            amount = Long.ZERO unless amount
            totals[asset_id] = amount.add balance
        
        by_account=(account_name)=>
            defer = q.defer()
            builder = @_transaction_builder()
            builder.get_account_balance_records(account_name, extended).then (key_records)->
                if (Object.keys key_records).length is 0
                    defer.resolve()
                    return
                for public_key in Object.keys key_records
                    for record in key_records[public_key]
                        continue if record.length is 0
                        rec = record[1]
                        asset_id = rec.condition.asset_id
                        total account_name, asset_id, if extended
                            builder.get_extended_balance rec
                        else
                            rec.balance
                defer.resolve()
            ,(error)->
                defer.reject error
            .done()
            defer.promise
        
        account_name = null if account_name is ""
        p=[]
        if account_name
            p.push by_account account_name
        else
            for account in @wallet.list_accounts just_mine=true
                p.push by_account account.name
        
        defer = q.defer()
        q.all(p).then (records)->
            account_balances = []
            for account_name in Object.keys totals_by_account
                totals = totals_by_account[account_name]
                balences = []
                for asset_id in Object.keys totals
                    balance = totals[asset_id]
                    balences.push [asset_id, balance]
                account_balances.push [
                    account_name
                    balences
                ]
            
            defer.resolve account_balances.sort (a,b)->
                if a[0] < b[0] then -1 else if a[0] > b[0] then 1 else 0
        
        defer.promise
    
    #wallet_account_yield
    
    #batch wallet_check_vote_proportion
    ###* @return promise [transaction] ###
    account_pending_transactions:(account_name)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @wallet.account_pending_transactions account_name
    
    ###* @return promise [transaction] ###
    account_transaction_history:(
        account_name=""
        asset=""
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        asset_id = if asset.match /^[0-9]$/
            parseInt asset
        else
            if asset is ""
                -1
        
        if asset_id
            return @wallet.account_transaction_history(
                account_name
                asset_id
                limit
                start_block_num
                end_block_num
            )
        
        @chain_interface.get_asset(asset_symbol).then (asset_lookup)=>
            LE.throw "jslib_blockchain.unknown_asset",[asset] unless asset_lookup
            asset_id = asset_lookup.id
            @wallet.account_transaction_history(
                account_name
                asset_id
                limit
                start_block_num
                end_block_num
            )
    
    ### Example to create USD from XTS at a penney a share:
        wallet_market_submit_ask delegate0 100 XTS 0.01 USD
        
        ask(0d)hexmap: "            TyLeAmount                      Order price             Owner                                   ..."
    ###
    market_submit_ask:(
        from_account_name
        sell_quantity_string
        sell_quantity_symbol
        ask_price_string
        ask_price_symbol
        #allow_ask_under_5_percent = false
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @blockchain_api.market_order_book(
            ask_price_symbol
            sell_quantity_symbol
            1
        ).then (highest_bid_price)=>
            #result = result[0]
            #console.log '... highest_bid_price',ask_price_string,JSON.stringify highest_bid_price
            #if( ask_price < highest_bid_price * 0.95 )
            #{
            # FC_THROW_EXCEPTION(stupid_order, "You are attempting to ask at more than 5% below the buy price. "
            # "This ask is based on economically unsound principles, and is ill-advised. "
            # "If you're sure you want to do this, place your ask again and set allow_ask_under_5_percent to true.");
            #}
            q.all([
                @wallet.get_chain_account from_account_name, refresh=false
                @chain_interface.get_asset sell_quantity_symbol
                @chain_interface.get_asset ask_price_symbol
            ]).spread (
                from_account
                sell_asset
                ask_asset
            )=>
                unless sell_asset
                    LE.throw 'jslib_wallet.unknown_asset',[sell_quantity_symbol]
                unless ask_asset
                    LE.throw 'jslib_wallet.unknown_asset',[ask_price_symbol]
                
                builder = @_transaction_builder()
                builder.submit_ask(
                    from_account
                    sell_quantity_string
                    sell_asset
                    ask_price_string
                    ask_asset
                )
                @_finalize_and_send(
                    builder, from_account, sell_quantity_symbol
                ).then (record)->
                    record
    
    market_submit_bid:(
        from_account_name
        quantity_string
        quantity_symbol
        quote_price_string
        quote_price_symbol
        #allow_pay_over_5_percent = false
    )->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @blockchain_api.market_order_book(
            quote_price_symbol
            quantity_symbol
            1
        ).then (highest_pay_price)=>
            #result = result[0]
            #console.log '... highest_pay_price',quote_price_string,JSON.stringify highest_pay_price
            #if( pay_price > highest_pay_price * 1.05 )
            #{
            # FC_THROW_EXCEPTION(stupid_order, "You are attempting to bid at more than 5% above the sell price. "
            # "This bid is based on economically unsound principles, and is ill-advised. "
            # "If you're sure you want to do this, place your bid again and set allow_pay_over_5_percent to true.");
            #}
            q.all([
                @wallet.get_chain_account from_account_name, refresh=false
                @chain_interface.get_asset quantity_symbol
                @chain_interface.get_asset quote_price_symbol
            ]).spread (
                from_account
                quantity_asset
                order_price_asset
            )=>
                unless quantity_asset
                    LE.throw 'jslib_wallet.unknown_asset',[quantity_symbol]
                unless order_price_asset
                    LE.throw 'jslib_wallet.unknown_asset',[quote_price_symbol]
                
                builder = @_transaction_builder()
                builder.submit_bid(
                    from_account
                    quantity_string
                    quantity_asset
                    quote_price_string
                    order_price_asset
                )
                @_finalize_and_send(
                    builder, from_account, quantity_symbol
                ).then (record)->
                    record
        ### Example to create USD from XTS at a penney a share:
        wallet_market_submit_short delegate0 200 XTS 1 USD 0.01
    ###
    market_submit_short:(
        from_account_name
        short_collateral_string # quantity
        collateral_symbol
        interest_rate_string # apr
        quote_symbol
        price_limit_string # price_limit
    )->
        throw new Error "Untested"
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        q.all([
            @wallet.get_chain_account from_account_name, refresh=false
            @chain_interface.get_asset collateral_symbol
            @chain_interface.get_asset quote_symbol
        ]).spread (
            from_account
            collateral_asset
            quote_asset
        )=>
            unless collateral_asset
                LE.throw 'jslib_wallet.unknown_asset',[collateral_symbol]
            unless quote_asset
                LE.throw 'jslib_wallet.unknown_asset',[quote_symbol]
            
            builder = @_transaction_builder()
            builder.submit_short(
                from_account
                short_collateral_string
                collateral_asset
                interest_rate_string
                quote_asset
                price_limit_string
            )
            @_finalize_and_send(
                builder, from_account, collateral_symbol
            ).then (record)->
                record
    
    market_cover:(from_account_name, quantity, quantity_symbol, order_id)->
        throw new Error "Untested"
        ((quantity, order_id, builder)=>
            q.all([
                @chain_interface.get_asset quantity_symbol
                @wallet.get_local_account from_account_name
                @blockchain_api.get_market_order order_id
            ]).spread (
                quantity_asset
                from_account
                order
            )=>
                unless quantity_asset
                    LE.throw 'jslib_blockchain.unknown_asset', [quantity_asset]
                
                quantity_amount = Util.to_ugly_asset quantity, quantity_asset
                builder.submit_cover from_account, quantity_amount, order
                @_finalize_and_send(
                    builder, from_account, quantity_asset.asset_id
                ).then (record)->
                    record
        
        )(quantity, order_id, @_transaction_builder())

    
    market_cancel_order:(order_id)->
        LE.throw "jslib_wallet.must_be_opened" unless @wallet
        @blockchain_api.get_market_order(order_id).then (order)=>
            throw new Error "Can not find market order" unless order
            owner_account = @wallet.get_account_for_address order.market_index.owner
            balance = Util.get_balance_asset order
            builder = @_transaction_builder()
            builder.cancel_order order
            @_finalize_and_send(
                builder, owner_account, balance.asset_id
            ).then (record)->
                record
        
    market_order_list:(base_symbol, quantity_symbol, limit, account_name)->
        active_key = @wallet.lookup_active_key account_name
        return [] unless active_key
        active = PublicKey.fromBtsPublic active_key
        @blockchain_api.list_address_orders(
            base_symbol, quantity_symbol, active.toBtsAddy(), limit
        ).then (result)->
            result
    
    account_order_list:(account_name, limit)->
        @market_order_list "", "", limit, account_name
    
    _finalize_and_send:(builder, payer_account, fee_asset_name_or_id)->
        collector_account_promise = if @relay.relay_fee_collector
            @wallet.get_chain_account( # cache in wallet_db
                @relay.relay_fee_collector.name
            )
        @relay.init().then =>
            q.all([
                @chain_interface.convert_base_asset_amount(
                    fee_asset_name_or_id
                    @relay.network_fee_amount
                )
                @chain_interface.convert_base_asset_amount(
                    fee_asset_name_or_id
                    @relay.relay_fee_amount
                )
                collector_account_promise
            ]).spread (
                network_fee
                light_fee
                collector
            )=>
                builder.pay_network_fee payer_account, network_fee
                #console.log '... collector',JSON.stringify collector
                if(light_fee and light_fee.amount.compare(Long.ZERO)>0)
                    unless collector
                        console.log "WARN: config.json, light_relay_fee specified but relay_account_name is missing"
                        # Pay the network fee so the transaction will submit
                        builder.pay_network_fee payer_account, light_fee
                    else
                        builder.pay_collector_fee payer_account, collector, light_fee
                
                builder.finalize().then ()=>
                    
                    #console.log '... transaction\t'+builder._transaction().toBuffer().toString 'hex'
                    
                    builder.sign_transaction()
                    record = builder.get_transaction_record()
                    
                    console.log '... record.trx', JSON.stringify record,null,2
                    
                    @blockchain_api.broadcast_transaction(record.trx).then =>
                        # https://github.com/BitShares/bitshares/issues/1510
                        #@chain_database.save_pending_transaction record
                        record
                    #,(e)->console.log 'e',e
                    
                    ### For TITAN support:
                    for notice in builder.encrypted_notifications()
                        p.push @mail_client.send_encrypted_message(
                            notice,from_account_name
                            to_account_name
                            recipient.active_key
                        )
                    ###
                    ### cpp
                    notices = builder->encrypted_notifications()
                    for notice in notices
                        mail.send_encrypted_message(
                            notice, sender, receiver, 
                            sender.active_key
                        )
                        # a second copy for one's self
                        mail.send_encrypted_message(
                            notice, sender, sender, 
                            sender.active_key
                        )
                    ###
                    #q.all(p)
    
exports.WalletAPI = WalletAPI
