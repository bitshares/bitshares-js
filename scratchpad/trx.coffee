assert = require("assert")

wallet = require '../src/wallet'
Wallet = wallet.Wallet

ecc = require '../src/ecc'
Aes = ecc.Aes
#Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
PublicKey = ecc.PublicKey
Address = ecc.Address
ExtendedAddress = ecc.ExtendedAddress

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
    #now = now.replace /[-:]/g, ''
    now = now.split('.')[0]
    
wallet_object = require './wallet.json'
wallet = Wallet.fromObject wallet_object
wallet.unlock(Aes.fromSecret('Password00'))

describe "Transfer", ->
    
    before ->
        #@rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
        
    after ->
        #@rpc.close()
    
    it "Spend money", () ->
        
        # spendable input, from an inbound transaction
        wc_in = WithdrawCondition.fromJson
            asset_id: 0
            delegate_slate_id: 0
            type: "withdraw_signature_type"
            data: 
                owner: "XTSNZ7sc75utzEyYWsdrZzgBhptekCZYPtYf"
                memo: 
                    one_time_key: "XTS6aHoVM1Br6SL6gtTLodmiUA4RneAuNBw6HpLgVpf1jbeu6Mc9U"
                    encrypted_memo_data: "a6f124521af6140acb310659261ab5845dcee4cd8376397cbd859d3dc30dbaa10927beb629f34e1dfeb287a4c66adb53ea79c6b1c2b37f3de68ab701f15f7ea0"
        
        balance_id = Address.fromBuffer(wc_in.toBuffer()).toString()
        #console.log balance_id
        
        amount = 10 * (100000)
        fee = .5 * (100000)
        
        sender_private = wallet.getActiveKeyPrivate "alice"
        payer_private = wallet.getActiveKeyPrivate "alice"
        
        
        one_time_key = (seq) ->
            sender_extended = ExtendedAddress.private_key sender_private, seq
            sender_extended.toPublicKey()
        one_time_key = one_time_key(23)
        
        owner = ->
            S_public_key = ExtendedAddress.deriveS_PublicKey sender_private, one_time_key
            S_public_key.toBuffer()
        owner = owner()
        
        wc_out =
            asset_id: 0
            delegate_slate_id: 0
            type: 'withdraw_signature_type'
            data:
                owner: Address.fromBuffer(owner).toString()
                memo:
                    one_time_key: one_time_key.toBtsPublic()
                    encrypted_memo_data: ''
        
        wc = WithdrawCondition.fromJson wc_out
        
        
        spend_trx =
            expiration: time(60)
            delegate_slate_id: null
            operations: [
                type: 'deposit_op_type'
                data:
                    amount: amount
                    condition: wc_out
            
            ,
                type: 'withdraw_op_type'
                data:
                    balance_id: balance_id
                    amount: amount + fee
                    claim_input_data: ""
            ]
            signatures: [
                ""
            ]
            
        console.log JSON.stringify spend_trx, undefined, 4
        ###
        deposit_asset = (payer, recipient, amount) ->
            throw "Can only deposit positive amount" if amount.amount <= 0
            # slate_id = wallet.select_slate(trx, amount.asset_id, vote_method)
            memo_sender = payer.active_key
        ###

