var assert = require('assert')
var Bitshares = require('../src/index');
var base58=require('bs58')
var BtsKey = Bitshares.BtsKey;
var BtsWallet = new Bitshares.BtsWallet({
    'rpc' : {
        'url' : 'http://localhost:5680/rpc',
        'user' : 'user',
        'password' : 'password'
    }
});

// https://github.com/BitShares/bitshares_toolkit/blob/master/libraries/api/wallet_api.json

// describe('Toolkit', function() { before(function(done) {startServer see
// README.md; done()})
// ...Unlocked Wallet API
// ...
// })

describe('Wallet', function() {

    /*
     * Create a wallet for this group of tests. Since there was no API call to
     * delete a wallet, this is making a new randomly named wallet for the
     * entire group of tests.
     *
     * <br>This does not require secure random numbers.
     */
    var WALLET_NAME = 'a'+Math.random().toString(36).substring(7)+'a';

    before(function() {
        BtsWallet.api.create(WALLET_NAME,'password1')
        .then(function() {
            BtsWallet.api.open(WALLET_NAME)
        }).then(function() {
            BtsWallet.api.unlock(99,'password1')
        }).done()
    }) 

    after(function() {
        BtsWallet.api.lock().then(function(){
            BtsWallet.api.close().done()
        })
    })
 
    it('wallet_account_create', function() {
        BtsWallet.api.account_create('account1', 'extra private data').then(function (public_key){
            //console.log('new account1 public key: '+public_key)
            assert(public_key.indexOf("XTS")==0)
        }).done()
    })

    it('wallet_import_private_key', function() {
        var btsKey = BtsKey.makeRandom();
        var priv = btsKey.toWIF().toString()
        BtsWallet.api.import_private_key(priv,'account2',true,false).then(function (acct){
            //console.log("imported private key=" + priv+" to account "+acct)
            assert.equal(acct,"account2")
        }).done()
    })

    it('wallet_import_private_key invalid', function(done) {
        var btsKey = BtsKey.makeRandom()
        var priv = new Buffer(btsKey.toWIF().toString())
        priv.write('a', 7)
        priv.write('a', 8)
        priv.write('a', 9)
        BtsWallet.api.import_private_key(priv.toString(), 'account3',true,false).
        catch(function(err){
            //this must happen, the key was invalid
            done()
        }).done()
    })
    
})

