assert = require 'assert'
config = require '../src/config'
hash = require '../src/ecc/hash'
types = require '../src/blockchain/types'
ByteBuffer = require 'bytebuffer'
base58 = require 'bs58'

ecc = require '../src/ecc'
Aes = ecc.Aes
Signature = ecc.Signature
PrivateKey = ecc.PrivateKey
PublicKey = ecc.PublicKey
Address = ecc.Address
ExtendedAddress = ecc.ExtendedAddress

mail = require '../src/mail'
Mail = mail.Mail
Email = mail.Email
EncryptedMail = mail.EncryptedMail
TransactionNotice = mail.TransactionNotice

# genesis format has changed, this matches the ID at the time this test data was collected
config.chain_id = "251e17305faf94fe8ae8c61c1408051338bed4b162d81007c5ff930a54039c7c"

###
bts::mail::transaction_notice_message, (signed_transaction)(extended_memo)(memo_signature)(one_time_key)
    bts::blockchain::signed_transaction signed_transaction
    std::string extended_memo
    fc::array<unsigned char,65> fc::optional<fc::ecc::compact_signature> memo_signature
    fc::optional<bts::blockchain::public_key_type> one_time_key

bts::blockchain::signed_transaction, (bts::blockchain::transaction), (signatures)
    fc::array<unsigned char,65> vector<fc::ecc::compact_signature> signatures
    
bts::blockchain::transaction, (expiration)(slate_id)(operations)
    fc::time_ _sec expiration
    optional slait_id_type uint64_t
    vector<operation>           operations
    
bts::blockchain::operation, (type)(data)
    fc::enum_type<uint8_t,operation_type_enum> type;
    std::vector<char> data;
###
tx_notification = (msg) ->
    
    trx_buffer = ""
    trx_notice_object = ""
    d1_private = ""
    
    describe "Transactions", ->
        it "Decrypt", ->
            encrypted_mail = EncryptedMail.fromHex msg.data
            _shared_secret = (private_key, one_time_key) ->
                one_time_key = one_time_key.toUncompressed()
                S = private_key.sharedSecret one_time_key

            _d1_private = ->
                aes = Aes.fromSecret 'Password00'
                PrivateKey.fromHex aes.decryptHex  msg.helper.delegate1_private_key_encrypted
            d1_private = _d1_private()
            
            _mail_hex_decrypt = ->
                otk_public_compressed = encrypted_mail.one_time_key
                aes_shared_secret = Aes.fromSharedSecret_ecies _shared_secret(d1_private, otk_public_compressed)
                aes_shared_secret.decryptHex encrypted_mail.ciphertext.toString('hex')
            mail_hex = _mail_hex_decrypt()
            
            mail = Mail.fromHex mail_hex
            assert.equal "transaction_notice",mail.type()
            trx_buffer = mail.data
        
        it "Parses transaction_notice_message", ->
            trx_binary = trx_buffer.toString('binary')
            b = ByteBuffer.fromBinary(trx_binary, ByteBuffer.LITTLE_ENDIAN)
            tn = TransactionNotice.fromByteBuffer b
            throw "#{b.remaining()} unknown bytes" unless b.remaining() is 0
            trx_notice_object = tn
            
        it "Regenerates transaction_notice_message", ->
            trx_export_b = trx_notice_object.toByteBuffer()
            trx_export_buffer = new Buffer(trx_export_b.toBinary(), 'binary')
            #trx_export_b.printDebug()
            #ByteBuffer.fromBinary(trx_buffer.toString('binary')).printDebug()
            assert.deepEqual trx_buffer, trx_export_buffer
            
        it "Verify transaction signatures", ->
            signed_transaction = trx_notice_object.signed_transaction
            transaction = signed_transaction.transaction
            trx_buffer = transaction.toBuffer()
            chain_id_buffer = new Buffer(config.chain_id, 'hex')
            
            trx_hash = hash.sha256(Buffer.concat([trx_buffer, chain_id_buffer]))
            public_key_sender = PublicKey.fromBtsPublic(msg.helper.public_btskey_sender)
            assert signed_transaction.signatures.length > 0, "Missing signature(s)"
            for signature in signed_transaction.signatures
                verify = signature.verifyHash(trx_hash, public_key_sender)
                assert.equal verify,true, 'Transaction did not verify'
                
        it "Verify memo signature", ->
            extended_memo = trx_notice_object.extended_memo
            memo_signature = trx_notice_object.memo_signature
            throw "Missing extended_memo" unless extended_memo
            throw "Missing memo_signature" unless memo_signature
            
            public_key_sender = PublicKey.fromBtsPublic(msg.helper.public_btskey_sender)
            verify = memo_signature.verifyBuffer(extended_memo, public_key_sender)
            assert verify, 'Memo did not verify'
        
        it "Extended owner key", ->
            signed_transaction = trx_notice_object.signed_transaction
            transaction = signed_transaction.transaction
            operations = transaction.operations
            deposit = operations[0].operation
            assert.equal "deposit_op_type", deposit.type_name
            withdraw_condition = deposit.withdraw_condition
            condition = withdraw_condition.condition
            assert.equal "withdraw_signature_type", condition.type_name
            assert one_time_key = condition.one_time_key
            
            public_key = ExtendedAddress.deriveS_PublicKey d1_private, one_time_key
            derive_owner = Address.fromBuffer(public_key.toBuffer()).toString()
            condition_owner = new Address(condition.owner).toString()
            assert.equal condition_owner, derive_owner
            
        it "Extended one-time-key", ->
            sender_private = PrivateKey.fromHex "ff726224b757cc2d06cf4a7045bc425fb4e173127f481cb9325cbd1438de33c6"
            one_time_key = (seq) ->
                sender_extended = ExtendedAddress.private_key sender_private, seq
                sender_extended.toPublicKey()
            one_time_key = one_time_key(21)
            expected_otc = "XTS7u48VQqffX6di8vz36ndLRxpFDVFT8yq5fHNK3rbQUxogbZWqg" 
            actual_otc = one_time_key.toBtsPublic()
            assert.equal expected_otc, actual_otc
            
        it "Derive secret private", ->
            # transfer 1 XTS delegate0 delegate1
            otk = PublicKey.fromBtsPublic "XTS8PfBnsM5UnqJ4MyqqEps39CMxJffJn9pSH47jve4ZG7oQ2LeVy"
            delegate14 = "f9178b3b9587d588ae3845acbd92be127cd706dbaeba8d0f5f55bdc07d9d8db9"
            private_key = PrivateKey.fromHex delegate14
            p=PrivateKey.fromHex("ce1cca0d85407ca2c0133a2ff979d3b7bb681f13770917d912a43aa587e46f47")
            pk = ExtendedAddress.private_key_child private_key, otk
            assert.equal p.toHex(), pk.toHex()
            
            
tx_notification
    # transfer 1 XTS delegate0 delegate1 "my memo" vote_random
    type: "encrypted"
    recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
    nonce: 68719479850
    timestamp: "20141111T121159"
    data: "02adc5b24a90fec15340ead27f2335071f9c17dad608bb149aa51f2829f56cc8aa90030955e4ad6f086f4cb0a8783b1aaf427a3d9d04180199557258a7a1a98b7a23e126964f7159ee97bfa2a6fbfa01c1f732944377d870b9cec83403c0bbc28f4b31d7e7512bb899d5b17b71e07b1fb7a8f1ea18dd9a8c2ff0ca897b4978bcb74586a1f17c137acd9767df0b9c8cebf6589f013a25c83b809f5238bd0e66145ff2ffb15d2e80ec80439e7b3a0b5b13c7fbd3fab2d2b7738233dfc5ede20328d39d7e562dcf4b632e9cda4302121da84b16b9fddc63c5a8039e643b1aab05ca03e5ea7e7e177675f0459eb7488357df176a576c3e440ab3ce1af753c59e120c95bde9e01993aad2dcf79fe4be27d73f41acff8f98d9ae717cdf0c55656ab013cbe87e5db8685ddda60cd5d6dfd5fb2e5f5df0bcc593c70b076c68a716a35b50d7d9260788db663f11869e179a3cabaebe9e503142cf10421085a0df97275f210e577e64217929dcf005d0ba939590d4340b46de233d1e34eaf384701fffe438ca9f814bc8a0d12a9a562bfbb8bbdbe123488d8d88a75faee96d98734578dc6c67f1dc5910ae38331614ecbe12bfc349756d5b"
    helper:
        public_btskey_sender: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        delegate1_private_key_encrypted: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"
