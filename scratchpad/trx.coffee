assert = require("assert")

wallet = require '../src/wallet'
Wallet = wallet.Wallet
config = require '../src/config'

ecc = require '../src/ecc'
Aes = ecc.Aes
Signature = ecc.Signature
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
        @rpc_on = on
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test") if @rpc_on
        
    after ->
        @rpc.close() if @rpc_on
    
    it "Spend money", () ->
        
        # spendable input, from an inbound transaction
        ###
        balance_id = ->
            wc_in = WithdrawCondition.fromJson
                asset_id: 0
                delegate_slate_id: 0
                type: "withdraw_signature_type"
                data: 
                    owner: "XTSNZ7sc75utzEyYWsdrZzgBhptekCZYPtYf"
                    memo: 
                        one_time_key: "XTS6aHoVM1Br6SL6gtTLodmiUA4RneAuNBw6HpLgVpf1jbeu6Mc9U"
                        encrypted_memo_data: "a6f124521af6140acb310659261ab5845dcee4cd8376397cbd859d3dc30dbaa10927beb629f34e1dfeb287a4c66adb53ea79c6b1c2b37f3de68ab701f15f7ea0"
            
            Address.fromBuffer(wc_in.toBuffer())
        balance_id = balance_id()
        ###
        balance_id = Address.fromString("XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP")
        console.log 'balance_id_string',balance_id.toString()
        
        amount = 1 * (100000)
        fee = .5 * (100000)
        
        sender_private = wallet.getActiveKeyPrivate "delegate0"
        receiver_public = wallet.getActiveKey "delegate1"
        #console.log 'receiver_public', receiver_public.toHex()
        
        otk_private = ExtendedAddress.private_key sender_private, 10001
        console.log 'one_time_private_key',otk_private.toHex()
        otk_derived = ExtendedAddress.derivePublic_outbound otk_private, receiver_public
        owner = otk_derived
        
        #console.log 'secret_ext_public_key\t',owner.toHex()
        console.log 'owner\t',Address.fromBuffer(owner.toBuffer()).toString()
        
        one_time_key = otk_private.toPublicKey()
        console.log 'one_time_key',one_time_key.toBtsPublic()
        
        #S_sender = ExtendedAddress._deriveS_PublicKey sender_private, one_time_key
        #console.log 'owner2\t',Address.fromBuffer(S_sender.toBuffer()).toString()
        
        #aes = Aes.fromSha512((hash.sha512 otk_private.sharedSecret receiver_public.toUncompressed()).toString('hex'))
        #encrypted_memo_data = aes.encrypt(new Buffer(''))

        ###
        wc_out =
            asset_id: 0
            delegate_slate_id: 0
            type: 'withdraw_signature_type'
            data:
                owner: owner
                memo:
                    one_time_key: one_time_key.toBtsPublic()
                    encrypted_memo_data: new Buffer("")
        
        wc = WithdrawCondition.fromJson wc_out
        ###
        enc_memo = new Buffer("", 'hex')

        
        exp = new Date()
        exp.setSeconds(exp.getSeconds() + (60 * 60 * 24))
        
        # removing seconds causes the epoch value 
        # the time_point_sec conversion Math.ceil(epoch / 1000)
        # to always come out as a odd number.  With the 
        # seconds, the result will always be even and 
        # the transaction will not be valid (missing signature)
        exp = new Date(exp.toISOString().split('.')[0])
        
        wc = new WithdrawCondition(
            asset_id = 0, 
            delegate_slate_id=0, 
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType(
                Address.fromBuffer(owner.toBuffer()).toBuffer()
                one_time_key
                encrypted_memo_data = enc_memo
            )
        )
        
        operations = []
        
        deposit = new Deposit(
            amount
            wc
        )
        withdraw = new Withdraw(
            balance_id.toBuffer()
            amount + fee
            claim_input_data=new Buffer("")
        )
        
        operations.push new Operation deposit.type_id, deposit
        operations.push new Operation withdraw.type_id, withdraw
        
        transaction = new Transaction(
            expiration = exp.getTime()
            delegate_slate_id = null
            operations
        )
        
        trx_sign = ->
            trx_buffer = transaction.toBuffer()
            chain_id_buffer = new Buffer(config.chain_id, 'hex')
            Buffer.concat([trx_buffer, chain_id_buffer])
        trx_sign = trx_sign()
        console.log 'digest',hash.sha256(trx_sign).toString('hex')
        console.log 'sign key sender_private',sender_private.toHex()
        #dkey = ExtendedAddress.deriveS_PublicKey sender_private, otk_derived.public_key
        #console.log dkey.private_key.toHex()
        signed_transaction = new SignedTransaction(
            transaction
            [ 
                Signature.signBuffer trx_sign, sender_private
            ]
        )
        signed_transaction.toJson(trx_signed = {})
        console.log JSON.stringify trx_signed, undefined, 4

        @rpc.run "blockchain_broadcast_transaction", [trx_signed] if @rpc_on
