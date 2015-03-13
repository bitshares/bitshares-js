q = require 'q'
config = require './config'
hash = require '../ecc/hash'
main_config = require '../config'
LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
{Storage} = require '../common/storage'
{Aes} = require '../ecc/aes'
{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{PrivateKey} = require '../ecc/key_private'
{ExtendedAddress} = require '../ecc/extended_address'
{WithdrawCondition} = require '../blockchain/withdraw_condition'
{ChainInterface} = require '../blockchain/chain_interface'
{RelayNode} = require '../net/relay_node'

class WalletDb
    
    constructor: (@wallet_object, @wallet_name = "default", @events={}) ->
        EC.throw "required parameter" unless @wallet_object
        invalid_format = -> LE.throw "jslib_wallet.invalid_format", [@wallet_name]
        invalid_format() unless @wallet_object?.length > 0
        @storage = new Storage(
            @wallet_name + " " + main_config.bts_address_prefix
        )
        @property = {}
        @account = {}
        @ownerKey = {}
        @activeKey_account = {}
        @account_activeKey = {}
        @key_record = {}
        @account_address = {}
        #@transaction_from = {}
        @transaction_to = {}
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "master_key_record_type"
                    invalid_format() unless data.encrypted_key
                    invalid_format() unless data.checksum
                    @master_key = data
                when "property_record_type"
                    @index_property data
                when "account_record_type"
                    @index_account data
                when "key_record_type"
                    @index_key_record data
                when "transaction_record_type"
                    @index_transaction data
                    
                    
        invalid() unless @master_key
        @resolve_address_to_name()
    
    # Support update or insert or cache (no save)
    index_account:(data, update_key_records = false)->
        account_name = data.name
        @account[account_name] = data
        max_key_datestr = null
        @ownerKey[data.owner_key] = data if data.owner_key
        for keyrec in data.active_key_history
            datestr = keyrec[0]
            key = keyrec[1]
            if max_key_datestr is null or datestr > max_key_datestr
                #console.log 'account_activeKey',account_name,key
                # most recent active key
                @account_activeKey[account_name] = key
                @activeKey_account[key] = data
                max_key_datestr = datestr
        
        if update_key_records
            public_keys = []
            public_keys.push data.owner_key
            for key in data.active_key_history
                public_keys.push key[1]
            if data.delegate_info?.signing_key_history
                for key in data.active_key_history
                    public_keys.push key[1]
            for key in public_keys
                key_record = @key_record[key]
                unless key_record
                    public_key = PublicKey.fromBtsPublic key
                    @add_key_record
                        account_address: public_key.toBtsAddy()
                        public_key: key
                # "index" should not make write operations. 
                # in bts' code, not needed in bitshares-js
                ###
                else
                    if key_record.encrypted_private_key
                        
                        unless data.is_my_account
                            data.is_my_account = true
                            #store
                        public_key = PublicKey.fromBtsPublic key
                        account_address = public_key.toBtsAddy()
                        owner_public = PublicKey.fromBtsPublic data.owner_key
                        owner_address = owner_public.toBtsAddy()
                        if account_address isnt owner_address
                            key_record.account_address = owner_address
                            store key_record
                ###
    
    index_key_record:(data)->
        @key_record[data.public_key] = data
        @key_record[data.account_address] = data
        public_key = PublicKey.fromBtsPublic data.public_key
        
        #https://github.com/BitShares/bitshares/blob/2602504998dcd63788e106260895769697f62b07/libraries/wallet/wallet_db.cpp#L103-L108
        index=(addr)=>@key_record[addr.toString()] = data
        index Address.fromPublic public_key, false, 0
        index Address.fromPublic public_key, true, 0
        index Address.fromPublic public_key, false, 56
        index Address.fromPublic public_key, true, 56
        
    index_property:(data)->
        @property[data.key] = data
        return
        
    index_transaction:(data)->
        EC.throw "Expecting transaction record to contain: trx" unless data.trx
        EC.throw "Expecting transaction record to contain: ledger_entries" unless data.ledger_entries
        
        for entry in data.ledger_entries
            continue unless entry.to_account
            to = @transaction_to[entry.to_account]
            unless to
                @transaction_to[entry.to_account] = to = []
            to.push data
        ###
        for entry in data.ledger_entries
            continue unless entry.from_account
            from = @transaction_from[entry.from_account]
            unless from
                @transaction_from[entry.from_account] = from = []
            from.push data
        for entry in data.ledger_entries
            continue unless entry.memo_from_account
            from = @transaction_from[entry.memo_from_account]
            unless from
                @transaction_from[entry.memo_from_account] = from = []
            from.push data
        ###
            
    
    ###*
        Adds from_account_name, to_account_name, and memo_from_account_name 
        to ledger entries.
        
        TODO, another function for blockchain api lookup 
    ###
    resolve_address_to_name:->
        # resolve any local registered account names
        # simplifies transaction_history
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
        storage = new Storage(
            wallet_name + " " + main_config.bts_address_prefix
        )
        wallet_json = storage.getItem 'wallet_json'
        if wallet_json then yes else no
    
    WalletDb.create = (wallet_name = "default", extended_private, brainkey, password, save = true, events) ->
        if WalletDb.exists wallet_name
            LE.throw 'jslib_wallet.exists', [wallet_name]
        
        checksum = hash.sha512 password
        checksum = hash.sha512 checksum
        aes = Aes.fromSecret password
        encrypted_key = aes.encrypt extended_private.toBuffer()
        wallet_object = [
            type: "master_key_record_type"
            data: 
                index: -1
                encrypted_key: encrypted_key.toString 'hex'
                checksum: checksum.toString 'hex'
        ]
        
        wallet_db = new WalletDb wallet_object, wallet_name, events
        wallet_db.save_brainkey aes, brainkey, save
        wallet_db.save() if save
        wallet_db
    
    ###* @return {WalletDb} or null ###
    WalletDb.open = (wallet_name = "default", events) ->
        storage = new Storage(
            wallet_name + " " + main_config.bts_address_prefix
        )
        wallet_json = storage.getItem 'wallet_json'
        return undefined unless wallet_json
        wallet_object = JSON.parse wallet_json
        new WalletDb wallet_object, wallet_name, events
    
    WalletDb.delete = (wallet_name)->
        storage = new Storage(
            wallet_name + " " + main_config.bts_address_prefix
        )
        storage.removeItemOrThrow 'wallet_json'
        return
    
    #WalletDb.has_legacy_bts_wallet=->
    #    storage = new Storage()
    #    #return no if storage.getItem("no_legacy_bts_wallet") is ""
    #    for i in [0...storage.local_storage.length] by 1
    #        key = storage.local_storage.key i
    #        # Only BTS had users create legacy accounts
    #        continue unless key.match /^[A-Za-z0-9]+ BTS\twallet_json$/
    #        return yes
    #    #storage.setItem "no_legacy_bts_wallet",""
    #    return no
    
    save_brainkey:(aes_root, brainkey, save)->
        (-># hide a really weak brainkey
            pad = 256 - brainkey.length
            if pad > 0
                spaces = ""
                spaces += " " for i in [0..pad] by 1
                brainkey += spaces
        )()
        cipherhex = aes_root.encryptHex new Buffer(brainkey).toString 'hex'
        @set_setting 'encrypted_brainkey', cipherhex, save
        return
    
    get_brainkey:(aes_root, normalize)->
        brain_key = aes_root.decryptHex @get_setting 'encrypted_brainkey'
        brain_key = new Buffer(brain_key,'hex').toString().trim()
        return brain_key unless normalize
        # http://doc.qt.io/qt-5/qstring.html#simplified
        brain_key = brain_key.split(/[\t\n\v\f\r ]+/).join ' '
        brain_key = brain_key.toUpperCase()
    
    master_private_key:(aes_root)->
        plainhex = aes_root.decryptHex @master_key.encrypted_key
        plainhex = plainhex.substring 0, 64
        PrivateKey.fromHex plainhex
    
    ###* @throws {QuotaExceededError} ###
    save: ->
        wallet_string = JSON.stringify @wallet_object, null, 0
        @storage.setItem('wallet_json', wallet_string)
        return
        
    ### This does not work with Date objects ###
    _clone:(obj)->
        JSON.parse JSON.stringify obj
    
    get_key_record:(public_key)->
        @_clone @key_record[public_key]
        
    get_setting: (key) ->
        @property[key]?.value or config.DEFAULT_SETTING[key]
    
    set_setting: (key, value, save = true) ->
        data = @property[key]
        if data
            data.value = value
        else
            index = @wallet_object[@wallet_object.length - 1].data.index
            index++ if index is -1 #bitshares client does not allow a zero
            index++
            @property[key] = property_record =
                type: "property_record_type"
                data:
                    index: index
                    key: key
                    value: value
            @index_property property_record.data
            @wallet_object.push property_record
        
        @save() if save
        return
    
    get_trx_expiration:->
        exp = new Date()
        sec = @get_setting 'transaction_expiration_sec'
        # https://github.com/BitShares/BitShares-JS/issues/58
        offset = sec + Math.round RelayNode.ntp_offset / 1000
        exp.setSeconds exp.getSeconds() + offset
        exp = new Date(exp.toISOString().split('.')[0])
    
    list_accounts:(just_mine=false)->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            account = @_pretty_account entry.data
            if just_mine
                continue unless @is_my_account account
            account
    
    ###*
        Get an account, try to sync with blockchain account 
        cache in wallet_db.  This may call blockchain_get_account
        which will resolve a name, ID, or public key.
    ###
    get_chain_account:(name, blockchain_api, refresh = false)-> # was lookup_account
        unless refresh
            local_account = @lookup_account name
            local_account = @get_account_for_address name unless local_account
            if local_account
                defer = q.defer()
                defer.resolve local_account
                return defer.promise

        p = null
        ((name)=>
            p = blockchain_api.get_account(name).then (chain_account)=>
                local_account = @lookup_account name
                local_account = @get_account_for_address name unless local_account
                unless local_account or chain_account
                    LE.throw "jslib_general.unknown_account", [name]
                
                if local_account and chain_account
                    if local_account.owner_key isnt chain_account.owner_key
                        LE.throw "jslib_wallet.conflicting_account", [name]
                
                if chain_account
                    @store_account_or_update chain_account
                    local_account = @lookup_account chain_account.name
                
                local_account
        )(name)
        p

    
    lookup_account:(account_name)->
        account = @account[account_name]
        return null unless account
        @_pretty_account account
    
    get_account_for_address:(address)->
        key = @lookup_key address
        return unless key
        @_pretty_account(
            @activeKey_account[key.public_key] or
            @ownerKey[key.public_key]
        )
        
    lookup_key:(account_address)->
        @key_record[account_address]
        
    lookup_active_key:(account_name)->
        @account_activeKey[account_name]
        
    lookup_owner_key:(account_name)->
        @lookup_account(account_name).owner_key
        
    is_my_account:(account)->
        key = @key_record[account.owner_key]
        return yes if key?.encrypted_private_key
        key = @account_activeKey[account.name]
        return yes if key?.encrypted_private_key
        return no
    
    _pretty_account:(account)->
        return null unless account
        unless account.registration_date
            # web_wallet littered with this date
            account.registration_date = "1970-01-01T00:00:00"
        account.is_my_account = @is_my_account account
        account.active_key = ChainInterface.get_active_key account.active_key_history
        account
    
    guess_next_account_keys:(aes_root, count, algorithm = 'standard')->
        switch algorithm
            when 'standard'
                key_index = @get_child_key_index()
                brainkey = @get_brainkey aes_root, normalize = yes
                for i in [0...count] by 1
                    owner_key = PrivateKey.fromBuffer(
                        hash.sha256 hash.sha512 brainkey + " " + (key_index + i)
                    )
                    public: owner_key.toPublicKey().toBtsPublic()
                    index: (key_index + i)
            
            when 'online_wallet_2015_03_14'
                key_index = 1
                for i in [0...count] by 1
                    master_key = @master_private_key aes_root
                    private_key = ExtendedAddress.private_key master_key, (key_index + i)
                    public: private_key.toPublicKey().toBtsPublic()
                    index: key_index
    
    generate_new_account:(
        aes_root, blockchain_api
        account_name, private_data
        next_account = null
        algorithm = 'standard'
    )->
        if @account[account_name]
            LE.throw 'jslib_wallet.account_already_exists', [account_name]
        
        standard_child_index = undefined
        [owner_key, active_key] = switch algorithm
            when 'standard'
                standard_child_index = if next_account
                    next_account.index 
                else
                    @get_child_key_index()
                
                brainkey = @get_brainkey aes_root, normalize = yes
                owner_key = PrivateKey.fromBuffer(
                    hash.sha256 hash.sha512 brainkey + " " + standard_child_index
                )
                if next_account
                    # account recovery
                    owner_public = owner_key.toPublicKey()
                    unless next_account.public is owner_public.toBtsPublic()
                        throw new Error "unable to generate account matching requested owner key"
                
                active_key = PrivateKey.fromBuffer(
                    hash.sha256 hash.sha512 owner_key.toWif() + " 0"
                )
                
                [owner_key, active_key]
            
            when 'online_wallet_2015_03_14'
                throw new Error 'next_account required' unless next_account
                master_key = @master_private_key aes_root
                owner_key = ExtendedAddress.private_key master_key, next_account.index 
                owner_public = owner_key.toPublicKey()
                # account recovery
                unless next_account.public is owner_public.toBtsPublic()
                    throw new Error "unable to generate account matching requested owner key"
                
                active_key = ExtendedAddress.private_key owner_key, 0
                [owner_key, active_key]
        
        [account, active, owner] = @_new_account(
            aes_root, account_name, owner_key
            active_key, private_data
        )
        
        defer = q.defer()
        ((standard_child_index, account, active, owner)=>
            blockchain_api.get_account(account_name).then (chain_account)=>
                if (
                    try
                        @store_account_or_update(account, chain_account, _save=false)
                        true
                    catch error
                        # registered account conflict
                        defer.reject error
                        false
                )
                    @add_key_record owner, _save=false
                    @add_key_record active, _save=false
                    if standard_child_index isnt undefined
                        new_index = Math.max @get_child_key_index(), standard_child_index + 1
                        @set_child_key_index new_index, _save=false
                    @save()
                    defer.resolve owner.public_key
        )(standard_child_index, account, active, owner)
        defer.promise
    
    ### but may be needed by legacy light wallet accounts 
    recover_account:(
        aes_root, blockchain_api
        account_name, private_data
        save = true
        recover_only = false
    )->
        # light-wallet compatible
        brainkey = @get_brainkey aes_root, normalize = yes
        owner_key = PrivateKey.fromBuffer(
            hash.sha256 hash.sha512 brainkey + " " + account_name
        )
        owner_public = owner_key.toPublicKey()
        active_key = PrivateKey.fromBuffer(
            hash.sha256 hash.sha512 owner_key.toWif() + " 0"
        )
        [account, active, owner] = @_new_account(
            aes_root, account_name, owner_key
            active_key, private_data
        )
        defer = q.defer()
        blockchain_api.get_account(account_name).then (chain_account)=>
            if recover_only
                unless chain_account
                    defer.reject new LE 'jslib_wallet.account_not_found', [account_name]
            if (
                try
                    @store_account_or_update account, chain_account, false
                    true
                catch error
                    defer.reject error
                    false
            )
                @add_key_record owner, false
                @add_key_record active, false
                @save() if save
                defer.resolve owner_public.toBtsPublic()
        defer.promise
    ###
    
    _new_account:(
        aes_root, account_name, owner_private_key
        active_private_key, private_data
    )->
        owner_public_key = owner_private_key.toPublicKey()
        owner_address = owner_public_key.toBtsAddy()
        active_public_key = active_private_key.toPublicKey()
        active_address = active_public_key.toBtsAddy()
        active_key =
            account_address: active_address
            public_key: active_public_key.toBtsPublic()
            encrypted_private_key: aes_root.encryptHex active_private_key.toHex()
        
        owner_key =
            account_address: owner_address
            public_key: owner_public_key.toBtsPublic()
            encrypted_private_key: aes_root.encryptHex owner_private_key.toHex()
        
        account =
            name: account_name
            public_data: null
            owner_key: owner_public_key.toBtsPublic()
            active_key_history: [
                [
                    (new Date().toISOString()).split('.')[0] # blockchain::now()
                    active_public_key.toBtsPublic()
                ]
            ]
            registration_date: null
            last_update: (new Date().toISOString()).split('.')[0]
            delegate_info: null
            meta_data: null
            is_my_account: yes
            approved: 0
            is_favorite: false
            block_production_enabled: false
            last_used_gen_sequence: 0
            private_data: private_data
        [account, active_key, owner_key]
    
    add_transaction_record:(rec, save = true)->
        @index_transaction rec
        @_append('transaction_record_type',rec)
        @save() if save
        return
    
    _wallet_index:(matches)->
        for i in [0...@wallet_object.length] by 1
            return i if matches @wallet_object[i]
    
    add_account_record:(account, save = true)->
        if @lookup_account account.name
            EC.throw "Account already exists"
        @store_account_or_update account, null, save
        return
    
    store_account_or_update:(new_account, chain_account = null, save = true)-> #store_account
        EC.throw "missing account name" unless new_account.name
        EC.throw "missing owner key" unless new_account.owner_key
        is_conflict=(account1, account2)->
            if account1.owner_key isnt account2.owner_key
                LE.throw "jslib_wallet.conflicting_account", [new_account.name]
        
        if chain_account
            is_conflict new_account, chain_account
            old_active = chain_active = null
            if (
                old_active = ChainInterface.get_active_key(new_account.active_key_history) isnt 
                chain_active = ChainInterface.get_active_key chain_account.active_key_history
            )
                history = new_account.active_key_history
                history.push chain_active
                (@events['wallet.active_key_updated'] or ->)(
                    chain_active, old_active
                )
            
        new_account.last_update = (new Date().toISOString()).split('.')[0]
        delete new_account.is_my_account #calc in real time instead
        delete new_account.active_key #populated from active key history array
        
        existing_account = @lookup_account new_account.name
        if existing_account
            is_conflict new_account, existing_account
            i = @_wallet_index (o)->
                o.type is "account_record_type" and
                o.data.name is new_account.name
            
            new_account.index = existing_account.index
            if existing_account.private_data
                new_account.private_data = existing_account.private_data
            @wallet_object[i].data = new_account
        else
            new_account.id = 0 #last_account_index + 1
            @_append('account_record_type',new_account)
        
        @index_account new_account, true
        @save() if save
    
    add_key_record:(rec, save = true)-> # store_and_reload_record
        @index_key_record rec
        @_append('key_record_type',rec)
        @save() if save
    
    _append:(key, rec)->
        last = @wallet_object[@wallet_object.length - 1].data
        rec.index = last.index+1
        @wallet_object.push
            type: key
            data: rec
        @_debug_last key
        return
    
    _debug_last:(ref)->
        #console.log "#{ref}",JSON.stringify @wallet_object[@wallet_object.length - 1].data,null,4
        return
    
    get_child_key_index:->
        index = @get_setting 'next_child_key_index'
        index = 0 unless index
        index
    
    set_child_key_index:(value, save = true)->
        @set_setting 'next_child_key_index', value, save
    
    get_my_key_records:(account_name, include_owner_key = false)->
        account = @lookup_account account_name
        return [] unless account
        addresses = {}
        lookup=(public_key)=>
            publicKey = PublicKey.fromBtsPublic public_key
            address = publicKey.toBtsAddy()
            key = @key_record[address]
            return unless key?.encrypted_private_key
            addresses[address] = on
        
        lookup account.owner_key if include_owner_key
        lookup ChainInterface.get_active_key account.active_key_history
        
        #if account.delegate_info?.signing_key_history
        #    lookup ChainInterface.get_active_key account.delegate_info.signing_key_history
        
        for entry in @wallet_object
            continue unless entry.type is "key_record_type"
            continue unless entry.data.encrypted_private_key
            continue unless addresses[entry.data.account_address]
            entry.data
    
    ###* @return {array} WithdrawCondition (withdraw_signature_type only) ###
    getWithdrawConditions:(account_name)->
        wcs = []
        account = @lookup_account account_name
        to = @transaction_to[account.owner_key]
        for key in account.active_key_history
            to_array = @transaction_to[key[1]]
            to.push t for t in to_array if to_array
        # include signing keys?
        return [] unless to
        for record in to
            continue unless tx = record.trx
            for op in tx.operations
                continue unless op.type is 'deposit_op_type'
                condition = op.data.condition
                unless condition.type is 'withdraw_signature_type'
                    continue
                
                wcs.push WithdrawCondition.fromJson op.data.condition
        wcs
    
    ###* @throws {key:'wallet.invalid_password'} ###
    validate_password: (password)->
        checksum1 = hash.sha512 password
        checksum = hash.sha512 checksum1
        @master_key.checksum is checksum.toString 'hex'
    
    getActivePrivate:(aes_root, account_name)->
        throw new Error 'missing required parameter' unless account_name
        active_key = @lookup_active_key account_name
        return null unless active_key
        key_record = @get_key_record active_key
        return null unless key_record?.encrypted_private_key
        PrivateKey.fromHex aes_root.decryptHex key_record.encrypted_private_key
    
exports.WalletDb = WalletDb
