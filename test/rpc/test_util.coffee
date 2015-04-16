{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'

secureRandom = require 'secure-random'
hash = require '../../src/ecc/hash'
config = require '../../src/config'
q = require 'q'

PASSWORD = "Password00"
XTS_CHAIN=config.chain_id

class TestUtil
    
    relay_node=
        chain_id: XTS_CHAIN
        network_fee_amount:25000
        relay_fee_amount:25000
        base_symbol:->"XTS"
        init:->
            defer=q.defer()
            defer.resolve()
            defer.promise
    
    TestUtil.new_wallet_api= (
        rpc, backup_file = '../../testnet/config/wallet.json'
    ) ->
        wallet_api = new WalletAPI rpc, rpc, relay_node
        #if backup_file
        wallet_json_string = JSON.stringify require backup_file
        # JSON.parse is used to clone (so internals can't change)
        wallet_object = JSON.parse wallet_json_string
        wallet_db = new WalletDb wallet_object
        wallet_api._open_from_wallet_db wallet_db
        
        aes_root = Aes.fromSecret PASSWORD
        # Unlock manually, avoids all the polling
        wallet_api.wallet.aes_root = aes_root
        # guest account aids in manual browser testing
        wallet_db.fake_account aes_root, hash.sha256 "123"
        
        #else
        #    throw new Error 'not used...'
        #    # create an empty wallet
        #    entropy = secureRandom.randomUint8Array 1000
        #    Wallet.add_entropy new Buffer entropy
        #    wallet_db = Wallet.create 'TestWallet', PASSWORD, "nimbose uplick refight staup yaird hippish unpaved couac doum setule", save=false
        #    wallet_api._open_from_wallet_db wallet_db
        
        #(# avoid a blockchain deterministic key conflit
        #    rnd = 0
        #    rnd += i for i in secureRandom.randomUint8Array 1000
        #    wallet_api.wallet.wallet_db.set_child_key_index rnd, save = false
        #)
        
        wallet_api
    
    TestUtil.after_block = (func)->
        setTimeout ->
            func().then().done()
        , config.BTS_BLOCKCHAIN_BLOCK_INTERVAL_SEC * 1000
    
    TestUtil.try_tryagain= (done, blocks=1, func)=>
        func().then (result)=>
            if result
                done()
            else
                setTimeout =>
                    func().then (result)=>
                        if result
                            done()
                        else
                            throw new Error "No results"
                    .done()
                , config.BTS_BLOCKCHAIN_BLOCK_INTERVAL_SEC * blocks * 1000
        .done()

module.exports=TestUtil