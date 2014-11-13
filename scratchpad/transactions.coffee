assert = require("assert")
ByteBuffer = require 'bytebuffer'

Ecc = require '../src/ecc'
Aes = Ecc.Aes
Signature = Ecc.Signature
PrivateKey = Ecc.PrivateKey
PublicKey = Ecc.PublicKey

_Mail = require '../src/mail'
Mail = _Mail.Mail
Email = _Mail.Email
EncryptedMail = _Mail.EncryptedMail

types = require '../src/blockchain/types'
base58 = require 'bs58'
config = require '../src/config'
hash = require '../src/ecc/hash'
{WithdrawSignatureType} = require '../src/blockchain/withdraw_signature_type'
{fp} = require '../src/common/fast_parser'

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
tx_notification = (msg) ->
    describe "Transactions", ->
        it "transaction_notice_message", ->
            encrypted_mail = EncryptedMail.fromHex msg.data
            
            _shared_secret = (private_key, one_time_key) ->
                one_time_key = one_time_key.toUncompressed()
                S = private_key.sharedSecret one_time_key

            _d1_private = ->
                aes = Aes.fromSecret 'Password00'
                PrivateKey.fromHex aes.decryptHex  msg.helper.delegate1_private_key_encrypted
            d1_private = _d1_private()
            
            mail_hex_decrypt = ->
                otk_public_compressed = PublicKey.fromBtsPublic msg.helper.otk_bts_public
                assert.equal otk_public_compressed.toHex(), encrypted_mail.one_time_key.toHex()
                aes_shared_secret = Aes.fromSharedSecret_ecies _shared_secret(d1_private, otk_public_compressed)
                aes_shared_secret.decryptHex encrypted_mail.ciphertext.toString('hex')
            mail_hex = mail_hex_decrypt()
            
            mail = Mail.fromHex mail_hex
            console.log "type\t",mail.type()
            console.log "rcpnt\t",mail.recipient.toString('hex')
            console.log "nonce\t",mail.nonce.toString()
            console.log "time\t",mail.time
            
            b = ByteBuffer.fromBinary mail.data.toString('binary'), ByteBuffer.LITTLE_ENDIAN
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
                                    S = _shared_secret(d1_private, condition.one_time_key)
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
                            
                            len = b.readVarint32()
                            if len isnt 0
                                console.log 'claim_input_data data',len
                                throw 'Not implemented'
                            
                operation_data(b_copy)
                if b_copy.remaining() isnt 0
                    #bb = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
                    #bb.writeVarint32(126)
                    #bb.printDebug()
                    b_copy.printDebug()
                    throw "#{b_copy.remaining()} unread bytes"

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
                
                S = _shared_secret(d1_private, one_time_key)
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
            
            throw "#{b.remaining()} unknown bytes" unless b.remaining() is 0
            
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
        otk_bts_public: "XTS6D28eGR6xtvYH8xdFLpc1PmLR1NDEnges6Pg9PWCgukYT95oYi"
        #chain_id: "251e17305faf94fe8ae8c61c1408051338bed4b162d81007c5ff930a54039c7c"
        #trx_sha256: "721ca500cc72deffd68a4759891b80c67cd995ba56e3aa4718d5334efd76892d"
        #otk_encrypted: "c4ba0fdc5a08412ef5d927f8f4d0f3dd1237c9fbd8d933199e57e48006758715ed4a16f29957886e7883861035deb474"
        
        
tx_notification1=
    # wallet_transfer 10000 XTS delegate0 delegate1 "" vote_none
    "type": "encrypted",
    "recipient": "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj",
    "nonce": 68719478787,
    "timestamp": "20141106T132825",
    "data": "0295708a2f640794cf92151b55007d08efce573798e090085986aef5d53d9f3f2580030f7a5037fbdefdd185d5a4c5fd610a9b5125f8b3e2124996aa8cb18c4b3e9b6731901ef65ac995bafe9f0f144516de4ede304bd509246240b1859331f3faaf54bff10c9024a8a96f0472cbd3ea9896db6e9563e6abd9b3105ac21735dd66862336d694722613a4a3c7284fca3b02e208a6b0f02cdd82afcf584628f8c94a9d1517bb5f3843a8373013ab0c280c6b0a83f69a7bf4c4a7317818e99351fec184c50840e7f934b81bdcd5405f6da3f2e87fd24746aeeaa1bc971bc2bee668a7d01ad9c4a69fe1532b885e4ce7962e863a2035b3d67393109989365d2428eae50d1fce88a4812ca038e4368844fb266610a68b890dc9af8911735f0bd6900a97b695a77b085197a14e5abd505af039b244bf28f14d3b8fb8d2b4f8fe3f388a85e18a2add329f2c827a6bab80efc71f953f4aeee92d6bc6b4350f8586edf10abca6f2704d62dafb83445fe23bc8da0a17306f6e2f8d4862d0dd5d09abc4e6d6d528e056361ad5dbbaa2199da5a9e725d8f7f1acca6be2bba942b9b17e181c2f054ffc"
    #otk_encrypted: "8832297c73bec8a4243b2fc39c5685cfc856e832c8305f79da78efe562826fe4423c2cf32c99df1d960626151f70da81"
    helper:
        otk_bts_public: "XTS62Jb3rL2vjV43eMgN9CvQogAxzm2SwSmkxNCRKyptQAae2zCCQ"
        delegate1_private_key_encrypted: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"
        encrypted_memo: "6919ae3585d8e313dfd9eb20fbe2087ad985e975230ce1cafa34da3e59767bb83459366c8b5f6eea13a32ae3f020648c2137eace9d8849a3b6a4202e1dd7d6c5"
        public_btskey_sender: "XTS7jDPoMwyjVH5obFmqzFNp4Ffp7G2nvC7FKFkrMBpo7Sy4uq5Mj"
        memo_signer: "XTS57rPNtkwivRd6TxzhaKQ3sPMb7ZP2txFtF3Y5B1kRLdhV83qwN"

###
bb = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
bb.writeInt64(ByteBuffer.Long.fromString("1000000000"))
bb.printDebug()

tx = (msg) ->
    describe "Transaction", ->
        it "Parse", ->
            #mail = Mail.fromHex msg.data
            #console.log 'type',mail.type
tx
    data: "49ae5b540002028a0100ca9a3b000000000000000000000000000177708b16ae5739ceb3310b2e1223ca5d6e4434af7d0102dc17ae44224e9336a1f3f4875e60dd29fce9fc5b10f0bc67cf3f63259c9f52e840ce44d0e05be6c5b48a3b9a656e5e16773318fe4f8dd8f933606dfcddf463b8cdfb76c8597c473f5c4a2fd85a68f9f857bbe5045ceb7087448ea45b6a95521f7c011d29e99edd68694b46faab47b2bd38604c085a399d508d9b3b0000000000011f1bb12156d45ba53c2a897a72c5a8312b6ba6ce7e178814e8c83681d8a1ad12221d5e93a5c51cb505bb46c5a79752f3239a9ee85de6e4de582e8240d143ab0e2300011f4ad1e2d05877189bd88bab945c8d9f4b92be9ee63689e00cfbc0331c76020d756629fa81cf48cd29a6c1f2c802cfcdcbf63e7d27d09136c7f1e225af000520710102dc17ae44224e9336a1f3f4875e60dd29fce9fc5b10f0bc67cf3f63259c9f52e8"
####
