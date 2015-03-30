{Rpc} = require "../lib/rpc_json"
{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'
{PublicKey} = require '../../src/ecc/key_public'

secureRandom = require 'secure-random'

PASSWORD = "Password00"
PAY_FROM = "delegate0" #(if p=process.env.PAY_FROM then p else "delegate0")

TestUtil = require './test_util'
new_wallet_api=TestUtil.new_wallet_api

### 
TODO: mail

All accounts default to init0 as there mail server
wallet_account_create init0
wallet_account_register init0 delegate0 {"mail_server_endpoint":"127.0.0.1:45000"}
###

describe "Wallet", ->
    
    beforeEach (done)->
        RPC_DEBUG=process.env.RPC_DEBUG
        RPC_DEBUG=off if RPC_DEBUG is undefined
        @rpc=new Rpc(RPC_DEBUG, 45000, "localhost", "test", "test")
    
    afterEach ->
        @rpc.close()
    
    it "dump_private_key", ->
        wallet_api = new_wallet_api @rpc
        private_key_hex = wallet_api.dump_private_key 'delegate0'
        EC.throw 'expecting private_key_hex' unless private_key_hex
    
    
    it "wallet_create", ->
        WalletDb.delete 'TestWallet'
        entropy = secureRandom.randomUint8Array 1000
        Wallet.add_entropy new Buffer entropy
        Wallet.create 'TestWallet', PASSWORD, brain_key=null, save=true
        WalletDb.delete 'TestWallet'
    
    it "wallet_transfer base asset", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.transfer(10, 'XTS', 'delegate0', 'delegate0').then(
            (trx)->
                throw new Error 'missing trx' unless trx?.trx
                done()
        ).done()
    
    it "wallet_transfer bit asset", (done) ->
        unless require '/tmp/wallet'
            throw new Error "this test requires a wallet /tmp/wallet.json with an account 'frog' and some bit USD"
        
        wallet_api = new_wallet_api @rpc, '/tmp/wallet'
        wallet_api.transfer(1, 'USD', 'frog', 'frog').then(
            (trx)->
                throw new Error 'missing trx' unless trx?.trx
                done()
        ).done()
    
    
    #it "wallet_transfer_to_address (public)", (done) ->
    #    wallet_api = new_wallet_api @rpc
    #    address = "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj" # delegate1
    #    wallet_api.transfer_to_address(
    #        amount = 10000
    #        asset = "XTS"
    #        from = PAY_FROM
    #        to_address = address
    #        memo_message = "test"
    #        vote_method = ""#vote_recommended"
    #    ).then (trx) ->
    #        EC.throw 'expecting transaction' unless trx
    #        #console.log trx
    #        done()
    #    .done()
    
    #wallet_transfer=(wallet_api, data)->
    #    console.log "\twallet_transfer "+(JSON.stringify data)
    #    wallet_api.transfer(
    #        data.amount
    #        data.asset
    #        data.from
    #        data.to
    #        data.memo
    #        data.vote
    #    ).then (trx) ->
    #        EC.throw 'expecting transaction' unless trx
    #        #console.log trx
    #    .done()