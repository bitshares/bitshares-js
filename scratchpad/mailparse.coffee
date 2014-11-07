console.log "\n###\n#",process.argv[1],'\n#'


ByteBuffer = require 'bytebuffer'
assert = require 'assert'
ecurve = require 'ecurve'
secp256k1 = ecurve.getCurveByName 'secp256k1'
crypto = require('../src/ecc/hash')
ecdsa = require('../src/ecc/ecdsa')
BigInteger = require('bigi')

Ecc = require('../src/ecc')
Aes = Ecc.Aes
aes = Aes.fromSecret 'Password00'

_Mail = require '../src/mail'
Mail = _Mail.Mail
EMail = _Mail.Email
EncryptedMail = _Mail.EncryptedMail
    
###
echo 0770...c414 | xxd -r -p - - > _msg
hexdump _msg -C
###

EMailParse = ->
    data="077375626a656374c50231323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a31323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839300a656e64206f66207472616e736d697373696f6e0000000000000000000000000000000000000000001fef84ce41ed1ef17d7541845d0e5ef506f2a94c651c836e53dde7621fda8897890f0251e1f6dbc0e713b41f13e73c2cf031aea2e888fe54f3bd656d727a83fddb"
    mm=EMail.fromHex data
    ###
    process.stdout.write "Original:\t"
    ByteBuffer.fromHex(data).printDebug()
    console.log "subject\t\t", mm.subject
    console.log "body\t\t",mm.body
    console.log "reply_to\t", mm.reply_to.toHex()
    console.log "attachments (#{mm.attachments.length})\t",mm.attachments
    console.log "signature\t", mm.signature.toHex()
    ###
    if data isnt mm.toHex(true)
        process.stdout.write "\nRe-created:\t"
        mm.toByteBuffer(true).printDebug()
        throw "Messages do not match #{data} AND #{mm.toHex(true)}" 

    return mm
EMail = EMailParse()

SignVerify = ->
    # npm install bs58
    bs58 = require('bs58')

    message = "abc"
    hash = crypto.sha256(message)
    
    d = ->
        privateKeyBs58 = "5JSSUaTbYeZxXt2btUKJhxU2KY1yvPvPs6eh329fSTHrCdRUGbS"
        privateKeyBuffer = bs58.decode(privateKeyBs58)
        privateKeyHex = new Buffer(privateKeyBuffer).toString("hex")
        BigInteger.fromHex(privateKeyHex)
    d = d()
    Q = secp256k1.G.multiply(d)
    #console.log "pub",Q.getEncoded(compressed=false).toString("hex"), "SignVerify"
    signature = ecdsa.sign(secp256k1, hash, d)
    throw "does not verify" unless ecdsa.verify(secp256k1, hash, signature, Q)
    throw "should not verify" if ecdsa.verify(secp256k1, crypto.sha256("def"), signature, Q)
SignVerify()

CryptoJS = require("crypto-js")
"""
https://github.com/BitShares/bitshares_toolkit/wiki/BitShares-Mail

http://stackoverflow.com/questions/16236141/cant-bridge-elliptic-curve-diffie-hellman-with-javascript -> 
    http://bitwiseshiftleft.github.io/sjcl/doc/symbols/sjcl.cipher.html
    SJCL does not use plain ECDH. It uses something that seems to be ECMQV 
    
    http://www-cs-students.stanford.edu/~tjw/jsbn/ecdh.html
    

mail_send delegate1 delegate1 s b
mail_fetch_message 0004111d003c49778a800d8c43b4b8f6c598e4c9

open default
unlock 9999 Password00
"""
#mail_store_message=
#        type: "encrypted"
#        recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
#        nonce: 474
#        timestamp: "20141027T205713"
#        data: "02dac4486140f4f3eb65c61cd517e6f75e7a50cc8d5a334f9d4713e1d6e660a043a0011af17eda53f7d4ded84c0b6ff5c0fd1724fa2985d878fac5cc5ff0c106f0ce44334b58b863ac40df82bb78ba36d88dd4c223c5af0bb74ef9fa3d18922a2cde95f9581c4a5794d9da9c24fef92634b65b2b258c61f7cfb8b61d53d337b2b0b5940ad0eb5d98399d5e23422b91d0fdc4c411b741742828711e8b8eab6fd7a1bd92a27979cdec6a51cff6cb9b308a1ee7875d925f9c9ae94c8231160921d6ae1a7c"

onetimekey = ->

    message_data_hex = "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2a001636588df76269f78eda0d98453a5e16266317ed78ae9bb013898b4cbf52ddf54959aaf2a4b0ffa4ac4dcd52edcfe179c0127bd8b02e90ba60697a34ac2a40ed6a5adf997d5f49952a9c274f018f8d9331228749a9bd899b7bcf3f52bbb7a4c1ada1e062885767fc11ceb70f72751ce86a484096a1d2e32d7cafd23469d207da2ec535b9c971b9923ca2a7db902f627a47f654435a1ccf7d822293386d69d5f50"
    d_receiver_hex = "8db25cb71976d0ee768ae602050b2afde072b32d9151405478dff0eba87f73ac"
    cipherbuf = EncryptedMail.fromHex(message_data_hex).ciphertext

    onetime_private_key=''
    onetime_public_key=''
    setup_onetime_keys = ->
        # backup wallet after sending a message, this is the last encrypted private key (one-time-key)
        encrypted_onetime_private_key = "c49c51a696060e1dbb9960aba931dfdc0f7202d2bcfdcb57b52b771b80729c2b6fd6489148b218b655c16d600b3d96ee"
        onetime_private_key = aes.decryptHex encrypted_onetime_private_key

        ## find one-time public key
        BigInteger = require('bigi')
        d = BigInteger.fromHex(onetime_private_key)
        Q = secp256k1.G.multiply(d)
        onetime_public_key_calculated = Q.getEncoded(compressed=true).toString("hex")
        onetime_public_key = Q.getEncoded(compressed=false).toString("hex")
        ###
        >>> mail_fetch_message 0007bfd903a20ee6311b269d71805eece6aacc51.
        {
          "type": "encrypted",
          "recipient": "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj",
          "nonce": 4242,
          "timestamp": "20141028T151830",
          "data": "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2a001636588df76269f78eda0d98453a5e16266317ed78ae9bb013898b4cbf52ddf54959aaf2a4b0ffa4ac4dcd52edcfe179c0127bd8b02e90ba60697a34ac2a40ed6a5adf997d5f49952a9c274f018f8d9331228749a9bd899b7bcf3f52bbb7a4c1ada1e062885767fc11ceb70f72751ce86a484096a1d2e32d7cafd23469d207da2ec535b9c971b9923ca2a7db902f627a47f654435a1ccf7d822293386d69d5f50"
        }
        ###
        onetime_public_key_compressed = EncryptedMail.fromHex(message_data_hex).one_time_key.toHex()
        assert.equal onetime_public_key_calculated, onetime_public_key_compressed, "one-time keys do not match"
    setup_onetime_keys()

    show_mail = (hex, type) ->
        console.log type, "Mail Message"
        ByteBuffer.fromHex(hex).printDebug()
        mm=EMail.fromHex hex
        mm.toByteBuffer().printDebug()

    ss_key_hex=""
    ss_iv_hex=""
    
    shared_secret_bitcore = ->
        console.log "=bitcore"

        # npm install bitcore
        ECIES = require '../node_modules/bitcore/lib/ECIES'
        ot_pubkey = new Buffer(onetime_public_key, 'hex')
        my_privkey = new Buffer(d_receiver_hex, 'hex')
        ecies = new ECIES.encryptObj ot_pubkey, new Buffer(''), my_privkey
        S = ecies.getSfromPubkey()
        console.log 'bitcore sharedsecret\t',S.toString 'hex'
        S_kdf_buf = ECIES.kdf(S)

        console.log 'bitcore sharedsecret kdf\t',S_kdf_buf.toString 'hex'
        #c=require 'crypto'
        #decipheriv = c.createDecipheriv('AES-256-CBC', @key, @iv);
        ##

        symmetricDecrypt = (privkeyhex, ivhex, cipherhex) ->
            sjcl = require '../node_modules/bitcore/lib/sjcl'
            privbits = sjcl.codec.hex.toBits privkeyhex
            encbits = sjcl.codec.hex.toBits cipherhex
            ivbits = sjcl.codec.hex.toBits ivhex
            aes_cipher = new sjcl.cipher.aes privbits

            # https://github.com/bitwiseshiftleft/sjcl/blob/master/core/cbc.js
            # https://github.com/bitwiseshiftleft/sjcl/issues/197
            sjcl.beware["CBC mode is dangerous because it doesn't protect message integrity."]()
            decrypted = sjcl.mode.cbc.decrypt aes_cipher, encbits, ivbits
            sjcl.codec.hex.fromBits decrypted

        # re-create ecies using:
        # initilization vector dervived from the shared secret S
        # the private key
        S_iv = S_kdf_buf.slice 32, 48
        S_privkey = S_kdf_buf.slice 0, 32
        ss_key_hex = S_privkey.toString('hex')
        ss_iv_hex = S_iv.toString('hex')
        plainhex = symmetricDecrypt ss_key_hex, ss_iv_hex, cipherbuf.toString('hex')

        ByteBuffer.fromHex(plainhex).printDebug()

        #plainbuf = symmetricDecrypt S_privkey, S_iv
        #msg = ECIES.symmetricDecrypt S_privkey, cipher_buf
        #show_mail new Buffer(msg, 'hex').toString(), 'bitcore'

    shared_secret_bitcore()
    
    crypto_js = ->
        console.log "=crypto-js"
        # npm install crypto-js
        CryptoJS = require("crypto-js")
        key = CryptoJS.enc.Hex.parse ss_key_hex
        iv = CryptoJS.enc.Hex.parse ss_iv_hex
        cipherwords = CryptoJS.enc.Hex.parse cipherbuf.toString('hex')
        plainwords = CryptoJS.AES.decrypt(
              ciphertext: cipherwords
              salt: cipherwords
            , key,
              iv: iv
            )
        plainhex = CryptoJS.enc.Hex.stringify plainwords
        ByteBuffer.fromHex(plainhex).printDebug()
    crypto_js()

    elliptic = ->
        # git clone https://github.com/indutny/elliptic.git
        # cd elliptic && npm install && popd
        elliptic = require('../elliptic/lib/elliptic.js')
        
        # npm install bn.js
        bn = require('bn.js')

        #Providing ecies_key_derivation https://github.com/indutny/elliptic/issues/9
        ec = new elliptic.ec('secp256k1')

        s0 = ec.keyPair(onetime_private_key, 'hex')

        # ../testnet/config/genesis_private_keys.txt
        
        s1 = ec.keyPair(d_receiver_hex, "hex")

        sh0 = s0.derive s1.getPublic()
        sh1 = s1.derive s0.getPublic()    
        assert.equal sh0.toString(16), sh1.toString(16), "shared secret did not match"

        # https://github.com/indutny/bn.js/issues/22
        shared_secret = "0"+sh0.toString(16) #### only works for this shared secret (bn.js::toString)
        console.log "elliptic shared_secret\t",shared_secret

        crypto = require('../src/ecc/hash')
        ss_buffer = new Buffer(shared_secret, "hex")

        shared_secret_sha512 = crypto.sha512 ss_buffer
        shared_secret_sha512 = shared_secret_sha512.toString('hex')
        console.log "elliptic shared_secret kdf\t",shared_secret_sha512

        aes = Aes.fromSha512(shared_secret_sha512)
        plainhex = aes.decryptHex cipherbuf.toString('hex')
        b = ByteBuffer.fromHex(plainhex)
        b.printDebug()
        
        
        ###assert.equal b.remaining(), 0, 'bytes unread '+b.remaining()
        b.skip 35
        plaintext = b.toHex()
        show_mail plaintext, 'elliptic.js'###
    #elliptic()
    
    

onetimekey()

###

# d private, Q public
d = BigInteger.fromHex private_key_hex
Q = secp256k1.G.multiply d

key = CryptoJS.enc.Hex.parse private_key_hex

###
