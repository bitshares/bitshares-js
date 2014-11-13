assert = require("assert")
ByteBuffer = require 'bytebuffer'

ecc = require '../src/ecc'
Aes = ecc.Aes
Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
PublicKey = ecc.PublicKey

mail = require '../src/mail'
Mail = mail.Mail
Email = mail.Email
EncryptedMail = mail.EncryptedMail
TransactionNotice = mail.TransactionNotice

types = require '../src/blockchain/types'
base58 = require 'bs58'
config = require '../src/config'
hash = require '../src/ecc/hash'
{WithdrawSignatureType} = require '../src/blockchain/withdraw_signature_type'
{fp} = require '../src/common/fast_parser'
q = require 'q'

###
bts::mail::transaction_notice_message, (trx)(extended_memo)(memo_signature)(one_time_key)
    bts::blockchain::signed_transaction trx
    std::string extended_memo
    fc::array<unsigned char,65> fc::optional<fc::ecc::compact_signature> memo_signature
    fc::optional<bts::blockchain::public_key_type> one_time_key

bts::blockchain::signed_transaction, (bts::blockchain::transaction), (signatures)
    fc::array<unsigned char,65> vector<fc::ecc::compact_signature> signatures
    
bts::blockchain::transaction, (expiration)(delegate_slate_id)(operations)
    fc::time_ _sec expiration
    optional slait_id_type uint64_t
    vector<operation>           operations
    
bts::blockchain::operation, (type)(data)
    fc::enum_type<uint8_t,operation_type_enum> type;
    std::vector<char> data;
###
parse_mail_transaction = (msg) ->
    describe "Transaction", ->
        it "Parse transaction_notice", ->
            
            assert.equal "transaction_notice", msg.mail.type()
            
            b = ByteBuffer.fromBinary msg.mail.data.toString('binary'), ByteBuffer.LITTLE_ENDIAN
            console.log '\nbts::blockchain::transaction'
            
            transaction_begin = b.offset
            
            epoch = b.readInt32() # fc::time_point_sec
            expiration = new Date(epoch * 1000)
            console.log 'expiration',expiration
            
            # Delegate slate ID
            boolean_int = b.readUint8()
            assert.equal 0, boolean_int, "Delegate slate is not implemented"
            #delegate_slait_id = b.readVarint64() 
            #console.log "delegate_slait_id",delegate_slait_id.toString()
            
            operations_count = b.readVarint32()
            console.log 'operations_count',operations_count
            
            operation = ->
                _type = b.readUint8()
                console.log 'operation type',types.operation[_type]
                
                len = b.readVarint32()
                console.log 'operation len',len
                b_copy = b.copy(b.offset, b.offset + len); b.skip len
                
                operation_data = (b) ->
                    switch types.operation[_type]
                        when "deposit_op_type"
                            ###
                            bts::blockchain::deposit_operation, (amount)(condition)
                                int64_t share_type amount
                                withdraw_condition // condition that the funds may be withdrawn
                                
                            bts::blockchain::withdraw_condition, (asset_id)(delegate_slate_id)(type)(data)
                                varint32 fc::signed_int asset_id_type asset_id
                                uint64_t slate_id_type delegate_slate_id
                                fc::enum_type<uint8_t, withdraw_condition_types> type
                                std::vector<char> data
                            ###
                            amount = b.readInt64()
                            console.log 'amount\t\t\t',amount.toString()
                            
                            asset_id = b.readVarint32()
                            console.log 'asset_id\t\t',asset_id
                            
                            delegate_slate_id = b.readInt64()
                            console.log 'delegate_slate_id\t',delegate_slate_id.toString()
                            
                            type_id = b.readUint8()
                            console.log 'withdraw_condition\t',types.withdraw[type_id]
                            assert.equal "withdraw_signature_type",types.withdraw[type_id]
                            
                            data = fp.variable_bytebuffer b
                            switch types.withdraw[type_id]
                                when "withdraw_signature_type"
                                    condition = WithdrawSignatureType.fromByteBuffer(data)
                                    S = msg.shared_secret(msg.d1_private, condition.one_time_key)
                                    aes = Aes.fromSharedSecret_ecies S
                                    memo = aes.decrypt condition.encrypted_memo
                                    
                                    memo_b = ByteBuffer.fromHex(memo.toString('hex'))
                                    fp.public_key memo_b
                                    console.log 'memo:'
                                    memo_b.printDebug()
                                else
                                    throw "Not Implemented"

                        when "withdraw_op_type"
                            ###
                            bts::blockchain::withdraw_operation, (balance_id)(amount)(claim_input_data)
                                fc::ripemd160 address balance_id_type balance_id
                                int64_t share_type amount
                                std::vector<char> claim_input_data
                            ###
                            # blockchain::address balance_id ripemd 160 (160 bits / 8 = 20 bytes)
                            console.log 'Py3aQQS4NDepCkKsqCA7ELAtdC8Xba1gY',base58.decode ('Py3aQQS4NDepCkKsqCA7ELAtdC8Xba1gY').toString('hex')
                            
                            b_copy = b.copy(b.offset, b.offset + 20); b.skip 20
                            b_copy.printDebug()
                            balance_owner = new Buffer(b_copy.toBinary(), 'binary')
                            balance_owner = base58.encode balance_owner
                            console.log "balance_id", balance_owner
                            
                            amount = b.readInt64()
                            console.log 'amount',amount.toString()
                            
                            claim_input_data = fp.variable_bytebuffer b
                            console.log 'claim_input_data:'
                            claim_input_data.printDebug()
                            
                operation_data(b_copy)
                if b_copy.remaining() isnt 0
                    #bb = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
                    #bb.writeVarint32(126)
                    #bb.printDebug()
                    console.log "WARNING #{b_copy.remaining()} unread bytes"
                    b_copy.printDebug()

            for i in [1..operations_count]#
                console.log '\noperation',i
                operation()
              
            transaction_end = b.offset
            
            signature_count = b.readVarint32()
            console.log '\nsignature_count',signature_count
            
            signatures = []
            _signature = () ->
                b_copy = b.copy(b.offset, b.offset + 65); b.skip 65
                signature_buffer = new Buffer(b_copy.toBinary(), 'binary')
                Signature.fromBuffer signature_buffer
            for i in [1..signature_count]
                signature = _signature()
                signatures.push signature
                console.log 'signature',i,signature.toHex(),'\n'
            
            _verify_sigs = ->
                assert.equal true, signatures.length isnt 0, 'Missing signature'
                public_key_sender = PublicKey.fromBtsPublic(msg.helper.public_btskey_sender)
                _trx_hash = ->
                    trx_b = b.copy(transaction_begin, transaction_end)
                    trx_b.printDebug()
                    trx_buffer = new Buffer(trx_b.toBinary(), 'binary')
                    chain_id_buffer = new Buffer(config.chain_id, 'hex')
                    hash.sha256(Buffer.concat([trx_buffer, chain_id_buffer]))
                trx_hash=_trx_hash()
                
                console.log 'trx_hash',trx_hash.toString('hex')
                for signature in signatures
                    verify = signature.verifyHash(trx_hash, public_key_sender)
                    assert.equal verify,true, 'Transaction did not verify'
            _verify_sigs()
            
            len = b.readVarint32()
            b_copy = b.copy(b.offset, b.offset + len); b.skip len
            extended_memo = new Buffer(b_copy.toBinary(), 'binary')
            console.log 'extended_memo',"'#{extended_memo.toString()}'"
            
            memo_signature = null
            if b.readUint8() is 1 # optional
                memo_signature = _signature() 
                console.log 'memo_signature',memo_signature.toHex()
                
            if b.readUint8() is 1 # optional
                # un-encrypted compressed public key
                b_copy = b.copy(b.offset, b.offset + 33); b.skip 33
                one_time_key = new Buffer(b_copy.toBinary(), 'binary')
                one_time_key = PublicKey.fromBuffer one_time_key
                console.log "one_time_key",one_time_key.toBtsPublic()
                
                S = msg.shared_secret(msg.d1_private, one_time_key)
                aes_shared_secret = Aes.fromSharedSecret_ecies S
                
                # encrypted_memo was in the trx (not in the mail trx) 
                if msg.helper.encrypted_memo
                    # peek at encrypted_memo_data from native transaction
                    helper_memo = aes_shared_secret.decryptHex msg.helper.encrypted_memo
                    helper_memo = new Buffer(helper_memo, 'hex')
                    console.log "helper_memo:"
                    ByteBuffer.fromBinary(helper_memo.toString('hex')).printDebug()
                
                # verify memo
                if memo_signature
                    public_key_sender = PublicKey.fromBtsPublic(msg.helper.public_btskey_sender)
                    verify = memo_signature.verifyBuffer(extended_memo, public_key_sender)
                    assert.equal verify,true, 'Memo did not verify'
            
            console.log "Warning #{b.remaining()} unknown bytes" unless b.remaining() is 0
            ### What to expect:
            bb = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
            bb.writeInt64(ByteBuffer.Long.fromString("1000000000"))
            bb.printDebug()
            ####

refund_mail_transfer = (msg) ->
    
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
            
            time = (offset_seconds) ->
                now = new Date()
                now.setSeconds now.getSeconds() + offset_seconds # timestamp_in_future
                now = now.toISOString()
                now = now.replace /[-:]/g, ''
                now = now.split('.')[0]
                
            #  signed_transaction
            console.log msg.d0_otk_private.toPublicKey().toBtsAddy()
            trx={}
            try
                st.toJson(trx)
            catch error
                console.log JSON.stringify(trx, undefined, 2)
                throw error
            
            trx.expiration = time(60 * 60)
            trx.operations[0].data.condition.data.owner = "XTSPy3aQQS4NDepCkKsqCA7ELAtdC8Xba1gY"
            trx.operations[1].data.balance_id = "XTS4pca7BPiQqnQLXUZp8ojTxfXo2g4EzBLP"
            ###
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
                        wallet = require '../testnet/wal.json'
                        
                        [...,[...,sender_key]] = sender_account.active_key_history
                        for rec in wallet
                            if rec.type is 'key_record_type' and rec.data.public_key is sender_key
                                sender_keyrecord = rec.data
                                break
    
                        unless sender_keyrecord and sender_keyrecord.encrypted_private_key
                            throw "Sender (#{sender_name}) active key was not found in this wallet"
                            
                        sender_keyrecord.encrypted_private_key
                    
                    encrypted_senderkey = encrypted_activekey_orThrow(sender_account)
                    is_recipient_public = recipient_account.meta_data?.type is "public_account"
                    [...,[...,recipient_key]] = recipient_account.active_key_history
                    recipient = PublicKey.fromBtsPublic(recipient_key)
                    
                    deposit_asset = (payer, recipient, amount) ->
                        throw "Can only deposit positive amount" if amount.amount <= 0
                        # slate_id = wallet.select_slate(trx, amount.asset_id, vote_method)
                        memo_sender = payer.active_key
                        if is_recipient_public
                            throw "Not Implemented"
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
                            #@rpc.run "network_broadcast_transaction", [trx]
                        
                    deposit_asset(msg.d1_private, recipient, {amount: 1000000, asset_id: 0})
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
                
mail_transfer_notice =
    # transfer 1 XTS delegate0 delegate1 "my memo" vote_random
    type: "encrypted"
    recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj" #delegate1
    nonce: 68719479850
    timestamp: "20141111T121159"
    data: "02adc5b24a90fec15340ead27f2335071f9c17dad608bb149aa51f2829f56cc8aa90030955e4ad6f086f4cb0a8783b1aaf427a3d9d04180199557258a7a1a98b7a23e126964f7159ee97bfa2a6fbfa01c1f732944377d870b9cec83403c0bbc28f4b31d7e7512bb899d5b17b71e07b1fb7a8f1ea18dd9a8c2ff0ca897b4978bcb74586a1f17c137acd9767df0b9c8cebf6589f013a25c83b809f5238bd0e66145ff2ffb15d2e80ec80439e7b3a0b5b13c7fbd3fab2d2b7738233dfc5ede20328d39d7e562dcf4b632e9cda4302121da84b16b9fddc63c5a8039e643b1aab05ca03e5ea7e7e177675f0459eb7488357df176a576c3e440ab3ce1af753c59e120c95bde9e01993aad2dcf79fe4be27d73f41acff8f98d9ae717cdf0c55656ab013cbe87e5db8685ddda60cd5d6dfd5fb2e5f5df0bcc593c70b076c68a716a35b50d7d9260788db663f11869e179a3cabaebe9e503142cf10421085a0df97275f210e577e64217929dcf005d0ba939590d4340b46de233d1e34eaf384701fffe438ca9f814bc8a0d12a9a562bfbb8bbdbe123488d8d88a75faee96d98734578dc6c67f1dc5910ae38331614ecbe12bfc349756d5b"
    helper:
        #tx_signer_privatekey: "20991828d456b389d0768ed7fb69bf26b9bb87208dd699ef49f10481c20d3e18"
        #memo_signer: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        #public_btskey_sender: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        # encrypted
        delegate1_private_key: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"
        d0_otk_public: "XTS6D28eGR6xtvYH8xdFLpc1PmLR1NDEnges6Pg9PWCgukYT95oYi"
        # encrypted
        d0_otk_private: "c4ba0fdc5a08412ef5d927f8f4d0f3dd1237c9fbd8d933199e57e48006758715ed4a16f29957886e7883861035deb474"
    
decrypt = (msg) ->
    
    describe "Decrypt", ->
        it "Mail", ->
            encrypted_mail = EncryptedMail.fromHex msg.data
                    
            shared_secret = (private_key, one_time_key) ->
                one_time_key = one_time_key.toUncompressed()
                S = private_key.sharedSecret one_time_key
            msg.shared_secret = shared_secret
            
            decrypt_private = (hex) ->
                aes = Aes.fromSecret 'Password00'
                PrivateKey.fromHex aes.decryptHex hex
            msg.d1_private = decrypt_private(msg.helper.delegate1_private_key)
            msg.d0_otk_private = decrypt_private(msg.helper.d0_otk_private)
            
            mail_hex_decrypt = ->
                otk_public_compressed = PublicKey.fromBtsPublic msg.helper.d0_otk_public
                assert.equal otk_public_compressed.toHex(), encrypted_mail.one_time_key.toHex()
                aes_shared_secret = Aes.fromSharedSecret_ecies msg.shared_secret(msg.d1_private, otk_public_compressed)
                aes_shared_secret.decryptHex encrypted_mail.ciphertext.toString('hex')
            mail_hex = mail_hex_decrypt()
            
            mail = Mail.fromHex mail_hex
            ###
            console.log "type\t",mail.type()
            console.log "rcpnt\t",mail.recipient.toString('hex')
            console.log "nonce\t",mail.nonce.toString()
            console.log "time\t",mail.time
            ####
            msg.mail = mail
        
decrypt(mail_transfer_notice)

#parse_mail_transaction mail_transfer_notice

# Reformat the transfer and refund the money (like the game ping pong)
refund_mail_transfer mail_transfer_notice
