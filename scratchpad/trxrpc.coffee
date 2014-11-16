assert = require("assert")
#ByteBuffer = require 'bytebuffer'

ecc = require '../src/ecc'
Aes = ecc.Aes
#Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
PublicKey = ecc.PublicKey
Address = ecc.Address

#types = require '../src/blockchain/types'
#config = require '../src/config'

base58 = require 'bs58'
hash = require '../src/ecc/hash'

blockchain = require '../src/blockchain'
types = blockchain.types
Deposit = blockchain.Deposit              
Operation = blockchain.Operation            
SignedTransaction = blockchain.SignedTransaction    
Transaction = blockchain.Transaction          
Withdraw = blockchain.Withdraw             
WithdrawCondition = blockchain.WithdrawCondition    
WithdrawSignatureType = blockchain.WithdrawSignatureType

{fp} = require '../src/common/fast_parser'
q = require 'q'

time = (offset_seconds) ->
    now = new Date()
    now.setSeconds now.getSeconds() + offset_seconds if offset_seconds
    now = now.toISOString()
    now = now.replace /[-:]/g, ''
    now = now.split('.')[0]
    
transfer = () ->
    
    describe "Transfer", ->
        it "TITAN", (done) ->
            ###
            assert.equal "transaction_notice", msg.mail.type()
            tn = TransactionNotice.fromBuffer(msg.mail.data)
            
            st = tn.signed_transaction
            tr = tn.signed_transaction.transaction
            ops = tn.signed_transaction.transaction.operations
            
            assert.equal 2, ops.length, 'expecting two operations'
            assert.equal 'deposit_op_type', ops[0].type()
            assert.equal 138, ops[0].operation.toBuffer().length
            assert.equal 'withdraw_op_type', ops[1].type()
            
            trx.expiration = time(60 * 60)
            trx.operations[0].data.condition.data.owner = "XTSPy3aQQS4NDepCkKsqCA7ELAtdC8Xba1gY"
            trx.operations[1].data.balance_id = "XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP"
                
            #  signed_transaction
            console.log msg.d0_otk_private.toPublicKey().toBtsAddy()
            trx={}
            try
                st.toJson(trx)
            catch error
                console.log JSON.stringify(trx, undefined, 2)
                throw error
            
            
            ###
            wallet = require '../testnet/config/wallet.json'
            
            balance_record = (public_key) ->
                pts_addy = public_key.toPtsAddy()
                for rec in wallet
                    if rec.type is 'balance_record_type' and rec.data.public_key is sender_key
                        sender_keyrecord = rec.data
                        break
            
            try
                {Rpc} = require "./rpc_json"
                @rpc=new Rpc(debug=on, 45000, "localhost", "test", "test")
                sender_name = "delegate0"
                recipient_name = "delegate1"
                q.all([
                    @rpc.run("blockchain_get_account", [sender_name])
                    @rpc.run("blockchain_get_account", [recipient_name])
                ]).then ((result) ->
                    [sender_account, recipient_account] = result

                    encrypted_activekey_orThrow = (sender_account) ->
                        [...,[create_date,sender_key]] = sender_account.active_key_history
                        for rec in wallet
                            if rec.type is 'key_record_type' and rec.data.public_key is sender_key
                                sender_keyrecord = rec.data
                                break
    
                        unless sender_keyrecord and sender_keyrecord.encrypted_private_key
                            throw "Sender (#{sender_name}) active key was not found in this wallet"
                            
                        sender_keyrecord.encrypted_private_key
                    encrypted_senderkey = encrypted_activekey_orThrow(sender_account)
                    
                    d1_private = PrivateKey.fromHex(Aes.fromSecret('Password00').decryptHex(encrypted_senderkey))
                    console.log d1_private.toPublicKey().toBtsAddy()
                    is_recipient_public = recipient_account.meta_data?.type is "public_account"
                    [...,[...,recipient_key]] = recipient_account.active_key_history
                    recipient = PublicKey.fromBtsPublic(recipient_key)
                    
                    deposit_asset = (payer, recipient, amount) ->
                        throw "Can only deposit positive amount" if amount.amount <= 0
                        # slate_id = wallet.select_slate(trx, amount.asset_id, vote_method)
                        memo_sender = payer.active_key
                        
                        wc=new WithdrawCondition(
                            asset_id=0, delegate_slate_id=0, types["withdraw_signature_type"], 
                            new WithdrawSignatureType(
                                owner=PublicKey.fromBtsAddy("XTSHDhRCtDbvMCSpoesz6LKMwjHkDZBogzTa"), 
                                one_time_key=PublicKey.fromBtsPublic("XTS5X6KkYj5hppC3ZPCnyCvi4v7offMQDtmg84oMDrXNTSMUkYfa2"),
                                encrypted_memo=new Buffer("d9ab940240e7d7041dfd23bc8e26b837ad6b826ead9ca9f37a7ad42abfcc0e710c4e7fea584888d9469997ac0724bd88c4cb97dfcbc4f006bfedb663a38836f5", 'hex')
                            )
                        )
                        
                        
                        ###
                        signed_trx = SignedTransaction.SignedTransaction.fromJson(
                          expiration: "20141111T131159"
                          delegate_slate_id: null
                          operations: [
                            {
                              type: "deposit_op_type"
                              data:
                                amount: 100000
                                condition:
                                  asset_id: 0
                                  delegate_slate_id: 0
                                  type: "withdraw_signature_type"
                                  data:
                                    owner: "XTSPy3aQQS4NDepCkKsqCA7ELAtdC8Xba1gY"
                                    memo:
                                      one_time_key: "XTS57rPNtkwivRd6TxzhaKQ3sPMb7ZP2txFtF3Y5B1kRLdhV83qwN"
                                      encrypted_memo_data: ""
                            }
                            {
                              type: "withdraw_op_type"
                              data:
                                balance_id: "XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP"
                                amount: 150000
                                claim_input_data: ""
                            }
                          ]
                          signatures: [""]
                        )
                        ###
                        ###
                        signed_trx = new SignedTransaction(
                            new Trx(
                                expiration, delegate_slate_id, [
                                    new Operation(
                                        type_id, 
                                        new Deposit(
                                            amount, 
                                            new WithdrawCondition(
                                                @asset_id, @delegate_slate_id, @type_id, 
                                                new WithdrawSigType(
                                                    @owner, @one_time_key, @encrypted_memo
                                                )
                                            )
                                        )
                                    ),
                                    new Operation(
                                        type_id, 
                                        new Withdraw(
                                            @balance_id, @amount, @claim_input_data
                                        )
                                ]
                            ),[
                                new Signature()
                            ]
                        )
                        # c++ pseudo code
                        if is_recipient_public
                            deposit
                                recipient_active_key: 'xy'
                                amount: amount
                                slate_id: 0
                        else
                            one_time_key = wallet.newPrivateKey(payer)
                            deposit_to_account
                                recipient_active_key: "xyx"
                                amount: amount
                                memo_sender:
                                    private_key: 'abc'
                                    message: 'msg'
                                slate_id: 0 
                                #memo sender (pub)
                                one_time_key: one_time_key
                                from_memo_type: 0
                                    
                            trx.deposit(recipient.active_key, amount, memo_sender.private_key, slate, memo_sender, one_time_key)
                            ###
                            #@rpc.run "network_broadcast_transaction", [trx]
                        
                    deposit_asset(d1_private, recipient, {amount: 1000000, asset_id: 0})
                    done()
                )
                .done()
            finally
                @rpc.close()
            ###
            wallet_key_record:
            
                # delegate0
                account_address: "XTS8DvGQqzbgCR5FHiNsFf8kotEXr8VKD3mR"
                
                # d0's one-time-key
                public_key: "XTS8DTWtMemdKUupjmsJYnFfxmrEpWNCGNSkhnHvzuCTx3JNioGYQ"
                encrypted_private_key: "0bf201077e854a3ac54d2b40c11577e4a5e9f1cd156d42791e8303b28cbb2514678e725ea55f0d6da7f819fb4cb97cdf"
            
            ###
transfer()