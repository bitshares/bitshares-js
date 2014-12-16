hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException

class WalletDb
    
    localStorage = window?.localStorage ||
        # NodeJs development and testing (WARNING: get and set are not atomic)
        # https://github.com/lmaccherone/node-localstorage/issues/6
        new (require('node-localstorage').LocalStorage)('./localstorage-bitshares-js')
            
    constructor: (@wallet_object, @wallet_name = "default") ->
        throw "Wallet object is required" unless @wallet_object # programmer error
        invalid = -> LE.throw "wallet.invalid_format", [@wallet_name]
        invalid() unless @wallet_object?.length > 0
        throwLE "wallet.missing_local_storage" unless localStorage
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    @master_key_encrypted = data.encrypted_key
                    @master_pw_checksum = data.checksum
                    break
        invalid() unless @master_key_encrypted
    
    ###* @return {WalletDb} or null ###
    WalletDb.open = (wallet_name = "default") ->
        wallet_string = localStorage.getItem("wallet-" + wallet_name)
        #if wallet_string then console.log 'wallet opened' else 'no wallet'
        return null unless wallet_string
        wallet_object = JSON.parse wallet_string
        new WalletDb(wallet_object, wallet_name)
        
    WalletDb.delete = (wallet_name)->
        localStorage.removeItem "wallet-" + wallet_name
        return
    
    ###* @throws {QuotaExceededError} ###
    save: ->
        wallet_string = JSON.stringify @wallet_object, null, 0
        localStorage.setItem("wallet-" + @wallet_name, wallet_string)
        return
    
    key_record: (public_key) ->
        bts_address = public_key.toBtsPublic()
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "key_record_type"
                    return data if data.public_key is bts_address
        return
    
    ###* @throws {key:'wallet.invalid_password'} ###
    validate_password: (password)->
        checksum = hash.sha512 password
        checksum = hash.sha512 checksum
        LE.throw 'wallet.invalid_password' unless @master_pw_checksum is checksum.toString 'hex'
        
    ###
    _find: ->
        
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
                    
        throw "Invalid wallet format" unless @master_key_encrypted
    ###
exports.WalletDb = WalletDb