assert = require("assert")

wallet = require '../src/wallet'
Wallet = wallet.Wallet

ecc = require '../src/ecc'
Aes = ecc.Aes
#Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
PublicKey = ecc.PublicKey
Address = ecc.Address

base58 = require 'bs58'
hash = require '../src/ecc/hash'

blockchain = require '../src/blockchain'
types = blockchain.types
type_id = types.type_id
Deposit = blockchain.Deposit              
Operation = blockchain.Operation            
SignedTransaction = blockchain.SignedTransaction    
Transaction = blockchain.Transaction          
Withdraw = blockchain.Withdraw             
WithdrawCondition = blockchain.WithdrawCondition    
WithdrawSignatureType = blockchain.WithdrawSignatureType

{fp} = require '../src/common/fast_parser'
{Rpc} = require "./rpc_json"
q = require 'q'

time = (offset_seconds) ->
    now = new Date()
    now.setSeconds now.getSeconds() + offset_seconds if offset_seconds
    now = now.toISOString()
    now = now.replace /[-:]/g, ''
    now = now.split('.')[0]
    
wallet_object = require './wallet.json'
wallet = Wallet.fromObject wallet_object
wallet.unlock(Aes.fromSecret('Password00'))

describe "Transfer", ->
    
    before ->
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
        
    after ->
        @rpc.close()
    
    it "TITAN", () ->
        
        sender_name = "bob"
        sender_key = "XTS8cGETYv3mFHk5RTdUFsZuTU2YL7LT6VhBiCAECkNfFm1jFGjzn"
        
        recipient_name = "alice"
        recipient_key = "XTS6YqTQfZXg1fXEKAMJWxgrDYTUo2UYtK4ExYmSaiywCgFJx2QYF"
        console.log 'alice addy',PublicKey.fromBtsPublic(recipient_key).toBtsAddy()
        
        tim_key = "XTS7xoaCqFbbScs8ePLZPcSK79FXrx6ST9fRYKstjfuAhymQoT5dF"
        console.log 'tim addy',Address.fromBuffer(PublicKey.fromBtsPublic(tim_key).toBuffer()).toString()
        console.log 'tim addy',Address.fromString(tim_key).toString()
        
        sender_private = wallet.getActiveKeyPrivate(sender_name)
        
        wallet.getWithdrawConditions
        
        wc=new WithdrawCondition(
            asset_id=0, delegate_slate_id=0, type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType(
                owner=Address.fromString("XTSM18vHj46jfinuU8EgTnMNv41F3fGUngL1").toBuffer(), 
                one_time_key=PublicKey.fromBtsPublic("XTS695pKqchVQ7WswL3yTXXSNC7cE6awpAJirGPR5BDZw8cNyLQR9"),
                encrypted_memo=new Buffer("5d504b1d3c372c98544f2edd8d74e0d92db01d1917781bee3ae2d543426c74d24425232d89167bdb74aff4dde0c4aa7e66ba3c5f0c9b1a6e2c5471244be0706f", 'hex')
            )
        )
        assert.equal "XTSXz2eE3TAitHVfnPLoFNM74TdsbnhZJXD", Address.fromBuffer(wc.toBuffer()).toString()

        
        deposit_asset = (payer, recipient, amount) ->
            throw "Can only deposit positive amount" if amount.amount <= 0
            # slate_id = wallet.select_slate(trx, amount.asset_id, vote_method)
            memo_sender = payer.active_key

