{Rpc} = require "../lib/rpc_json"
{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'
{PublicKey} = require '../../src/ecc/key_public'

secureRandom = require 'secure-random'

PASSWORD = "Password00"
wallet_json_string = JSON.stringify require '../fixtures/wallet.json'
new_wallet_api= (rpc) ->
    # JSON.parse is used to clone (so internals can't change)
    wallet_object = JSON.parse wallet_json_string
    new WalletAPI(
        new Wallet (new WalletDb wallet_object), rpc
        rpc
    )
### 
TODO: mail

All accounts default to init0 as there mail server
wallet_account_create init0
wallet_account_register init0 delegate0 {"mail_server_endpoint":"127.0.0.1:45000"}
###

describe "Account", ->
    
    beforeEach ->
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
        
    afterEach ->
        @rpc.close()
    
    
    it "Transfer TITAN", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.unlock 9, PASSWORD
        wallet_api.transfer(100.500019, 'XTS', 'delegate2', 'delegate3').then(
            (trx)->
               console.log '... transactions::trx',JSON.stringify trx
               done()
       ).done()
   
    account_create=(name)->
        it "account_create "+name, (done) ->
            wallet_api = new_wallet_api @rpc
            wallet_api.unlock 9, PASSWORD
            wallet_api.account_create(name).then (key)->
                PublicKey.fromBtsPublic key
                done()
            .done()
    
    wallet_transfer_to_address=(data)->
        it "wallet_transfer_to_address (public)", (done) ->
            wallet_api = new_wallet_api @rpc
            wallet_api.unlock 9, PASSWORD
            address = "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj" # delegate1
            wallet_api.transfer_to_address(
                amount = 10000
                asset = "XTS"
                from = "delegate0"
                to_address = address
                memo_message = "test"
                vote_method = ""#vote_recommended"
            ).then (trx) ->
                EC.throw 'expecting transaction' unless trx
                #console.log trx
                done()
            .done()
    
    wallet_transfer=(wallet_api, data)->
        console.log "\twallet_transfer "+(JSON.stringify data)
        wallet_api.transfer(
            data.amount
            data.asset
            data.from
            data.to
            data.memo
            data.vote
        ).then (trx) ->
            EC.throw 'expecting transaction' unless trx
            #console.log trx
        .done()
   
    account_register=(data)->
        it "Register", (done) ->
            wallet_api = new_wallet_api @rpc
            wallet_api.unlock 9, PASSWORD
            try
                # bob has a withdraw signature transaction in the wallet.json
                wallet_api.account_register(
                    account_name = "bob"
                    pay_from_account = "bob"
                    public_data = { url:'bobsbarricades' }
                    delegate_pay_rate = -1
                    account_type = "titan_account"
                ).then( (trx)=>
                    EC.throw 'expecting transaction' unless trx
                    #console.log trx
                    done()
                ).done()
            catch ex
                console.log 'ex',ex
    
    it "dump_private_key", ->
        wallet_api = new_wallet_api @rpc
        wallet_api.unlock 9, PASSWORD
        private_key_hex = wallet_api.dump_private_key 'delegate0'
        EC.throw 'expecting private_key_hex' unless private_key_hex
    
    ###
    it "create a wallet", ->
        Wallet.delete 'TestWallet'
        entropy = secureRandom.randomUint8Array 1000
        Wallet.add_entropy new Buffer entropy
        Wallet.create 'TestWallet'
        Wallet.delete 'TestWallet'
    ###