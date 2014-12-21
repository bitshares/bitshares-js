aes = require '../ecc/aes'
hash = require '../ecc/hash'

{WalletDb} = require './wallet_db'
{ExtendedAddress} = require '../ecc/extended_address'
{PrivateKey} = require '../ecc/key_private'
{PublicKey} = require '../ecc/key_public'
{Aes} = require '../ecc/aes'
LE = require('../common/exceptions').LocalizedException
config = require './config'
hash = require '../ecc/hash'
secureRandom = require 'secure-random'

###* Public ###
class Wallet

    constructor: (@wallet_db) ->
        throw 'wallet_db is required' unless @wallet_db
        throw 'wallet_db type is required' unless @wallet_db.wallet_object
    
    Wallet.fromWalletDb = (wallet_db) ->
        new Wallet wallet_db
    
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
        new Wallet wallet_db
        
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
    
    lock: ->
        @aes_root = undefined
        
    locked: ->
        @aes_root is undefined
        
    getActiveKey: (account_name) ->
        active_key = @wallet_db.account_activeKey[account_name]
        throw "Account #{account_name} not found" unless active_key
        PublicKey.fromBtsPublic active_key
    
    getActiveKeyPrivate: (account_name) ->
        @unlocked()
        active_key = @getActiveKey account_name
        key_record = @wallet_db.keyRecord(active_key)
        PrivateKey.fromHex(@wallet_db.aes_root.decryptHex(key_record.encrypted_private_key))
        
    backup_restore_object: (json_object, wallet_name) ->
        Db.backup_restore_object json_object, wallet_name

    
exports.Wallet = Wallet