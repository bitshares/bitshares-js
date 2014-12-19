{Wallet} = require '../src/wallet/wallet'
{WalletDb} = require '../src/wallet/wallet_db'
{WalletAPI} = require '../src/client/wallet_api'

wallet_object = require './fixtures/wallet.json'
EC = require('../src/common/exceptions').ErrorWithCause

secureRandom = require 'secure-random'

describe "Wallet API", ->
    
    before ->
        # create / reset in ram
        @wallet_db = new WalletDb wallet_object, "default"
        @wallet = Wallet.fromWalletDb @wallet_db
        @wallet_api = new WalletAPI(@wallet)
        
    after ->
        # delete from persistent storage if exists
        WalletDb.delete "default"
    
    it "backup_restore_object", (done) ->
        WalletDb.delete "default" # prior run failed
        wallet_db = @wallet_api.backup_restore_object(wallet_object, "default")
        unless wallet_db and wallet_db.wallet_name
            throw 'missing wallet_db'
        try
            @wallet_api.backup_restore_object(wallet_object, "default")
            throw 'allowed to restore over existing wallet'
        catch error
            unless error.key is 'wallet.exists'
                throw 'expecting error: wallet.exists' 
            WalletDb.delete wallet_db.wallet_name
            done()

    
    it "save", ->
        @wallet_db.save()
        unless WalletDb.open "default"
            throw "Could not open wallet after save"
    
    it "open", (done) ->
        @wallet_db.save()
        try
            @wallet_api.open("WalletNotFound")
            throw 'opened wallet that does not exists'
        catch error
            unless error.key is 'wallet.not_found'
                throw 'Expecting wallet.not_found'
            try
                @wallet_api.open("default")
                unless @wallet_api.wallet_db.wallet_name is "default"
                    throw "Expecting wallet named default"
                
                WalletDb.delete "default"
                done()
            catch error
                EC.throw 'failed to open existing wallet', error
    
    it "validate_password", (done) ->
        try
            @wallet_api.validate_password("Wrong Password")
            throw "wrong password verified"
        catch error
            unless error.key is 'wallet.invalid_password'
                throw 'Expecting wallet.invalid_password'
            try
                @wallet_api.validate_password(correct_password = "Password00")
                done()
            catch error
                EC.throw "correct password did not verify", error
        
    it "unlock", (done) ->
        try
            @wallet_api.unlock(2, "Wrong Password")
            throw 'allowed to unlock with wrong password'
        catch error
            unless error.key is 'wallet.invalid_password'
                throw 'Expecting wallet.invalid_password'
            try
                @wallet_api.unlock(2, "Password00")
                done()
            catch error
                EC.throw 'unable to unlock with the correct password', error
    
    it "lock", ->
        @wallet_api.lock()
        throw "Wallet should be locked" unless @wallet.locked()
        throw "Locked wallet should not have an AES object" if @wallet.root_aes
        
    it "create password wallet", ->
        WalletDb.delete "default"
        entropy = secureRandom.randomUint8Array(1000)
        Wallet.add_entropy new Buffer entropy
        try
            @wallet_api.create "default", "Password00"
            #console.log @wallet_api.wallet.toJson 4
        finally
            WalletDb.delete "default"
       
    ###
    it "create brain-key wallet", ->
        # exception in wallet.coffee: throw 'Brain keys have not been tested with the native client'
        phrase = "Qtn3E@gU-BrainKey https://www.grc.com/passwords.htm UfN71K&rS&VdqVE" 
        try
            @wallet_api.create "default", "Password00", phrase
        finally
            WalletDb.delete "default"
    ###
    
    
    