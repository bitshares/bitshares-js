assert = require 'assert'
aes = require '../ecc/aes'
hash = require '../ecc/hash'

ecc = require '../ecc'
#Aes = ecc.Aes
#Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
#PublicKey = ecc.PublicKey
#Address = ecc.Address

###* Public ###
class Wallet

    constructor: (wallet_object) ->
        @db = new Db(wallet_object)

    Wallet.fromObject = (wallet_object) ->
        new Wallet(wallet_object)
        
    toJson: (indent_spaces=undefined) ->
        JSON.stringify(@db.wallet_object, undefined, indent_spaces)
        
    unlock: (aes) ->
        throw "Provide an ecc/aes object to unlock" unless aes
        @db.aes_root = aes
        
    lock: ->
        @db.aes_root = undefined
        
    unlocked: ->
        throw 'Wallet is locked' unless @db.aes_root
        
    getActiveKey: (account_name) ->
        active_key = @db.account_activeKey[account_name]
        throw "Account #{account_name} not found" unless active_key
        active_key
    
    getActiveKeyPrivate: (account_name) ->
        @unlocked()
        active_key = @getActiveKey account_name
        key_record = @db.keyRecord(active_key)
        PrivateKey.fromHex(@db.aes_root.decryptHex(key_record.encrypted_private_key))
    
###* Private ###
class Db
    
    constructor: (@wallet_object) ->
        assert @wallet_object, "Invalid wallet format"
        assert @wallet_object.length , "Invalid wallet format"
        assert @wallet_object.length > 0, "Invalid wallet format"
        
        @account={} # [ string account name ] = object account_record_type
        
        @account_activeKey={} # [ string account name ] = string most recent active key
        @activeKey_account={} # [ string all active keys ] = string account name 
        
        @master_key_encrypted
        @master_pw_checksum
        
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    @master_key_encrypted = data.encrypted_key
                    @master_pw_checksum = data.checksum
                when "account_record_type"
                    account_name = data.name
                    @account[account_name] = data
                    max_key_datestr = "0"
                    for keyrec in data.active_key_history
                        datestr = keyrec[0]
                        key = keyrec[1]
                        @activeKey_account[key] = account_name
                        if datestr > max_key_datestr
                            # most recent active key
                            @account_activeKey[account_name] = key
                            max_key_datestr = datestr
                when "key_record_type"
                    address = data.account_address
                    public_key = data.public_key
                    
        assert @master_key_encrypted, 'Invalid wallet format'
    
    keyRecord: (public_key) ->
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "key_record_type"
                    return data if data.public_key is public_key
        throw "Not found"
                        
    
    
module.exports = Wallet