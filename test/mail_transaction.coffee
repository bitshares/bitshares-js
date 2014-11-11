assert = require("assert")
config = require '../src/config'
hash = require '../src/ecc/hash'

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
config = require '../src/config'

ByteBuffer = require 'bytebuffer'
base58 = require 'bs58'
hash = require '../src/ecc/hash'
###
bts::mail::transaction_notice_message, (signed_transaction)(extended_memo)(memo_signature)(one_time_key)
    bts::blockchain::signed_transaction signed_transaction
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
tx_notification = (msg) ->
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
            assert.equal "transaction_notice",mail.type
            msg.helper.trx_buffer = mail.data
        
        it "Parses transaction_notice_message", ->
            trx_binary = msg.helper.trx_buffer.toString('binary')
            b = ByteBuffer.fromBinary trx_binary, ByteBuffer.LITTLE_ENDIAN
            trx_notice = TransactionNotice.fromByteBuffer b
            throw "#{b.remaining()} unknown bytes" unless b.remaining() is 0
            msg.helper.trx_notice = trx_notice
        ###
        it "Verify", ->
            trx_notice = msg.helper.trx_notice
            signed_transaction = trx_notice.signed_transaction
            transaction = signed_transaction.transaction
            trx_buffer = transaction.toBuffer()
            chain_id_buffer = new Buffer(config.chain_id, 'hex')
            trx_hash = hash.sha256(Buffer.concat([trx_buffer, chain_id_buffer]))
            public_key_sender = PublicKey.fromBtsPublic(msg.helper.public_btskey_sender)
            assert.equal true, signed_transaction.signatures.length > 0, "Missing signature(s)"
            for signature in signed_transaction.signatures
                verify = signature.verifyHash(trx_hash, public_key_sender)
                assert.equal verify,true, 'Transaction did not verify'
        ###
            
        
            
tx_notification
    # transfer 1 XTS delegate0 delegate1 "my memo" vote_random
    type: "encrypted"
    recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
    nonce: 68719479850
    timestamp: "20141111T121159"
    data: "02adc5b24a90fec15340ead27f2335071f9c17dad608bb149aa51f2829f56cc8aa90030955e4ad6f086f4cb0a8783b1aaf427a3d9d04180199557258a7a1a98b7a23e126964f7159ee97bfa2a6fbfa01c1f732944377d870b9cec83403c0bbc28f4b31d7e7512bb899d5b17b71e07b1fb7a8f1ea18dd9a8c2ff0ca897b4978bcb74586a1f17c137acd9767df0b9c8cebf6589f013a25c83b809f5238bd0e66145ff2ffb15d2e80ec80439e7b3a0b5b13c7fbd3fab2d2b7738233dfc5ede20328d39d7e562dcf4b632e9cda4302121da84b16b9fddc63c5a8039e643b1aab05ca03e5ea7e7e177675f0459eb7488357df176a576c3e440ab3ce1af753c59e120c95bde9e01993aad2dcf79fe4be27d73f41acff8f98d9ae717cdf0c55656ab013cbe87e5db8685ddda60cd5d6dfd5fb2e5f5df0bcc593c70b076c68a716a35b50d7d9260788db663f11869e179a3cabaebe9e503142cf10421085a0df97275f210e577e64217929dcf005d0ba939590d4340b46de233d1e34eaf384701fffe438ca9f814bc8a0d12a9a562bfbb8bbdbe123488d8d88a75faee96d98734578dc6c67f1dc5910ae38331614ecbe12bfc349756d5b"
    helper:
        tx_signer_privatekey: "20991828d456b389d0768ed7fb69bf26b9bb87208dd699ef49f10481c20d3e18"
        memo_signer: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        public_btskey_sender: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        tx_raw: "1f0b62540002028a01a0860100000000000000000000000000000177fbec361cb10cd18ede795a68e497f5674fea44f301021e576ccceba49a6239898e5512fcde996a67248b8afe715ffb9a701e88c4b3fc406919ae3585d8e313dfd9eb20fbe2087ad985e975230ce1cafa34da3e59767bb866b9cdfb8f9d77a438b1f3755acccd6d646fe9f68a3bfc55376885cbf623267e011d29e99edd68694b46faab47b2bd38604c085a399df04902000000000000"
        delegate1_private_key_encrypted: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"