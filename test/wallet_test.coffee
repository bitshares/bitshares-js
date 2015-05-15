{Wallet} = require '../src/wallet/wallet'
{WalletDb} = require '../src/wallet/wallet_db'
{WalletAPI} = require '../src/client/wallet_api'
{TransactionLedger} = require '../src/wallet/transaction_ledger'
{ChainInterface} = require '../src/blockchain/chain_interface'
{Storage} = require '../src/common/storage'
wallet_object = require '../testnet/config/wallet.json'
EC = require('../src/common/exceptions').ErrorWithCause
secureRandom = require 'secure-random'
config = require '../src/config'

# cloneable
wallet_object_string = JSON.stringify wallet_object
PASSWORD = "Password00"

describe "Wallet API (non-RPC)", ->
    
    beforeEach ->
        # create / reset in ram
        wallet_object = JSON.parse wallet_object_string
        @wallet_db = new WalletDb wallet_object, "default"
        @relay=
            relay_fee_collector: null
            relay_fee_amount: 50000
            network_fee_amount: 200000
            base_asset_symbol: 'XTS'
            chain_id: config.chain_id
            
        @wallet_api = new WalletAPI null, null, @relay
        @wallet_api._open_from_wallet_db @wallet_db
        
    afterEach ->
        # delete from persistent storage if exists
        try
            WalletDb.delete "default"
    
    it "backup_restore_object", (done) ->
        try
            WalletDb.delete "default" # prior run failed
        wallet_db = @wallet_api.backup_restore_object wallet_object, "default"
        unless wallet_db and wallet_db.wallet_name
            EC.throw 'missing wallet_db'
        try
            @wallet_api.backup_restore_object wallet_object, "default"
            EC.throw 'allowed to restore over existing wallet'
        catch error
            unless error.key is 'jslib_wallet.exists'
                EC.throw 'expecting error: jslib_wallet.exists', error
            WalletDb.delete wallet_db.wallet_name
            done()

    # Brain-key only
    #it "create password wallet", ->
    #    try
    #        WalletDb.delete "default"
    #    entropy = secureRandom.randomUint8Array 1000
    #    Wallet.add_entropy new Buffer entropy
    #    try
    #        @wallet_api.create "default", PASSWORD
    #        unless @wallet_api.wallet.master_private_key()
    #            EC.throw "Unable to create master key"
    #    finally
    #        WalletDb.delete "default"
    
    it "wallet create and open", (done) ->
        @wallet_db.save()
        try
            @wallet_api.open("WalletNotFound")
            EC.throw 'opened wallet that does not exists'
        catch error
            unless error.key is 'jslib_wallet.not_found'
                EC.throw 'Expecting jslib_wallet.not_found', error
            try
                @wallet_api.open("default")
                unless @wallet_db.wallet_name is "default"
                    EC.throw "Expecting wallet named default"
                
                WalletDb.delete "default"
                done()
            catch error
                EC.throw 'failed to open existing wallet', error
    
    it "validate_password", (done) ->
        try
            @wallet_api.validate_password("Wrong Password")
            EC.throw "wrong password verified"
        catch error
            unless error.key is 'jslib_wallet.invalid_password'
                EC.throw 'Expecting jslib_wallet.invalid_password', error
            try
                @wallet_api.validate_password(correct_password = PASSWORD)
                done()
            catch error
                EC.throw "correct password did not verify", error
        
    it "decrypted master_private_key", ->
        @wallet_api.unlock(2, PASSWORD)
        master_key = @wallet_api.wallet.master_private_key()
        EC.throw "missing master key" unless master_key
        
    it "unlock", (done) ->
        try
            @wallet_api.unlock(2, "Wrong Password")
            EC.throw 'allowed to unlock with wrong password'
        catch error
            unless error.key is 'jslib_wallet.invalid_password'
                EC.throw 'Expecting jslib_wallet.invalid_password', error
            try
                @wallet_api.unlock(2, PASSWORD)
                done()
            catch error
                EC.throw 'unable to unlock with the correct password', error
    
    it "lock", ->
        @wallet_api.unlock(2, PASSWORD)
        @wallet_api.lock()
        EC.throw "Wallet should be locked" unless @wallet_api.locked()
        EC.throw "Locked wallet should not have an AES object" if @wallet_api.root_aes
        
    it "store and retrieve settings", ->
        @wallet_api.set_setting "key", "value"
        setting = @wallet_api.get_setting "key"
        EC.throw "Setting mismatch" unless setting.value is "value"
    
    it "list accounts", ->
        accounts = @wallet_api.list_accounts()
        EC.throw "No accounts" unless accounts or accounts.length > 0
    
    it "list my accounts", ->
        accounts = @wallet_api.list_my_accounts()
        EC.throw "No accounts" unless accounts or accounts.length > 0
    
    it "has local storage", ->
        storage = new Storage "namespace"
        storage.setItem 'key', 'value'
        value = storage.getItem 'key'
        throw new Error 'failed to save value' unless value is 'value'
    
    #it "recover's account by name", ->
    #    @wallet_api.create "default", PASSWORD, "brainkey                            "
    #    @wallet_api.account_recover "jtest3"
    
    ###
    it "create brain-key wallet", ->
        # exception in wallet.coffee: throw 'Brain keys have not been tested with the native client'
        phrase = "Qtn3E@gU-BrainKey https://www.grc.com/passwords.htm UfN71K&rS&VdqVE" 
        try
            @wallet_api.create "default", PASSWORD, phrase
        finally
            WalletDb.delete "default"
    ###
    
    
    
