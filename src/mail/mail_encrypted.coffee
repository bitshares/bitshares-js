assert = require 'assert'

Ecc = require '../ecc'
PublicKey = Ecc.PublicKey

ByteBuffer = require 'bytebuffer'

class EncryptedMail

    ###*
    @constructor
    @param {string} binary encoded one_time_key
    @param {string} binary encoded encrypted_mail (converts to Mail)
    ###
    constructor: (@one_time_key,  @ciphertext) ->
    
    toBinary: ->
        @toByteBuffer().toBinary()

    EncryptedMail.fromBuffer = (buf) ->
        EncryptedMail.fromByteBuffer ByteBuffer.fromHex(buf.toString('hex'), ByteBuffer.LITTLE_ENDIAN)
        
    toBuffer: ->
        b = @toByteBuffer()
        new Buffer b.toBinary(), 'binary'

    EncryptedMail.fromByteBuffer = (b) ->
        # un-encrypted compressed public key
        otk_b = b.copy(b.offset, b.offset + 33); b.skip 33
        otk_buffer = new Buffer otk_b.toBinary(), 'binary'
        one_time_key = PublicKey.fromBuffer otk_buffer
        
        len = b.readVarint32()
        cipher_b = b.copy(b.offset, b.offset + len); b.skip len
        ciphertext = new Buffer cipher_b.toBinary(), 'binary'

        assert.equal b.remaining(), 0, 'bytes unread '+b.remaining()

        return new EncryptedMail one_time_key, ciphertext

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        b.append @one_time_key.toBuffer().toString('binary'), 'binary'
        b.writeVarint32 @ciphertext.length
        b.append @ciphertext.toString('binary'), 'binary'
        return b.copy 0, b.offset
        
    ### <HEX> ###
    
    EncryptedMail.fromHex = (hex) ->
        b = ByteBuffer.fromHex hex
        return EncryptedMail.fromByteBuffer b

    toHex: ->
        @toByteBuffer().toHex()
        
    ### </HEX> ###

exports.EncryptedMail = EncryptedMail
