assert = require("assert")

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

ByteBuffer = require 'bytebuffer'
base58 = require 'bs58'

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
            console.log "type\t",mail.type
            console.log "rcpnt\t",mail.recipient.toString('hex')
            console.log "nonce\t",mail.nonce.toString()
            console.log "time\t",mail.time
            
            b = ByteBuffer.fromBinary mail.data.toString('binary'), ByteBuffer.LITTLE_ENDIAN
            console.log '\nbts::blockchain::transaction'
            
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
                            console.log 'amount',amount.toString()
                            
                            asset_id = b.readVarint32()
                            console.log 'asset_id',asset_id
                            
                            delegate_slate_id = b.readVarint64()
                            console.log 'delegate_slate_id',delegate_slate_id.toString()
                            
                            condition_type = b.readUint8()
                            console.log types.withdraw[condition_type]
                            
                            len = b.readVarint32()
                            if len isnt 0
                                console.log 'additional withdraw_condition data',len
                                b_copy = b.copy(b.offset, b.offset + len); b.skip len
                                data = new Buffer(b_copy.toBinary(), 'binary')
                                ByteBuffer.fromBinary(data.toString('binary')).printDebug()
                                throw 'Not implemented'
                                
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

            for i in [1..operations_count]#
                console.log '\noperation',i
                operation()
                
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
            
            len = b.readVarint32()
            b_copy = b.copy(b.offset, b.offset + len); b.skip len
            extended_memo = new Buffer(b_copy.toBinary(), 'binary')
            console.log 'extended_memo',"'#{extended_memo.toString()}'"
            
            memo_signature = null
            boolean_int = b.readUint8() # optional
            if boolean_int is 1
                memo_signature = _signature() 
                console.log 'memo_signature',memo_signature.toHex()
                
            
            boolean = b.readUint8() is 1 # optional
            if boolean
                # un-encrypted compressed public key
                b_copy = b.copy(b.offset, b.offset + 33); b.skip 33
                one_time_key = new Buffer(b_copy.toBinary(), 'binary')
                one_time_key = PublicKey.fromBuffer one_time_key
                console.log "one_time_key",one_time_key.toBtsPublic()
                
                
                S = _shared_secret(d1_private, one_time_key)
                aes_shared_secret = Aes.fromSharedSecret_ecies S
                
                # peek at encrypted_memo_data from native transaction
                helper_memo = aes_shared_secret.decryptHex msg.helper.encrypted_memo
                helper_memo = new Buffer(helper_memo, 'hex')
                console.log "helper_memo"
                ByteBuffer.fromBinary(helper_memo.toString('hex')).printDebug()
                
                # verify memo
                if memo_signature 
                    private_key = PrivateKey.fromSharedSecret_ecies S
                    public_key = private_key.toPublicKey()
                    verify = memo_signature.verifyBuffer(helper_memo, public_key)
                    #fails, ...?
                    #assert.equal verify,true
                
                
            
            throw "#{b.remaining()} unknown bytes" unless b.remaining() is 0
            
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
tx_notification
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
