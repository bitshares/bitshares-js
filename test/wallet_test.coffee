{Wallet} = require '../src/wallet/wallet'
{WalletDb} = require '../src/wallet/wallet_db'
{WalletAPI} = require '../src/client/wallet_api'

wallet_object = require './fixtures/wallet.json'
EC = require('../src/common/exceptions').ErrorWithCause

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
        @wallet_api.backup_restore_object(wallet_object, "default").then(
            (wallet_db)=>
                unless wallet_db and wallet_db.wallet_name
                    throw 'missing wallet_db'
                
                @wallet_api.backup_restore_object(wallet_object, "default").then(
                    (result) ->
                        throw 'allowed to restore over existing wallet'
                    (error) ->
                        unless error.key is 'wallet.already_exists'
                            throw 'expecting error: wallet.already_exists' 
                        WalletDb.delete wallet_db.wallet_name
                        done()
                ).done()
        ).done()
    
    it "save", () ->
        @wallet_db.save()
        throw "Could not open wallet after save" unless WalletDb.open "default"
    
    ## Why does "open" break the "lock" test?
    it "open", (done) ->
        @wallet_db.save()
        @wallet_api.open("WalletNotFound").then(
            (result)->
                throw 'opened wallet that does not exists'
            (error)=>
                unless error.key is 'wallet.not_found'
                    throw 'Expecting wallet.not_found'
                @wallet_api.open("default").then(
                    (result)->
                        unless result.wallet_db.wallet_name is "default"
                            throw "Expecting wallet named default"
                        
                        WalletDb.delete "default"
                        done()
                    (error)->
                        EC.throw 'failed to open existing wallet', error
                ).done()
        ).done()
    ####
    it "validate_password", (done) ->
        @wallet_api.validate_password("Wrong Password").then(
            (result)->
                throw "wrong password verified"
            (error)=>
                @wallet_api.validate_password(correct_password = "Password00").then(
                    (result)->
                        done()
                    (error)->
                        EC.throw "correct password did not verify", error
                ).done()
        ).done()
        
    it "unlock", (done) ->
        @wallet_api.unlock(2, "Wrong Password").then(
            (result)->
                throw 'allowed to unlock with wrong password'
            (error)=>
                @wallet_api.unlock(2, "Password00").then(
                    (result)->
                        done()
                    (error)->
                        EC.throw 'unable to unlock with the correct password', error
                ).done()
        ).done()
            
    it "lock", (done) ->
        @wallet_api.lock().then(()=>
            throw "Wallet should be locked" unless @wallet.locked()
            done()
        ).done()
        