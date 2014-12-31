{WalletDb} = require './wallet_db'
{TransactionLedger} = require '../wallet/transaction_ledger'
{TransactionBuilder} = require '../wallet/transaction_builder'
{ChainInterface} = require '../blockchain/chain_interface'
{ExtendedAddress} = require '../ecc/extended_address'
#{PrivateKey} = require '../ecc/key_private'
#{PublicKey} = require '../ecc/key_public'
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

    constructor: (@wallet_db, @rpc) ->
        throw "required parameter" unless @wallet_db
        @transaction_ledger = new TransactionLedger @wallet_db
        @transaction_builder = new TransactionBuilder @wallet_db, @rpc, @transaction_ledger
        @chain_interface = new ChainInterface @rpc
    
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
    Wallet.create = (wallet_name, password, brain_key)->
        
        wallet_name = wallet_name?.trim()
        unless wallet_name and wallet_name.length > 0
            LE.throw "wallet.invalid_name"
        
        if not password or password.length < config.BTS_WALLET_MIN_PASSWORD_LENGTH
            LE.throw "wallet.password_too_short"
        
        if brain_key and brain_key.length < config.BTS_WALLET_MIN_BRAINKEY_LENGTH
            LE.throw "wallet.brain_key_too_short"
        
        #@blockchain.is_valid_account_name wallet_name
        
        data = if brain_key
            throw 'Brain keys have not been tested with the native client'
            base = hash.sha512 brain_key
            for i in [0..100*1000]
                # strengthen the key a bit
                base = hash.sha512 base
            base
        else
            # generate random
            Wallet.get_secure_random()
        
        epk = ExtendedAddress.fromSha512 data
        wallet_db = WalletDb.create wallet_name, epk, password
        ###
        set_version( BTS_WALLET_VERSION );
        set_transaction_fee( asset( BTS_WALLET_DEFAULT_TRANSACTION_FEE ) );
        set_transaction_expiration( BTS_WALLET_DEFAULT_TRANSACTION_EXPIRATION_SEC );
        ###
        wallet_db.save()
        return
        
    lock: ->
        EC.throw "Wallet is already locked" unless @aes_root
        @aes_root.clear()
        @aes_root = undefined
        
    locked: ->
        @aes_root is undefined
            
    toJson: (indent_spaces=undefined) ->
        JSON.stringify(@wallet_db.wallet_object, undefined, indent_spaces)
    
    unlock: (timeout_seconds = 1700, password)->
        @wallet_db.validate_password password
        @aes_root = Aes.fromSecret password
        unlock_timeout_id = setTimeout ()=>
            @lock()
        ,
            timeout_seconds * 1000
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
        
    get_transaction_fee:->
        @wallet_db.get_transaction_fee()
        
    get_account:(name)->
        @wallet_db.lookup_account name
    
    list_accounts:->
        accounts = @wallet_db.list_accounts()
        accounts.sort (a, b)->
            if a.name < b.name then -1
            else if a.name > b.name then 1
            else 0
        accounts
        
    ###* Get a blockchain account, cache in wallet_db ###
    lookup_account:(name)->
        defer = q.defer()
        @rpc.request("blockchain_get_account", [name]).then(
            (result)->
                @wallet_db.account_update_or_save result
                defer.resolve result
            (error)->
                defer.reject error
        ).done()
        defer.promise()
    
    ###* @return {string} public key ###
    account_create:(account_name, private_data)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        defer = q.defer()
        @chain_interface.valid_unique_account(account_name).then(
            (resolve)=>
                #cnt = @wallet_db.list_my_accounts()
                account = @wallet_db.lookup_account account_name
                if account
                    e = new LE 'wallet.account_already_exists',[account_name]
                    defer.reject e
                    return
                
                key = @wallet_db.generate_new_account @aes_root, account_name, private_data
                defer.resolve key
            (error)=>
                defer.reject error
        ).done()
        defer.promise
        
    get_new_private_key:(account_name)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        @wallet_db.generate_new_account_child_key @aes_root, account_name
        
    wallet_transfer:()->
        
    
    wallet_transfer_to_address:(
        amount
        asset
        from_name
        to_address
        memo_message = ""
        vote_method = ""#vote_recommended"
    )->
        defer = q.defer()
        @transaction_builder.wallet_transfer_to_address(
            amount
            asset
            from_name
            to_address
            memo_message
            vote_method
            @aes_root
        ).then(
            (signed_trx)=>
                console.log 'signed_trx',JSON.stringify signed_trx,null,2
                @rpc.request("blockchain_broadcast_transaction", [signed_trx]).then(
                    (result)->
                        # returns void
                        defer.resolve signed_trx
                    (error)->
                        defer.reject error
                ).done()
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
        @chain_interface.valid_unique_account(account_name).then(
            (resolve)=>
                @transaction_builder.account_register(
                    account_name
                    pay_from_account
                    public_data
                    delegate_pay_rate
                    account_type
                ).then(
                    (signed_trx)=>
                        @rpc.request("blockchain_broadcast_transaction", [signed_trx]).then(
                            (result)->
                                # returns void
                                defer.resolve signed_trx
                            (error)->
                                defer.reject error
                        ).done()
                    (error)->
                        defer.reject error
                ).done()
            (error)->
                defer.reject error
        ).done()
        defer.promise
    
    account_transaction_history:(
        account_name=""
        asset_id=0
        limit=0
        start_block_num=0
        end_block_num=-1
    )->
        account_name = null if account_name is ""
        
        if asset_id is "" then asset_id = 0
        unless /^\d+$/.test asset_id
            throw "asset_id should be a number, instead got: #{asset_id}"
        
        history = @transaction_ledger.get_transaction_history(
            account_name
            start_block_num
            end_block_num
            asset_id
        )
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
        
    valid_unique_account:(account_name) ->
        @chain_interface.valid_unique_account account_name
    
    dump_private_key:(account_name)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        account = @wallet_db.lookup_account account_name
        return null unless account
        rec = @wallet_db.get_key_record account.owner_key
        return null unless rec
        @aes_root.decryptHex rec.encrypted_private_key
        
    ###* @return {PrivateKey} ###
    getOwnerKeyPrivate: (account_name)->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        @wallet_db.getOwnerKeyPrivate @aes_root, account_name
    
    ###* @return {PublicKey} ###
    getActiveKey: (account_name) ->
        @wallet_db.getActiveKey account_name
    
    ###* @return {PrivateKey} ###
    getActivePrivate: (account_name) ->
        LE.throw 'wallet.must_be_unlocked' unless @aes_root
        @wallet_db.getActivePrivate @aes_root, account_name


    
exports.Wallet = Wallet