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

describe "Account", ->
    
    beforeEach (done)->
        RPC_DEBUG=process.env.RPC_DEBUG
        RPC_DEBUG=off if RPC_DEBUG is undefined
        @rpc=new Rpc(RPC_DEBUG, 45000, "localhost", "test", "test")
    
    afterEach ->
        @rpc.close()
    
    it "list_accounts", (done) ->
        suffix = secureRandom.randomBuffer(2).toString 'hex'
        wallet_api = new_wallet_api @rpc
        wallet_api.account_create("newaccount-"+suffix).then (key)->
            accounts = wallet_api.list_accounts()
            if accounts.length is 0
                throw new Error "could not fetch any accounts"
            
            for account in accounts
                if account.name is "newaccount-"+suffix
                    done()
                    return
            
            throw new Error "list_accounts did not return a new account"
        .done()
    
    it "account_create", (done) ->
        suffix = secureRandom.randomBuffer(2).toString 'hex'
        wallet_api = new_wallet_api @rpc
        wallet_api.account_create("newaccount-"+suffix).then (key)->
            PublicKey.fromBtsPublic key
            account = wallet_api.get_account "newaccount-"+suffix
            throw new Error "could not fetch new account" unless account
            wallet_api.account_create("newaccount-"+suffix).then (key)->
                throw new Error "allowed to create an account that already exists"
            ,(error)->
                done()
            
        .done()
    
    it "account_transaction_history", (done) ->
        @timeout 10*1000
        wallet_api = new_wallet_api @rpc
        wallet_api.chain_database.sync_transactions().then ()->
            wallet_api.account_transaction_history(wallet_api.aes_root).then (history)->
                throw new Error 'no history' unless history?.length > 0
                done()
        .done()
    
    it "account_register", (done) ->
        wallet_api = new_wallet_api @rpc#, '../fixtures/del.json'
        suffix = secureRandom.randomBuffer(2).toString 'hex'
        @timeout 10*1000
        try
            wallet_api.account_create("bob-" + suffix).then (key)->
                wallet_api.account_register(
                    account_name = "bob-" + suffix
                    pay_from_account = PAY_FROM
                    public_data = null#{data:'value'}
                    delegate_pay_rate = -1
                    account_type = "public_account"
                ).then (trx)=>
                    EC.throw 'expecting transaction' unless trx
                    #console.log trx
                    done()
                .done()
        catch ex
            console.log 'ex',ex
    
    it "account_balance (none)", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.account_balance("account_does_not_exist").then (balances)->
            unless balances?.length is 0
                throw new Error 'expecting empty array'
            done()
        .done()
    
    it "account_balance (single)", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.account_balance("delegate0").then (balances)->
            #console.log '... balances',JSON.stringify balances,null,1
            unless balances?[0]?[0] is "delegate0"
                throw new Error('invalid')
            done()
        .done()
    
    it "account_balance (multiple)", (done) ->
        wallet_api = new_wallet_api @rpc
        @timeout 10*1000
        wallet_api.account_balance().then (balances)->
            #console.log '... balances',JSON.stringify balances,null,1
            unless balances[0]?.length > 1
                throw new Error('invalid')
            
            done()
        .done()
    