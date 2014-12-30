{Rpc} = require "../lib/rpc_json"
{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'
{PublicKey} = require '../../src/ecc/key_public'

PASSWORD = "Password00"
wallet_json_string = JSON.stringify require '../fixtures/wallet.json'
new_wallet_api= (rpc) ->
    # JSON.parse is used to clone (so internals can't change)
    wallet_object = JSON.parse wallet_json_string
    new WalletAPI(
        new Wallet (new WalletDb wallet_object), rpc
        rpc
    )

describe "Account", ->
    
    beforeEach ->
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
        
    afterEach ->
        @rpc.close()
    
    it "Create", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.unlock 9, PASSWORD
        wallet_api.account_create("test-alice").then (key)->
            PublicKey.fromBtsPublic key
            done()
        .done()
        
    it "Transfer to public address", (done) ->
        ### All accounts default to init0 as there mail server
        wallet_account_create init0
        wallet_account_register init0 delegate0 {"mail_server_endpoint":"127.0.0.1:45000"}
        ###
        wallet_api = new_wallet_api @rpc
        wallet_api.unlock 9, 'Password00'
        # bob has a withdraw signature transaction in the wallet.json
        wallet_api.account_create("test-angle").then (key)->
            console.log key
            address = PublicKey.fromBtsPublic(key)
            wallet_api.wallet_transfer_to_address(
                amount = 10000
                asset = "XTS"
                from = "delegate0"
                to_address = address.toBtsAddy()
                memo_message = "test"
                vote_method = ""#vote_recommended"
            ).then (trx) ->
                EC.throw 'expecting transaction' unless trx
                console.log trx
                done()
            .done()
        .done()
        
    
    it "Register", (done) ->
        wallet_api = new_wallet_api @rpc
        wallet_api.unlock 9, 'Password00'
        # bob has a withdraw signature transaction in the wallet.json
        wallet_api.account_register(
            account_name = "test-bob"
            pay_from_account = "test-bob"
            public_data = { url:'bobsbarricades' }
            delegate_pay_rate = -1
            account_type = "titan_account"
        ).then (trx)=>
            EC.throw 'expecting transaction' unless trx
            console.log trx
            done()
        .done()
    
    ###
    it "dump_private_key", ->
        WalletDb.delete "default"
        entropy = secureRandom.randomUint8Array 1000
        Wallet.add_entropy new Buffer entropy
        @wallet_api.create "default", PASSWORD
        @wallet_api.account_create('newname').then( =>
            private_key_hex = @wallet_api.dump_private_key 'newname'
            console.log private_key_hex
            EC.throw 'expecting private_key_hex' unless private_key_hex
        ).done()
    ###