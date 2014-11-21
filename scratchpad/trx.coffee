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

# Remove when this is a real ua test
rpc_on = off

# Remove when this is a real ua test
# to get comparable keys and data, match these with data from the  
# bitshares_client transaction (see wallet backup delegate0)
child_account_index = 1
enc_memo_hex = ""

describe "Transfer", ->
    
    before ->
        @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test") if rpc_on
        
    after ->
        @rpc.close() if rpc_on
    
    it "Send TITAN", (done) ->
        
        sender_private = wallet.getActiveKeyPrivate "delegate0"
        receiver_public = wallet.getActiveKey "delegate1"
        
        # blockchain_list_balances [where owner = delegate0]
        # TODO, lookup with RPC calls so user can spend initial genesis claim
        balance_id = Address.fromString("XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP")
        
        child_account_index = 10005
        enc_memo_hex = "a830da651e9fd0785d5eccb656d7ea9b5c3c39dc0e928981cd84cde8bf4e67f8ff605959c8f0b781142c03232c76fc104492debe1845e27316eb950b43248bc9"
        
        amount = 2 * (100000)
        signed_transaction = titan_trx(sender_private, receiver_public, amount, balance_id)
        signed_transaction.toJson(trx_signed = {})
        console.log JSON.stringify trx_signed, undefined, 4
        
        # only needed to spend later, but this is a good place to check it
        check_balance_id = ->
            # new spendable input, from the transaction
            deposit = signed_transaction.transaction.operations[0].operation
            wc = deposit.withdraw_condition
            balid = Address.fromBuffer(wc.toBuffer())
            assert.equal "XTS5bJNzfPVQxEahXp28H85hnL9GvdbiHdPf", balid.toString()
        check_balance_id()
        
        if rpc_on
            @rpc.run("blockchain_broadcast_transaction", [trx_signed]).then (result) ->
                done()
        else
            done()
    
    it "Re-send TITAN", (done) ->
        
        sender_private = wallet.getActiveKeyPrivate "delegate1"
        receiver_public = wallet.getActiveKey "delegate0"
        
        child_account_index = 10002
        enc_memo_hex = "e387a340b7e4d0b81d7d50c9a00a7eaa7750dce8f91650a69a7a46008e7b70ec209f9ec136ffedec476bc0227b4ecac4df0c78c7530bf83205194a67e020e9d3"
        
        amount = 1 * (100000)
        
        # balance_id from initial Send (above)
        balance_id = Address.fromString("XTS7iavfWWphLEJpACiJaiwXDFiRSw1M81Bw")
        
        signed_transaction = titan_trx(sender_private, receiver_public, amount, balance_id)
        signed_transaction.toJson(trx_signed = {})
        console.log JSON.stringify trx_signed, undefined, 4
        
        if rpc_on
            @rpc.run("blockchain_broadcast_transaction", [trx_signed]).then (result) ->
                done()
        else
            done()
        
titan_trx = (sender_private, receiver_public, amount, balance_id) ->
    fee = .5 * (100000)
    otk_private = ExtendedAddress.private_key sender_private, child_account_index
    console.log 'one_time_private_key',otk_private.toHex()
    owner = ExtendedAddress.derivePublic_outbound otk_private, receiver_public
    
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
    enc_memo = new Buffer(enc_memo_hex, 'hex')

    
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
    #dkey = ExtendedAddress.deriveS_PublicKey sender_private, owner.public_key
    #console.log dkey.private_key.toHex()
    new SignedTransaction(
        transaction
        [ 
            Signature.signBuffer trx_sign, sender_private
        ]
    )
    