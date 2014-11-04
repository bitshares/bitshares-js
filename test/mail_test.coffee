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

###
= Buffer verses HEX

In the main implemenation, NodeJs Buffers are the standard but HEX functions are provided.  The HEX functions
simply convert to Buffers and call the main implementation.  Using all HEX functions here in the testing gives
debug readability and complete code coverage.

###

encrypted_mail_test = (msg) ->
    describe "Encrypted Mail", ->
        describe "Parse and regenerate", ->
            it "HEX", ->
                encrypted_mail = EncryptedMail.fromHex msg.data
                assert.equal encrypted_mail.toHex(), msg.data

            it "Buffer", ->
                encrypted_mail = EncryptedMail.fromBuffer new Buffer msg.data, 'hex'
                assert.equal encrypted_mail.toBuffer().toString('hex'), msg.data

    describe "Mail", ->
        describe "Parse and regenerate", ->
            it "HEX", ->
                mail = Mail.fromHex msg.decrypted_mail
                assert.equal mail.toHex(), msg.decrypted_mail
                email = mail.toEmail()

        it "Matching one_time_key", ->
            aes = Aes.fromSecret 'Password00'
            onetime_private_key = aes.decrypt_hex msg.encrypted_onetime_private_key
            private_key= PrivateKey.fromHex onetime_private_key
            assert.equal private_key.toHex(), msg.otk_private
            public_key = private_key.toPublicKey()
            assert.equal public_key.toHex(), msg.otk_compressed
            public_key = public_key.toUncompressed()
            assert.equal public_key.toHex(), msg.otk_uncompressed

        it "Decrypt", ->
            encrypted_mail = EncryptedMail.fromHex msg.data
            one_time_key = PublicKey.fromBinary encrypted_mail.one_time_key
            one_time_key = one_time_key.toUncompressed()
            private_key = PrivateKey.fromHex msg.receiver_private_key
            assert.equal private_key.toPublicKey().toHex(), msg.receiver_public_key
            shared_secret = private_key.sharedSecret one_time_key
            assert.equal shared_secret.toString('hex'), msg.shared_secret
            aes = Aes.fromSha512 shared_secret.toString('hex')
            plaintext = aes.decrypt_hex new Buffer(encrypted_mail.ciphertext, 'binary').toString 'hex'
            assert.equal plaintext, msg.decrypted_mail

        


encrypted_mail_test
    type: "encrypted"
    recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
    nonce: 474
    timestamp: "20141027T205713"
    data: "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2a001636588df76269f78eda0d98453a5e16266317ed78ae9bb013898b4cbf52ddf54959aaf2a4b0ffa4ac4dcd52edcfe179c0127bd8b02e90ba60697a34ac2a40ed6a5adf997d5f49952a9c274f018f8d9331228749a9bd899b7bcf3f52bbb7a4c1ada1e062885767fc11ceb70f72751ce86a484096a1d2e32d7cafd23469d207da2ec535b9c971b9923ca2a7db902f627a47f654435a1ccf7d822293386d69d5f50"
    receiver_private_key: "8db25cb71976d0ee768ae602050b2afde072b32d9151405478dff0eba87f73ac"
    receiver_public_key: "029d1e307b2a774af1ddd18646be6b493b2cf176fc6bb6d031b6150339d9016721"
    encrypted_onetime_private_key: "c49c51a696060e1dbb9960aba931dfdc0f7202d2bcfdcb57b52b771b80729c2b6fd6489148b218b655c16d600b3d96ee"
    shared_secret: "b995580b69bd17cdb08dcc5e6f2648150bac16e3f6fb7f18a1a76cf36133ceca48898efeab29422769a45421b44f1ed1913b729781d301934a730dc22dbdb90f"
    otk_private: "f00bbc96bd20d5ab8e354ad7007522d796e280fc93a0c66a3cc66b2bf7101150"
    otk_compressed: "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2"
    otk_uncompressed: "040833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f21d02e425c8b56ac0119db7eca5a827925907b9cde13928ddeb238d538e5ca5da"
    decrypted_mail: "03000e87650518d645c797b83f50af19515e295398d20000000000000000c7b34f5477075375626a65637418426f64790a656e64206f66207472616e736d697373696f6e0000000000000000000000000000000000000000002086a2b7a360bcdf84adef2fb34f10e98d4cba85b087438b11898b249c1495c4dc86d88057abea938f0dcfcf58200da69ee8312a7c297503710908739378537c7f"

email_test = (msg) ->
    describe "Email", ->
        describe "Parse and regenerate", ->
            it "HEX", ->
                Email email = Email.fromHex(msg.hex)
                assert.equal email.toHex(true), msg.hex
            
        #it "Buffer", ->
        #    Email email = Email.fromBuffer(new Buffer(msg.hex, 'hex'))
        #    assert.equal email.toBuffer(true).toString('hex'), msg.hex

        it "Check each field", ->
            Email email = Email.fromHex(msg.hex)
            assert.equal email.subject, msg.subject, "subject"
            assert.equal email.body, msg.body, "body"
            assert.equal email.reply_to.toString('hex'), msg.reply_to_hex, "reply_to message id"
            assert.equal email.attachments.length, msg.attachments.length, "num of attachments"
            assert.equal email.attachments.length, 0, "attachments are not supported"
            assert.equal email.signature.toString('hex'), msg.signature_hex, "signature"

        describe "Signature", ->
            it "Verifiy", ->
                # remove the signature
                email_hex = Email.fromHex(msg.hex).toHex(include_signature=false)
                public_key = PrivateKey.fromHex(msg.private_key_hex).toPublicKey()
                signature = Signature.fromHex msg.signature_hex
                verify = signature.verifyHex email_hex, public_key
                assert.equal verify, true, "signature did not verify"
            
            ###it "Sign", ->
                private_key = PrivateKey.fromHex(msg.private_key_hex)
                email = Email.fromHex(msg.hex)
                email_hex = email.toHex(include_signature=false)
                signature = Signature.signHex email_hex, private_key
                # todo, insert and test with mail server w/new signature 
                assert.equal signature.toHex(), msg.signature_hex
                
                #verify = signature.verifyHex email_hex, private_key.toPublicKey()
                #assert.equal verify, true, "signature did not verify"
            ###

email_test
    hex: "077375626a656374c50231323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a656e64206f66207472616e736d697373696f6e0000000000000000000000000000000000000000001fef84ce41ed1ef17d7541845d0e5ef506f2a94c651c836e53dde7621fda8897890f0251e1f6dbc0e713b41f13e73c2cf031aea2e888fe54f3bd656d727a83fddb"
    subject: "subject"
    body: "12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\nend of transmission"
    reply_to_hex: "0000000000000000000000000000000000000000"
    attachments: []
    signature_hex: "1fef84ce41ed1ef17d7541845d0e5ef506f2a94c651c836e53dde7621fda8897890f0251e1f6dbc0e713b41f13e73c2cf031aea2e888fe54f3bd656d727a83fddb"
    private_key_hex: "52173306ca0f862e8fbf8e7479e749b9859fa78588e0e5414ec14fc8ae51a58b"
