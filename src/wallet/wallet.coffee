assert = require 'assert'
aes = require '../ecc/aes'
hash = require '../ecc/hash'

class Wallet
    
    constructor: (@wallet_object) ->
        assert @wallet_object, "Invalid wallet format"
        assert @wallet_object.length , "Invalid wallet format"
        assert @wallet_object.length > 0, "Invalid wallet format"
        
        @account={} # [ string account name ] = object account_record_type
        
        @account_active_key={} # [ string account name ] = string most recent active key
        @active_key_account={} # [ string all active keys ] = string account name 
        
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
                        @active_key_account[key] = account_name
                        if datestr > max_key_datestr
                            # most recent active key
                            @account_active_key[account_name] = key
                            max_key_datestr = datestr
                when "key_record_type"
                    address = data.account_address
                    public_key = data.public_key
                    
        assert @master_key_encrypted, 'Invalid wallet format'
    
    Wallet.fromObject = (wallet_object) ->
        new Wallet(wallet_object)
        
    toJson: (indent_spaces=undefined) ->
        JSON.stringify(@wallet_object, undefined, indent_spaces)
        
    
    
module.exports = Wallet