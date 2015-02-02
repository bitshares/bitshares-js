hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
config = require './config'
main_config = require '../config'
localStorage = require '../common/local_storage'
{Aes} = require '../ecc/aes'
{Address} = require '../ecc/address'
{PublicKey} = require '../ecc/key_public'
{PrivateKey} = require '../ecc/key_private'
{ExtendedAddress} = require '../ecc/extended_address'
{WithdrawCondition} = require '../blockchain/withdraw_condition'

class WalletDb
    
    CHAIN_SYMBOL = main_config.bts_address_prefix
    
    constructor: (@wallet_object, @wallet_name = "default") ->
        EC.throw "required parameter" unless @wallet_object
        invalid_format = -> LE.throw "wallet.invalid_format", [@wallet_name]
        invalid_format() unless @wallet_object?.length > 0
        throwLE "wallet.missing_local_storage" unless localStorage
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
        max_key_datestr = ""
        @ownerKey[data.owner_key] = data if data.owner_key
        for keyrec in data.active_key_history
            datestr = keyrec[0]
            key = keyrec[1]
            @activeKey_account[key] = data
            if datestr > max_key_datestr
                #console.log 'account_activeKey',account_name,key
                # most recent active key
                @account_activeKey[account_name] = key
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
        str = localStorage.getItem("wallet-" + CHAIN_SYMBOL + '-' + wallet_name)
    
    WalletDb.create = (wallet_name = "default", extended_private, password, save = true) ->
        if WalletDb.open wallet_name
            LE.throw 'wallet.exists', [wallet_name]
        
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
        wallet_db = new WalletDb wallet_object, wallet_name
        wallet_db.save() if save
        wallet_db
    
    ###* @return {WalletDb} or null ###
    WalletDb.open = (wallet_name = "default") ->
        wallet_string = localStorage.getItem "wallet-" + CHAIN_SYMBOL + '-' + wallet_name
        return undefined unless wallet_string
        wallet_object = JSON.parse wallet_string
        new WalletDb wallet_object, wallet_name
    
    WalletDb.delete = (wallet_name)->
        localStorage.removeItem "wallet-" + CHAIN_SYMBOL + '-' + wallet_name
        return
    
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
    
    get_brainkey:(aes_root)->
        plainhex = aes_root.decryptHex @get_setting 'encrypted_brainkey'
        new Buffer(plainhex,'hex').toString().trim()
    
    master_private_key:(aes_root)->
        plainhex = aes_root.decryptHex @master_key.encrypted_key
        plainhex = plainhex.substring 0, 64
        PrivateKey.fromHex plainhex
    
    ###* @throws {QuotaExceededError} ###
    save: ->
        wallet_string = JSON.stringify @wallet_object, null, 0
        localStorage.setItem("wallet-" + CHAIN_SYMBOL + '-' + @wallet_name, wallet_string)
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
            throw "invalid index #{index}" unless /[0-9]+/.test index
            @property[key] = property_record =
                type: "property_record_type"
                data:
                    index: ++index
                    key: key
                    value: value
            @index_property property_record.data
            @wallet_object.push property_record
        
        @save() if save
        return
    
    get_trx_expiration:->
        exp = new Date()
        sec = @get_setting 'transaction_expiration_sec'
        exp.setSeconds exp.getSeconds() + sec
        # removing seconds causes the epoch value 
        # the time_point_sec conversion Math.ceil(epoch / 1000)
        # to always come out as a odd number.  With the 
        # seconds, the result will always be even and 
        # the transaction will not be valid (signature 
        # assertion exception)
        exp = new Date(exp.toISOString().split('.')[0])
    
    get_transaction_fee:->
        @get_setting "transaction_fee"
    
    list_accounts:(just_mine=false)->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            account = @_pretty_account entry.data
            continue unless account.is_my_account if just_mine
            account
    
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
        
    is_my_account:(owner_key)->
        rec = @get_key_record owner_key
        return yes if rec?.encrypted_private_key
        return no
    
    _pretty_account:(account)->
        return null unless account
        unless account.registration_date
            # web_wallet littered with this date
            account.registration_date = "1970-01-01T00:00:00"
        account.is_my_account = @is_my_account account.owner_key
        account.active_key = @_get_active_key account.active_key_history
        account
    
    guess_next_account_keys:(aes_root, count)->
        key_index = @get_child_key_index()
        master_key = @master_private_key aes_root
        for i in [0...count] by 1
            ++key_index
            private_key = ExtendedAddress.private_key master_key, key_index
            public: private_key.toPublicKey().toBtsPublic()
            index: key_index
    
    #get_wallet_child_key:(aes_root, key_index)->
    #    master_key = @master_private_key aes_root
    #    ExtendedAddress.private_key master_key key_index
        
    generate_new_account:(
        aes_root, account_name, private_data
        save = true, next_account = null
    )->
        LE.throw 'wallet.account_already_exists' if @account[account_name]
        key_index = if next_account
           next_account.index 
        else
            @get_child_key_index()
        master_key = @master_private_key aes_root
        owner_private_key = owner_public_key = owner_address = null
        while true
            ++key_index unless next_account
            throw new Error "overflow" if key_index > Math.pow(2,32)
            owner_private_key = ExtendedAddress.private_key master_key, key_index
            owner_public_key = owner_private_key.toPublicKey()
            if next_account
                # account backup recovery
                unless next_account.public is owner_public_key.toBtsPublic()
                    throw new Error "unable to generate account matching requested owner key"
            
            owner_address = owner_public_key.toBtsAddy()
            continue if @get_account_for_address owner_address
            continue if (@lookup_key owner_address)?.key?.encrypted_private_key
            
            active_private_key = ExtendedAddress.private_key owner_private_key, 0
            active_public_key = active_private_key.toPublicKey()
            active_address = active_public_key.toBtsAddy()
            continue if @get_account_for_address active_address
            continue if (@lookup_key active_address)?.key?.encrypted_private_key
            break
        
        active_key =
            account_address: active_address
            public_key: active_public_key.toBtsPublic()
            encrypted_private_key: aes_root.encryptHex active_private_key.toHex()
            gen_seq_number: 0
        
        owner_key =
            account_address: owner_address
            public_key: owner_public_key.toBtsPublic()
            encrypted_private_key: aes_root.encryptHex owner_private_key.toHex()
            gen_seq_number: key_index
        
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
        
        @add_key_record active_key, false
        @set_child_key_index key_index, false
        @add_key_record owner_key, false
        @add_account_record account, false
        @save() if save
        owner_public_key.toBtsPublic()
    
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
        @store_account_or_update account, save
        return
    
    store_account_or_update:(account, save = true)-> #store_account
        EC.throw "missing account name" unless account.name
        EC.throw "missing owner key" unless account.owner_key
        account.last_update = (new Date().toISOString()).split('.')[0]
        delete account.is_my_account #calc in real time instead
        delete account.active_key #populated from active key history array
        existing = @lookup_account account.name
        if existing
            # New accounts in bitshares_client backups use an id of 0
            account.id = 0 #last_account_index + 1
            i = @_wallet_index (o)->
                o.type is "account_record_type" and o.data.name is account.name
            #console.log 'store_account_or_update', account.name,i
            if @wallet_object[i].owner isnt account.owner
                throw new Error "owner key unique violation on account '#{account.name}'"
            
            @wallet_object[i].data = account
        else
            @_append('account_record_type',account)
        
        @index_account account, true
        @save() if save
    
    ###
    ##* @return {PrivateKey} ##
    generate_new_one_time_key:(aes_root)->
        throw new Error 'not implemented'
        # Deterministic instead of random to piggy-back
        # on the extra entropy used in the master key
        one_time_private_key = PrivateKey.newRandom()
        one_time_public = one_time_private_key.toPublicKey()
        one_time_address = one_time_public.toBtsAddy()
        key_record = @lookup_key one_time_address
        throw new Error 'key exists' if key_record
        @store_key
            public_key: one_time_public
            encrypted_private_key: aes_root.encryptHex one_time_private_key.toHex()
        one_time_private_key
    ###
    ###
    store_key:(key, save)->
       key_record = @lookup_key key.public_key.getBtsAddy()
       key_record = {} unless key_record
       @add_key_record key_record, off
       if key_record.encrypted_private_key
           account_record = @get_account_for_address key.public_key
           unless account_record
               account_record = @get_account_for_address key.account_address
           if account_record
               account_record_address = PublicKey.fromHex(account_record.owner_key).toBtsAddy()
               if key_record.account_address isnt account_record_address
                   throw 'address miss match'
               #    key_record.account_address = account_record_address
               #    @add_key_record key_record, off
               unless account_record.is_my_account
                   account_record.is_my_account = yes
                   @store_account_or_update account_record, off
       @save() if save
    ###
    
    ###* @return {PrivateKey} ###
    generate_new_account_child_key:(aes_root, account_name, save = true)->
        private_key = @getActivePrivate aes_root, account_name
        LE.throw 'wallet.account_not_found',[account_name] unless current_account unless private_key
        account = @lookup_account account_name
        seq = account.last_used_gen_sequence
        seq = 0 unless seq
        child_private = child_public = child_address = null
        while true
            try
                child_private = ExtendedAddress.private_key private_key, seq
                child_public = child_private.toPublicKey()
                child_address = child_public.toBtsAddy()
                break unless @key_record[child_address]
            catch error
                console.log "Error creating child key index #{seq} for account #{account_name}", error  # very rare
            
        account.last_used_gen_sequence = seq
        @add_key_record
            account_address: child_address
            public_key: child_public.toBtsPublic()
            encrypted_private_key: aes_root.encryptHex child_private.toHex()
        , save
        child_private
        
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
    
    #get_transactions:->
    #    for entry in @wallet_object
    #        continue unless entry.type is "transaction_record_type"
    #        entry.data
    
    _get_active_key:(hist)->
        hist = hist.sort (a,b)-> 
            if a[0] < b[0] then -1 
            else if a[0] > b[0] then 1 
            else 0
        hist[hist.length - 1][1]
    
    get_my_key_records:(account_name)->
        active_only = false
        account = @lookup_account account_name
        return null unless account
        addresses = {}
        lookup=(public_key)=>
            publicKey = PublicKey.fromBtsPublic public_key
            address = publicKey.toBtsAddy()
            key = @key_record[address]
            return unless key?.encrypted_private_key
            addresses[address] = on
        
        lookup account.owner_key
        if active_only
            lookup @_get_active_key account.active_key_history
        else
            lookup key[1] for key in account.active_key_history
               
        if account.delegate_info?.signing_key_history
            if active_only 
                lookup @_get_active_key account.delegate_info.signing_key_history
            else
                lookup key[1] for key in account.delegate_info.signing_key_history
        
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
        unless @master_key.checksum is checksum.toString 'hex'
            LE.throw 'wallet.invalid_password'
            
    getActivePrivate:(aes_root, account_name)->
        throw new Error 'missing required parameter' unless account_name
        active_key = @lookup_active_key account_name
        return null unless active_key
        key_record = @get_key_record active_key
        return null unless key_record
        PrivateKey.fromHex aes_root.decryptHex key_record.encrypted_private_key
    
exports.WalletDb = WalletDb
