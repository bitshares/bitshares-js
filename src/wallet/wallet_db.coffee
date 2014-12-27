hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException
{Aes} = require '../ecc/aes'
{config} = require './config'
{PrivateKey} = require '../ecc/key_private'
{ExtendedAddress} = require '../ecc/extended_address'

class WalletDb
    
    localStorage = window?.localStorage ||
        # NodeJs development and testing (WARNING: get and set are not atomic)
        # https://github.com/lmaccherone/node-localstorage/issues/6
        new (require('node-localstorage').LocalStorage)('./localstorage-bitshares-js')
            
    constructor: (@wallet_object, @wallet_name = "default") ->
        throw new Error "required parameter" unless @wallet_object
        invalid_format = -> LE.throw "wallet.invalid_format", [@wallet_name]
        invalid_format() unless @wallet_object?.length > 0
        throwLE "wallet.missing_local_storage" unless localStorage
        @auto_save = true
        @property = {}
        @account = {}
        @ownerKey = {}
        @activeKey_account = {}
        @account_activeKey = {}
        @key_record = {}
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
                    @key_record[entry.address] = data
                    
        invalid() unless @master_key
        @resolve_address_to_name()
    
    ###*
        Adds from_account_name, to_account_name, and memo_from_account_name 
        to ledger entries.
        
        TODO, another function for blockchain api lookup 
    ###
    resolve_address_to_name:->
        # resolve any local registered account names
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "transaction_record_type"
                    tx = entry.data
                    for entry in tx.ledger_entries
                        if entry.from_account and not entry.from_account_name
                            # new property
                            entry.from_account_name = @get_account_for_address(entry.from_account)?.name
                        if entry.to_account and not entry.to_account_name
                            # new property
                            entry.to_account_name = @get_account_for_address(entry.to_account)?.name
                        if entry.memo_from_account and not entry.memo_from_account_name
                            # new property
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
        @auto_save = on
        wallet_string = JSON.stringify @wallet_object, null, 0
        localStorage.setItem("wallet-" + @wallet_name, wallet_string)
        return
        
    defer_save: ->
        @auto_save = off
    
    key_record: (public_key) ->
        bts_address = public_key.toBtsPublic()
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "key_record_type"
                    return data if data.public_key is bts_address
        return
        
    get_setting: (key) ->
        @property[key] or config.DEFAULT_SETTING[key]
    
    set_setting: (key, value) ->
        property = @property[key]
        if property
            property.value = value
            return
        
        index = @wallet_object[@wallet_object.length - 1].data.index
        throw "invalid index #{index}" unless /[0-9]+/.test index
        index += 1
        @wallet_object.push
            type: "property_record_type"
            data:
                index: index
                key: key
                value: value
        @save() if @auto_save
        @property[key] = value
        return
    
    list_accounts:->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            data = entry.data
            unless data["active_key"]
                hist = data.active_key_history
                hist = hist.sort (a,b)-> 
                    if a[0] < b[0] then-1 
                    else if a[0] > b[0] then 1 
                    else 0
                data["active_key"] = hist[hist.length - 1]
            data
            
    list_my_accounts:->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            continue unless entry.is_my_account
            data = entry.data
            unless data["active_key"]
                hist = data.active_key_history
                hist = hist.sort (a,b)-> 
                    if a[0] < b[0] then-1 
                    else if a[0] > b[0] then 1 
                    else 0
                data["active_key"] = hist[hist.length - 1]
            data

    lookup_account:(account_name)->
        @account[account_name]
        
    lookup_key:(account_address)->
        @key_record[account_address]
        
    get_account_for_address:(public_key_string)->
        @activeKey_account[public_key_string] or
        @ownerKey[public_key_string]
    
    master_private_key:(aes_root)->
        plainhex = aes_root.decryptHex @master_key.encrypted_key
        plainhex = plainhex.substring 0, 64
        PrivateKey.fromHex plainhex
    
    get_wallet_child_key:(aes_root, key_index)->
        master_key = @master_private_key aes_root
        ExtendedAddress.private_key master_key key_index
        
        
    generate_new_account:(aes_root, account_name, private_data)->
        LE.throw 'wallet.account_already_exists' if @account[account_name]
        key_index = @get_child_key_index()
        master_key = @master_private_key aes_root
        private_key = public_key = address = null
        while true
            ++key_index
            private_key = ExtendedAddress.private_key master_key, key_index
            public_key = private_key.toPublicKey()
            address = public_key.toBtsAddy()
            record = @lookup_account address
            continue if record
            key = @lookup_key address
            continue if key
            break
        public_key_string = public_key.toBtsPublic()
        key =
            account_address: address
            public_key: public_key_string
            encrypt_private_key: aes_root.encryptHex private_key.toHex()
            gen_seq_number: key_index
        account =
            name: account_name
            owner_key: public_key_string
            active_key_history: [
                [
                    (new Date().toISOString()).split('.')[0] # blockchain::now()
                    public_key_string
                ]
            ]
            private_data: private_data
            is_my_account: yes
        @defer_save()
        @set_child_key_index key_index
        @add_key_record key
        @add_account_record account
        @save()
        public_key_string
        
    
    add_account_record:(rec)->
        #last_account_index = 1
        #for entry in @wallet_object # todo, backwards is better
        #    if entry.type is "account_record_type"
        #        #console.log entry.data.id
        #        last_account_index = entry.data.id
        # New accounts in the backups all use an id of 0
        rec.id = 0 #last_account_index + 1
        @_append('account_record_type',rec)
    add_key_record:(rec)->
        @_append('key_record_type',rec)
    _append:(key, rec)->
        last = @wallet_object[@wallet_object.length - 1]
        rec.index = last.index+1
        @wallet_object.push
            type: key
            data: rec
        @save() if @auto_save
        return
    
    get_child_key_index:->
        index = @get_setting('next_child_key_index')?.value
        index = 0 unless index
        index
        
    set_child_key_index:(value)->
        @set_setting('next_child_key_index', value)
        
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
    
exports.WalletDb = WalletDb