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

operations = require '../src/blockchain/operations'

ByteBuffer = require 'bytebuffer'

tx = (msg) ->
    describe "Transaction", ->
        it "Parse", ->
            #mail = Mail.fromHex msg.data
            #console.log 'type',mail.type
tx
    data: "49ae5b540002028a0100ca9a3b000000000000000000000000000177708b16ae5739ceb3310b2e1223ca5d6e4434af7d0102dc17ae44224e9336a1f3f4875e60dd29fce9fc5b10f0bc67cf3f63259c9f52e840ce44d0e05be6c5b48a3b9a656e5e16773318fe4f8dd8f933606dfcddf463b8cdfb76c8597c473f5c4a2fd85a68f9f857bbe5045ceb7087448ea45b6a95521f7c011d29e99edd68694b46faab47b2bd38604c085a399d508d9b3b0000000000011f1bb12156d45ba53c2a897a72c5a8312b6ba6ce7e178814e8c83681d8a1ad12221d5e93a5c51cb505bb46c5a79752f3239a9ee85de6e4de582e8240d143ab0e2300011f4ad1e2d05877189bd88bab945c8d9f4b92be9ee63689e00cfbc0331c76020d756629fa81cf48cd29a6c1f2c802cfcdcbf63e7d27d09136c7f1e225af000520710102dc17ae44224e9336a1f3f4875e60dd29fce9fc5b10f0bc67cf3f63259c9f52e8"

tx_notification = (msg) ->
    describe "Transaction Notification", ->
        it "Parse", ->
            encrypted_mail = EncryptedMail.fromHex msg.data
            mail_hex_decrypt = ->
                aes = Aes.fromSecret 'Password00'
                d1_private = PrivateKey.fromHex aes.decrypt_hex  msg.delegate1_private_key_encrypted
                otk_public_compressed = PublicKey.fromBtsPublic msg.otk_bts_public
                assert.equal otk_public_compressed.toHex(), encrypted_mail.one_time_key.toHex()
                otk_public_uncompressed = otk_public_compressed.toUncompressed()
                S = d1_private.sharedSecret otk_public_uncompressed
                aes = Aes.fromSha512 S.toString('hex')
                aes.decrypt_hex encrypted_mail.ciphertext.toString('hex')
            mail_hex = mail_hex_decrypt()
            
            mail = Mail.fromHex mail_hex
            console.log "type\t",mail.type
            console.log "rcpnt\t",mail.recipient.toString('hex')
            console.log "nonce\t",mail.nonce
            console.log "time\t",mail.time
            
            b = ByteBuffer.fromBinary mail.data.toString('binary'), ByteBuffer.LITTLE_ENDIAN
            ###
            bts::mail::transaction_notice_message, (trx)(extended_memo)(memo_signature)(one_time_key)
            bts::blockchain::signed_transaction               trx
            bts::blockchain::signed_transaction, (bts::blockchain::transaction), (signatures)
            bts::blockchain::transaction, (expiration)(delegate_slate_id)(operations)
            bts::blockchain::operation, (type)(data)
                fc::enum_type<uint8_t,operation_type_enum> type;
                std::vector<char> data;
            ###
            console.log '\nbts::blockchain::transaction'
            
            epoch = b.readInt32() # fc::time_point_sec
            expiration = new Date(epoch * 1000)
            console.log 'expiration',expiration
            
            
            #blockchain types.hpp slait_id_type uint64_t
            #   optional<slate_id_type>
            boolean = b.readUint8()
            assert.equal 0, boolean, "Delegate slate is not implemented"
            #delegate_slait_id = b.readUint64() 
            #console.log "delegate_slait_id",delegate_slait_id
            
            # vector<operation>           operations
            operations_count = b.readVarint32()
            console.log 'operations_count',operations_count
            
            operation = ->
                # fc::enum_type<uint8_t,operation_type_enum> type
                _type = b.readUint8()
                console.log 'operation type',operations[_type]
                
                # std::vector<char> data
                len = b.readVarint32()
                console.log 'operation len',len
                b_copy = b.copy(b.offset, b.offset + len); b.skip len
                operation_data = new Buffer(b_copy.toBinary(), 'binary')
                
                switch operations[_type]
                    when "deposit_op_type"
                        ###
                        bts::blockchain::deposit_operation, (amount)(condition)
                            int64_t share_type amount
                            withdraw_condition
                            
                        bts::blockchain::withdraw_condition, (asset_id)(delegate_slate_id)(type)(data)
                            varint32 fc::signed_int asset_id_type asset_id
                            uint64_t slate_id_type delegate_slate_id
                            fc::enum_type<uint8_t, withdraw_condition_types> type
                            std::vector<char> data
                        ###
                        amount = b.readInt64()
                        console.log 'amount',amount
                        
                        asset_id = b.readVarint32()
                        console.log 'asset_id',asset_id
                        
                        delegate_slate_id = b.readUint64()
                        console.log 'delegate_slate_id',delegate_slate_id
                        
                        condition_type = b.readUint8()
                        console.log 'condition_type',condition_type
                        
                        len = b.readVarint32()
                        b_copy = b.copy(b.offset, b.offset + len); b.skip len
                        data = new Buffer(b_copy.toBinary(), 'binary')
                        ByteBuffer.fromBinary(data.toString('binary')).printDebug()
                        
            for i in [0..operations_count]
                console.log '\noperation',i
                operation()##
            b.printDebug()
            
##
tx_notification
    "type": "encrypted",
    "recipient": "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj",
    "nonce": 68719478787,
    "timestamp": "20141106T132825",
    "data": "0295708a2f640794cf92151b55007d08efce573798e090085986aef5d53d9f3f2580030f7a5037fbdefdd185d5a4c5fd610a9b5125f8b3e2124996aa8cb18c4b3e9b6731901ef65ac995bafe9f0f144516de4ede304bd509246240b1859331f3faaf54bff10c9024a8a96f0472cbd3ea9896db6e9563e6abd9b3105ac21735dd66862336d694722613a4a3c7284fca3b02e208a6b0f02cdd82afcf584628f8c94a9d1517bb5f3843a8373013ab0c280c6b0a83f69a7bf4c4a7317818e99351fec184c50840e7f934b81bdcd5405f6da3f2e87fd24746aeeaa1bc971bc2bee668a7d01ad9c4a69fe1532b885e4ce7962e863a2035b3d67393109989365d2428eae50d1fce88a4812ca038e4368844fb266610a68b890dc9af8911735f0bd6900a97b695a77b085197a14e5abd505af039b244bf28f14d3b8fb8d2b4f8fe3f388a85e18a2add329f2c827a6bab80efc71f953f4aeee92d6bc6b4350f8586edf10abca6f2704d62dafb83445fe23bc8da0a17306f6e2f8d4862d0dd5d09abc4e6d6d528e056361ad5dbbaa2199da5a9e725d8f7f1acca6be2bba942b9b17e181c2f054ffc"
    #otk_encrypted: "8832297c73bec8a4243b2fc39c5685cfc856e832c8305f79da78efe562826fe4423c2cf32c99df1d960626151f70da81"
    otk_bts_public: "XTS62Jb3rL2vjV43eMgN9CvQogAxzm2SwSmkxNCRKyptQAae2zCCQ"
    delegate1_private_key_encrypted: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"
####
