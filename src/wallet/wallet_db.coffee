hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException
{Aes} = require '../ecc/aes'

class WalletDb
    
    localStorage = window?.localStorage ||
        # NodeJs development and testing (WARNING: get and set are not atomic)
        # https://github.com/lmaccherone/node-localstorage/issues/6
        new (require('node-localstorage').LocalStorage)('./localstorage-bitshares-js')
            
    constructor: (@wallet_object, @wallet_name = "default") ->
        throw "Wallet object is required" unless @wallet_object # programmer error
        invalid_format = -> LE.throw "wallet.invalid_format", [@wallet_name]
        invalid_format() unless @wallet_object?.length > 0
        throwLE "wallet.missing_local_storage" unless localStorage
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    invalid_format() unless data.encrypted_key
                    invalid_format() unless data.checksum
                    @master_key = data
                    break
        invalid() unless @master_key
    
    WalletDb.exists = (wallet_name) ->
        str = localStorage.getItem("wallet-" + wallet_name)
        
    WalletDb.create = (wallet_name = "default", extended_private, password) ->
        LE.throw 'wallet.exists', [wallet_name] if WalletDb.open wallet_name
        checksum1 = hash.sha512 password
        checksum = hash.sha512 checksum1
        aes = Aes.fromSecret checksum1
        encrypted_key = aes.encrypt extended_private.toBuffer()
        wallet_object = [
            type: "master_key_record_type"
            data: 
                index: -1
                encrypted_key: encrypted_key.toString 'hex'
                checksum: checksum.toString 'hex'
        ]
        wallet_db = new WalletDb wallet_object, wallet_name
        wallet_db.save()
        wallet_db
    
    ###* @throws {key:'wallet.invalid_password'} ###
    validate_password: (password)->
        checksum1 = hash.sha512 password
        checksum = hash.sha512 checksum1
        unless @master_key.checksum is checksum.toString 'hex'
            LE.throw 'wallet.invalid_password'
        
    ###* @return {WalletDb} or null ###
    WalletDb.open = (wallet_name = "default") ->
        wallet_string = localStorage.getItem("wallet-" + wallet_name)
        #if wallet_string then console.log 'wallet opened' else 'no wallet'
        return undefined unless wallet_string
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
    
    ###
    _find: ->
        
        @account={} # [ string account name ] = object account_record_type
        @account_activeKey={} # [ string account name ] = string most recent active key
        @activeKey_account={} # [ string all active keys ] = string account name 
        
        @master_key.encrypted_key
        @master_key.checksum
        
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    @master_key.encrypted_key = data.encrypted_key
                    @master_key.checksum = data.checksum
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
                    
        throw "Invalid wallet format" unless @master_key.encrypted_key
    ###
exports.WalletDb = WalletDb