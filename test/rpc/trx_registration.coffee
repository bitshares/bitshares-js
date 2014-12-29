{Rpc} = require "../lib/rpc_json"
{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'
wallet_json_string = JSON.stringify require '../fixtures/wallet.json'

PASSWORD = "Password00"

#wallet_api:->
    

describe "Account", ->
    
    beforeEach ->
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
        
    afterEach ->
        @rpc.close()
    
    it "Create", (done) ->
        wallet_object = JSON.parse wallet_json_string
        wallet_api = new WalletAPI(
            new Wallet (new WalletDb wallet_object), @rpc
            @rpc
        )
        wallet_api.unlock 9, 'Password00'
        wallet_api.account_create("mycat").then (key)->
            console.log key
            done()
        .done()
    
    ###
    it "Register", (done) ->
        wallet_object = JSON.parse wallet_json_string
        wallet_api = new WalletAPI(
            new Wallet (new WalletDb wallet_object), @rpc
            @rpc
        )
        wallet_api.unlock 9, 'Password00'
        wallet_api.account_create("mycat").then (key)->
            console.log key
        wallet_api.wallet.account_register(
            account_name = "mycat"
            pay_from_account = "delegate0"
            public_data = { url:'mycat.org' }
            delegate_pay_rate = -1
            account_type = "titan_account"
        ).then (trx)->
            console.log tx
            EC.throw 'expecting transaction' unless tx
            done()
        .done()
    ###
        