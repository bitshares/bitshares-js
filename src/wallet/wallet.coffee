aes = require '../ecc/aes'
hash = require '../ecc/hash'

{PrivateKey} = require '../ecc/key_private'
{PublicKey} = require '../ecc/key_public'
{Aes} = require '../ecc/aes'
LE = require('../common/exceptions').LocalizedException

###* Public ###
class Wallet

    constructor: (@wallet_db) ->
        throw 'wallet_db is required' unless @wallet_db
        throw 'wallet_db type is required' unless @wallet_db.wallet_object

    Wallet.fromWalletDb = (wallet_db) ->
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
        
    Wallet.backup_restore_object = (json_object, wallet_name) ->
        Db.backup_restore_object json_object, wallet_name

    
exports.Wallet = Wallet