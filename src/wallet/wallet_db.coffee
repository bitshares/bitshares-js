hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException
{Aes} = require '../ecc/aes'
#config = require './config'

class WalletDb
    
    localStorage = window?.localStorage ||
        # NodeJs development and testing (WARNING: get and set are not atomic)
        # https://github.com/lmaccherone/node-localstorage/issues/6
        new (require('node-localstorage').LocalStorage)('./localstorage-bitshares-js')
            
    constructor: (@wallet_object, @wallet_name = "default", @autocommit = true) ->
        throw new Error "required parameter" unless @wallet_object
        invalid_format = -> LE.throw "wallet.invalid_format", [@wallet_name]
        invalid_format() unless @wallet_object?.length > 0
        throwLE "wallet.missing_local_storage" unless localStorage
        @property = {}
        @account = {}
        @ownerKey = {}
        @activeKey_account = {}
        @account_activeKey = {}
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    invalid_format() unless data.encrypted_key
                    invalid_format() unless data.checksum
                    @master_key = data
                when "property_record_type"
                    @property[data.key] = data.value
                when "account_record_type"
                    account_name = data.name
                    @account[account_name] = data
                    max_key_datestr = "0"
                    @ownerKey[data.owner_key] = data if data.owner_key
                    for keyrec in data.active_key_history
                        datestr = keyrec[0]
                        key = keyrec[1]
                        @activeKey_account[key] = data
                        if datestr > max_key_datestr
                            # most recent active key
                            @account_activeKey[account_name] = key
                            max_key_datestr = datestr
                when "key_record_type"
                    address = data.account_address
                    public_key = data.public_key
                    
        invalid() unless @master_key
        @resolve_address_to_name()
    
    ### TODO, add optional parameter for blockchain api lookup ###
    resolve_address_to_name:->
        # resolve any local registered account names
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "transaction_record_type"
                    tx = entry.data
                    for entry in tx.ledger_entries
                        if entry.from_account and not entry.from_account_name
                            entry.from_account_name = @get_account_for_address(entry.from_account)?.name
                        if entry.to_account and not entry.to_account_name 
                            entry.to_account_name = @get_account_for_address(entry.to_account)?.name
                        if entry.memo_from_account and not entry.memo_from_account_name
                            entry.memo_from_account_name = @get_account_for_address(entry.memo_from_account)?.name
    
    WalletDb.exists = (wallet_name) ->
        str = localStorage.getItem("wallet-" + wallet_name)
    
    WalletDb.create = (wallet_name = "default", extended_private, password, autocommit) ->
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
        wallet_db = new WalletDb wallet_object, wallet_name, autocommit
        wallet_db.save() if autocommit
        wallet_db
        
    ###* @return {WalletDb} or null ###
    WalletDb.open = (wallet_name = "default") ->
        wallet_string = localStorage.getItem "wallet-" + wallet_name
        return undefined unless wallet_string
        wallet_object = JSON.parse wallet_string
        new WalletDb wallet_object, wallet_name
        
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
        
    get_setting: (key) ->
        value = @property[key]
        ### Defaults:
        unless value
            switch key
                when "transaction_fee"
                    config.BTS_WALLET_DEFAULT_TRANSACTION_FEE / 
        ###
        
    set_setting: (key, value) ->
        index = @wallet_object[@wallet_object.length - 1].data.index
        index += 1
        @wallet_object.push
            type: "property_record_type"
            data:
                index: index
                key: key
                value: value
        @save() if @autocommit
        @property[key] = value
    
    list_accounts:->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            data = entry.data
            unless data["active_key"]
                hist = data.active_key_history
                hist = hist.sort (a,b)->a[0]<b[0]
                data["active_key"] = hist[hist.length - 1]
            data

    get_transactions:->
        for entry in @wallet_object
            continue unless entry.type is "transaction_record_type"
            entry.data
    
    ###* @throws {key:'wallet.invalid_password'} ###
    validate_password: (password)->
        checksum1 = hash.sha512 password
        checksum = hash.sha512 checksum1
        unless @master_key.checksum is checksum.toString 'hex'
            LE.throw 'wallet.invalid_password'
            
    get_account_for_address:(public_key_string)->
        @activeKey_account[public_key_string] or
        @ownerKey[public_key_string]
    
exports.WalletDb = WalletDb