{WalletDb} = require './wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
{ChainInterface} = require '../blockchain/chain_interface'
{ChainDatabase} = require '../blockchain/chain_database'
{BlockchainAPI} = require '../blockchain/blockchain_api'
{ExtendedAddress} = require '../ecc/extended_address'
{PrivateKey} = require '../ecc/key_private'
{PublicKey} = require '../ecc/key_public'
{Aes} = require '../ecc/aes'

#{Transaction} = require '../blockchain/transaction'
#{RegisterAccount} = require '../blockchain/register_account'
#{Withdraw} = require '../blockchain/withdraw'

LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
config = require './config'
hash = require '../ecc/hash'
secureRandom = require 'secure-random'
q = require 'q'

###* Public ###
class Wallet

    constructor: (@wallet_db, @rpc, chain_id) ->
        throw new Error "required wallet_db" unless @wallet_db
        throw new Error "required chain_id" unless chain_id
        @transaction_ledger = new TransactionLedger()
        @blockchain_api = new BlockchainAPI @rpc
        @chain_interface = new ChainInterface @blockchain_api, chain_id
        @chain_database = new ChainDatabase @wallet_db, @rpc, chain_id
    
    Wallet.entropy = null
    Wallet.add_entropy = (data) ->
        unless data and data.length >= 1000
            throw 'Provide at least 1000 bytes of data'
        
        data = new Buffer(data)
        data = Buffer.concat [Wallet.entropy, data] if Wallet.entropy
        Wallet.entropy = hash.sha512 data
        return
        
    Wallet.has_secure_random = ->
        try
            secureRandom.randomBuffer 10
            true
        catch
            false
    
    Wallet.get_secure_random = ->
        throw 'Call add_entropy first' unless Wallet.entropy
        rnd = secureRandom.randomBuffer 512/8
        #console.log 'Wallet.get_secure_random length',(Buffer.concat [rnd, Wallet.entropy]).length
        hash.sha512 Buffer.concat [rnd, Wallet.entropy]
    
    ###* Unless brain_key is used, must add_entropy first ### 
    Wallet.create = (wallet_name, password, brain_key, save = true)->
        wallet_name = wallet_name?.trim()
        unless wallet_name and wallet_name.length > 0
            LE.throw "wallet.invalid_name"
        
        if not password or password.length < config.BTS_WALLET_MIN_PASSWORD_LENGTH
            LE.throw "wallet.password_too_short"
        
        if brain_key and brain_key.length < config.BTS_WALLET_MIN_BRAINKEY_LENGTH
            LE.throw "wallet.brain_key_too_short"
        
        #@blockchain.is_valid_account_name wallet_name
        
        data = if brain_key
            base = hash.sha512 brain_key
            for i in [0...100*1000] by 1
                # strengthen the key a bit
                base = hash.sha512 base
            base
        else
            # generate random
            Wallet.get_secure_random()
        
        epk = ExtendedAddress.fromSha512_zeroChainCode data
        wallet_db = WalletDb.create wallet_name, epk, password, save
        if brain_key
            aes_root = Aes.fromSecret password
            wallet_db.save_brainkey aes_root, brain_key, save
        
        ###
        set_version( BTS_WALLET_VERSION );
        set_transaction_fee( asset( BTS_WALLET_DEFAULT_TRANSACTION_FEE ) );
        set_transaction_expiration( BTS_WALLET_DEFAULT_TRANSACTION_EXPIRATION_SEC );
        ###
        wallet_db.save() if save
        wallet_db
    
    lock: ->
        EC.throw "Wallet is already locked" unless @aes_root
        try
            @chain_database.poll_transactions shutdown=true if @rpc
            @chain_database.poll_accounts null, shutdown=true if @rpc
        finally #let nothing stop the lock
            @aes_root.clear()
            @aes_root = undefined
    
    locked: ->
        @aes_root is undefined
            
    toJson: (indent_spaces=undefined) ->
        JSON.stringify(@wallet_db.wallet_object, undefined, indent_spaces)
    
    unlock: (timeout_seconds = 1700, password)->
        unless @wallet_db.validate_password password
            LE.throw 'wallet.invalid_password'
        @aes_root = Aes.fromSecret password
        unlock_timeout_id = setTimeout ()=>
            @lock()
        ,
            timeout_seconds * 1000
        
        @chain_database.poll_transactions shutdown=false if @rpc
        @chain_database.poll_accounts @aes_root, shutdown=false if @rpc
        unlock_timeout_id
    
    validate_password: (password)->
        @wallet_db.validate_password password
    
    master_private_key:->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        @wallet_db.master_private_key @aes_root
    
    get_setting: (key) ->
        @wallet_db.get_setting key 
        
    set_setting: (key, value) ->
        @wallet_db.set_setting key, value
        
    get_trx_expiration:->
        @wallet_db.get_trx_expiration()
    
    list_accounts:(just_mine=false)->
        accounts = @wallet_db.list_accounts just_mine
        accounts.sort (a, b)->
            if a.name < b.name then -1
            else if a.name > b.name then 1
            else 0
        accounts
    
    get_local_account:(name)->
        @wallet_db.lookup_account name
    
    is_my_account:(public_key)->
        @wallet_db.is_my_account public_key
    
    ###*
        Get an account, try to sync with blockchain account 
        cache in wallet_db.
    ###
    get_chain_account:(name, refresh = false)-> # was lookup_account
        unless refresh
            local_account = @wallet_db.lookup_account name
            if local_account
                defer = q.defer()
                defer.resolve local_account
                return defer.promise
        
        @blockchain_api.get_account(name).then (chain_account)=>
            local_account = @wallet_db.lookup_account name
            unless local_account or chain_account
                LE.throw "general.unknown_account", [name]
            
            if local_account and chain_account
                if local_account.owner_key isnt chain_account.owner_key
                    LE.throw "wallet.conflicting_accounts", [name]
            
            if chain_account
                @wallet_db.store_account_or_update chain_account
                local_account = @wallet_db.lookup_account name
            
            local_account
    
    ###* @return promise: {string} public key ###
    account_create:(account_name, private_data)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        defer = q.defer()
        @chain_interface.valid_unique_account(account_name).then(
            ()=>
                #cnt = @wallet_db.list_my_accounts()
                account = @wallet_db.lookup_account account_name
                if account
                    e = new LE 'wallet.account_already_exists',[account_name]
                    defer.reject e
                    return
                
                key = @wallet_db.generate_new_account @aes_root, account_name, private_data
                defer.resolve key
            (error)->
                defer.reject error
        ).done()
        defer.promise
    
    ### @return {promise} [
        [
            account_name,[ [asset_id,amount] ]
        ]
    ] ###
    #get_spendable_account_balances:(account_name)->
        
    
    getWithdrawConditions:(account_name)->
        @wallet_db.getWithdrawConditions account_name
    
    getNewPrivateKey:(account_name, expiration_seconds_epoch)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        private_key = @wallet_db.getActivePrivate @aes_root, account_name
        LE.throw 'wallet.account_not_found',[account_name] unless private_key
        unless expiration_seconds_epoch > 1423765682
            throw new Error "Invalid expiration_seconds_epoch #{expiration_seconds_epoch}"
        
        ExtendedAddress.create_one_time_key private_key, expiration_seconds_epoch
        # seq key generation deprecated
        # @wallet_db.generate_new_account_child_key @aes_root, account_name, save
    
    ###
    wallet_transfer:(
        amount, asset, 
        paying_name, from_name, to_name
        memo_message = "", vote_method = ""
    )->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        defer = q.defer()
        to_public = @wallet_db.getActiveKey to_name
        #console.log to_name,to_public?.toBtsPublic()
        @rpc.request("blockchain_get_account",[to_name]).then(
            (result)=>
                unless result or to_public
                    error = new LE 'blockchain.unknown_account', [to_name]
                    defer.reject error
                    return
                
                recipient = @wallet_db.get_account to_name if result
                    @wallet_db.index_account result # cache
                    to_public = @wallet_db.getActiveKey to_name
                
                builder = @transaction_builder()
                
            (error)->
                defer.reject error
        ).done()
        defer.promise
    

    ###
    
    save_transaction:(record)->
        @wallet_db.add_transaction_record record
        return
    
    
    account_transaction_history:(
        account_name=""
        asset_id=-1
        limit=0
        start_block_num=0
        end_block_num=-1
        transactions
    )->
        @chain_database.account_transaction_history(
            account_name
            asset_id
            limit
            start_block_num
            end_block_num
        )
    
    valid_unique_account:(account_name) ->
        @chain_interface.valid_unique_account account_name
    
    dump_private_key:(account_name)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        account = @wallet_db.lookup_account account_name
        return null unless account
        rec = @wallet_db.get_key_record account.owner_key
        return null unless rec
        @aes_root.decryptHex rec.encrypted_private_key
    
    #get_new_private_key:(account_name, save) ->
    #    @generate_new_account_child_key @aes_root, account_name, save
    #    
    #get_new_public_key:(account_name) ->
    #    @get_new_private_key(account_name).toPublicKey()
    
    get_my_key_records:(owner_key) ->
        @wallet_db.get_my_key_records owner_key
    
    getOwnerKey: (account_name)->
        account = @wallet_db.lookup_account account_name
        return null unless account
        PublicKey.fromBtsPublic account.owner_key
    
    getOwnerPrivate: (aes_root, account_name)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        account = @wallet_db.lookup_account account_name
        return null unless account
        account.owner_key
        @getPrivateKey account.owner_key
    
    lookup_active_key:(account_name)->
        @wallet_db.lookup_active_key account_name
    
    get_account_for_address:(address)->
        @wallet_db.get_account_for_address address
    
    keyrec_to_private:(key_record)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        return null unless key_record?.encrypted_private_key
        PrivateKey.fromHex @aes_root.decryptHex key_record.encrypted_private_key
        
    #lookup_private:(bts_public_key)->@getPrivateKey bts_public_key
    getPrivateKey:(bts_public_key)->
        @keyrec_to_private @wallet_db.get_key_record bts_public_key
    
    lookupPrivateKey:(address)->
        @keyrec_to_private @wallet_db.lookup_key address
    
    #getNewPublicKey:(account_name)->
    
    ###* @return {PublicKey} ###
    getActiveKey: (account_name) ->
        active_key = @wallet_db.lookup_active_key account_name
        return null unless active_key
        PublicKey.fromBtsPublic active_key
        
    ###* @return {PrivateKey} ###
    getActivePrivate: (account_name) ->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        @wallet_db.getActivePrivate @aes_root, account_name
    
exports.Wallet = Wallet