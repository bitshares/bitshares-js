aes = require '../ecc/aes'
hash = require '../ecc/hash'

{PrivateKey} = require '../ecc/key_private'
{PublicKey} = require '../ecc/key_public'
LE = require('../common/exceptions').LocalizedException

###* Public ###
class Wallet

    constructor: (@wallet_db) ->

    Wallet.fromWalletDb = (wallet_db) ->
        new Wallet wallet_db
        
    toJson: (indent_spaces=undefined) ->
        JSON.stringify(@wallet_db.wallet_object, undefined, indent_spaces)
        
    unlock: (aes) ->
        throw "Provide an ecc/aes object to unlock" unless aes
        
        @wallet_db.aes_root = aes
        
    lock: ->
        @wallet_db.aes_root = undefined
        
    unlocked: ->
        throw 'Wallet is locked' unless @wallet_db.aes_root
        
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