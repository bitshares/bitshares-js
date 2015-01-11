hash = require '../ecc/hash'
LE = require('../common/exceptions').LocalizedException
EC = require('../common/exceptions').ErrorWithCause
config = require './config'
{Aes} = require '../ecc/aes'
{PublicKey} = require '../ecc/key_public'
{PrivateKey} = require '../ecc/key_private'
{ExtendedAddress} = require '../ecc/extended_address'
{WithdrawCondition} = require '../blockchain/withdraw_condition'

class WalletDb
    
    localStorage = window?.localStorage ||
        # WARNING: NodeJs get and set are not atomic
        # https://github.com/lmaccherone/node-localstorage/issues/6
        new (require('node-localstorage').LocalStorage)('./localstorage-bitshares-js')
            
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
                # It is awkward to update the account here.. 
                # probably not needed
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
        @account_address[data.account_address] = data
        
    index_property:(data)->
        @property[data.key] = data.value
        
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
        str = localStorage.getItem("wallet-" + wallet_name)
    
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
        wallet_string = localStorage.getItem "wallet-" + wallet_name
        return undefined unless wallet_string
        wallet_object = JSON.parse wallet_string
        new WalletDb wallet_object, wallet_name
    
    WalletDb.delete = (wallet_name)->
        localStorage.removeItem "wallet-" + wallet_name
        return
    
    master_private_key:(aes_root)->
        plainhex = aes_root.decryptHex @master_key.encrypted_key
        plainhex = plainhex.substring 0, 64
        PrivateKey.fromHex plainhex
    
    ###* @throws {QuotaExceededError} ###
    save: ->
        wallet_string = JSON.stringify @wallet_object, null, 0
        localStorage.setItem("wallet-" + @wallet_name, wallet_string)
        return
        
    ### This does not work with Date objects ###
    _clone:(obj)->
        JSON.parse JSON.stringify obj
    
    get_key_record:(public_key)->
        @key_record[public_key]
        ###
        bts_address = public_key.toBtsPublic()
        for entry in @wallet_object
            data = entry.data
            switch entry.type
                when "key_record_type"
                    return data if data.public_key is bts_address
        return
        ###
        
    get_setting: (key) ->
        @property[key]?.value or config.DEFAULT_SETTING[key]
    
    set_setting: (key, value, save = true) ->
        property = @property[key]
        if property
            property.value = value
            return
        
        index = @wallet_object[@wallet_object.length - 1].data.index
        throw "invalid index #{index}" unless /[0-9]+/.test index
        index += 1
        data=
            type: "property_record_type"
            data:
                index: index
                key: key
                value: value
        @index_property data
        @wallet_object.push data
        @save() if save
        @property[key] = data.data
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
        @_clone @get_setting "transaction_fee"
    
    list_accounts:->
        for entry in @wallet_object
            continue unless entry.type is "account_record_type"
            data = entry.data
            unless data["active_key"]
                hist = data.active_key_history
                hist = hist.sort (a,b)-> 
                    if a[0] < b[0] then -1 
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
        
    lookup_key:(account_address)-> #lookup_account
        @account_address[account_address]
        
    lookup_active_key:(account_name)->
        @account_activeKey[account_name]
        
    lookup_owner_key:(account_name)->
        @lookup_account(account_name).owner_key
        
    get_account_for_address:(public_key_string)-> #lookup_account
        @activeKey_account[public_key_string] or
        @ownerKey[public_key_string]
    
    #get_wallet_child_key:(aes_root, key_index)->
    #    master_key = @master_private_key aes_root
    #    ExtendedAddress.private_key master_key key_index
        
    generate_new_account:(aes_root, account_name, private_data, save = true)->
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
            encrypted_private_key: aes_root.encryptHex private_key.toHex()
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
            registration_date: null
            is_my_account: yes
        @set_child_key_index key_index, false
        @add_account_record account, false
        @add_key_record key, false
        @save() if save
        public_key_string
    
    add_account_record:(rec, save = true)->
        if @lookup_account rec.name
            EC.throw "Account already exists"
        @index_account rec
        @_append('account_record_type',rec)
        @save() if save
        return
        
    add_transaction_record:(rec, save = true)->
        @index_transaction rec
        @_append('transaction_record_type',rec)
        @save() if save
        return
    
    _wallet_index:(matches)->
        for i in [0...@wallet_object.length] by 1
            return i if matches @wallet_object[i]
    
    store_account_or_update:(account, save = true)-> #store_account
        EC.throw "missing account name" unless account.name
        EC.throw "missing owner key" unless account.owner_key
        # New accounts in the backups all use an id of 0
        account.id = 0 #last_account_index + 1
        existing = @lookup_account account.name
        if existing
            i = @_wallet_index (o)->
                o.type is "account_record_type" and o.data.name is account.name
            #console.log 'store_account_or_update', account.name,i
            @wallet_object[i] = account
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
    store_key:(key, save)->
       key_record = @lookup_key key.public_key.getBtsAddy()
       key_record = {} unless key_record
       @add_key_record key_record, save = off
       if key_record.encrypted_private_key
           account_record = @get_account_for_address key.public_key
           unless account_record
               account_record = @lookup_key key.account_address
           if account_record
               account_record_address = PublicKey.fromHex(account_record.owner_key).toBtsAddy()
               if key_record.account_address isnt account_record_address
                   throw 'address miss match'
               #    key_record.account_address = account_record_address
               #    @add_key_record key_record, save = off
               unless account_record.is_my_account
                   account_record.is_my_account = yes
                   @store_account_or_update account_record, save = off
       @save()
    
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
                break unless @account_address[child_address]
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
        console.log "#{ref}",JSON.stringify @wallet_object[@wallet_object.length - 1].data,null,4
        #console.log '... (new Error).stack',(new Error).stack
        return
    
    get_child_key_index:->
        index = @get_setting('next_child_key_index')?.value
        index = 0 unless index
        index
        
    set_child_key_index:(value, save = true)->
        @set_setting 'next_child_key_index', value, save
        
    get_transactions:->
        for entry in @wallet_object
            continue unless entry.type is "transaction_record_type"
            entry.data
            
    ###* @return {array} WithdrawCondition ###
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
                    console.log "WARN unsupported balance record #{balance.condition.type}"
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
