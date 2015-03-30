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

describe "Markets", ->
    
    beforeEach ()->
        RPC_DEBUG=process.env.RPC_DEBUG
        RPC_DEBUG=off if RPC_DEBUG is undefined
        @rpc=new Rpc(RPC_DEBUG, 45000, "localhost", "test", "test")
    
    afterEach ->
        @rpc.close()
    
    it "market_submit_short", (done) ->
        # wallet_market_submit_short delegate0 200 XTS 1 USD 0.01
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_short(
            "delegate0","200","XTS","1","USD","0.01"
        ).then (result)->
            console.log '... result', result
            done()
        .done()
    
    it "market_submit_ask", (done) ->
        # wallet_market_submit_ask delegate0 100 XTS 0.01 USD
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_ask(
            "delegate0","100","XTS","0.01","USD"
        ).then (result)->
            console.log '... result', result
            done()
        .done()
    
    it "market_submit_bid", (done) ->
        # wallet_market_submit_bid delegate0 0.01 USD 100 XTS
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_ask(
            "delegate0","100","XTS","0.01","USD"
        ).then (result)->
            console.log '... result', result
            done()
        .done()