{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'

secureRandom = require 'secure-random'
q = require 'q'

PASSWORD = "Password00"
XTS_CHAIN="74cef39d88afd6123d40c5822632b753e5b25da6ca196218c2364560bbf3171f"

class TestUtil
    
    relay_node=
        chain_id: XTS_CHAIN
        network_fee_amount:10000
        relay_fee_amount:10000
        base_symbol:->"XTS"
        init:->
            defer=q.defer()
            defer.resolve()
            defer.promise
    
    TestUtil.new_wallet_api= (
        rpc, backup_file = '../../testnet/config/wallet.json'
    ) ->
        wallet_api = new WalletAPI rpc, rpc, relay_node
        if backup_file
            wallet_json_string = JSON.stringify require backup_file
            # JSON.parse is used to clone (so internals can't change)
            wallet_object = JSON.parse wallet_json_string
            wallet_api._open_from_wallet_db new WalletDb wallet_object
        else
            throw new Error 'not used...'
            # create an empty wallet
            entropy = secureRandom.randomUint8Array 1000
            Wallet.add_entropy new Buffer entropy
            wallet_db = Wallet.create 'TestWallet', PASSWORD, "nimbose uplick refight staup yaird hippish unpaved couac doum setule", save=false
            wallet_api._open_from_wallet_db wallet_db
        (# avoid a blockchain deterministic key conflit
            rnd = 0
            rnd += i for i in secureRandom.randomUint8Array 1000
            wallet_api.wallet.wallet_db.set_child_key_index rnd, save = false
        )
        # unlock manually, avoids all the polling
        wallet_api.wallet.aes_root = Aes.fromSecret PASSWORD
        wallet_api

module.exports=TestUtil