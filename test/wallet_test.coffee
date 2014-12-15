{Wallet} = require '../src/wallet/wallet'
{WalletDb} = require '../src/wallet/wallet_db'
{WalletAPI} = require '../src/client/wallet_api'

wallet_object = require './fixtures/wallet.json'
wallet_object = require '../testnet/config/wallet.json'

describe "Wallet API", ->
    
    before ->
        @wallet_db = new WalletDb wallet_object, "default"
        @wallet = Wallet.fromWalletDb @wallet_db
        @wallet_api = new WalletAPI(@wallet)
    
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
        
    it "validate_password", (done) ->
        @wallet_api.validate_password("Wrong Password").then(
            (result)->
                throw "wrong password verified"
            (error)=>
                @wallet_api.validate_password(correct_password = "Password00").then(
                    (result)->
                        done()
                    (error)->
                        console.log error
                        throw "correct password did not verify"
                ).done()
        ).done()