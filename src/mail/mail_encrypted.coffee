assert = require 'assert'

ByteBuffer = require 'bytebuffer'
# https://github.com/dcodeIO/ByteBuffer.js/issues/34
ByteBuffer = ByteBuffer.dcodeIO.ByteBuffer if ByteBuffer.dcodeIO

class EncryptedMail

    ###*
    @constructor
    @param {string} binary encoded one_time_key
    @param {string} binary encoded encrypted_mail (converts to Mail)
    ###
    constructor: (@one_time_key,  @ciphertext) ->

    EncryptedMail.fromHex = (hex) ->
        b = ByteBuffer.fromHex hex
        return EncryptedMail.fromByteBuffer b

    toHex: ->
        @toByteBuffer().toHex()
    
    toBinary: ->
        @toByteBuffer().toBinary()

    EncryptedMail.fromBuffer = (buf) ->
        EncryptedMail.fromByteBuffer ByteBuffer.fromHex buf.toString 'hex'
        
    toBuffer: ->
        b = @toByteBuffer()
        new Buffer b.toString('hex'), 'hex'

    EncryptedMail.fromByteBuffer = (b) ->
        # un-encrypted compressed public key
        one_time_key = b.copy(b.offset, b.offset + 33).toBinary(); b.skip 33
        
        len = b.readVarint32()
        ciphertext = b.copy(b.offset, b.offset + len).toBinary()
        b.skip len

        assert.equal b.remaining(), 0, 'bytes unread '+b.remaining()

        return new EncryptedMail one_time_key, ciphertext 

    toByteBuffer: ->
        b = new ByteBuffer()
        b.append @one_time_key, 'binary'
        b.writeVarint32 @ciphertext.length
        b.append @ciphertext, 'binary'
        return b.copy 0, b.offset

exports.EncryptedMail = EncryptedMail
