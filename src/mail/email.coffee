assert = require 'assert'
ByteBuffer = require 'bytebuffer'
# https://github.com/dcodeIO/ByteBuffer.js/issues/34
ByteBuffer = ByteBuffer.dcodeIO.ByteBuffer if ByteBuffer.dcodeIO

Ecc = require '../ecc'
Signature = Ecc.Signature

class Email

    constructor: (@subject, @body, @reply_to, @attachments, @signature) ->
        assert @subject isnt null, "subject is required"
        assert @body isnt null, "body is required"
        @reply_to = new Buffer("0000000000000000000000000000000000000000", 'hex').toString('binary') unless @reply_to
        @attachments = [] unless @attachments

    Email.fromBuffer = (buf) ->
        b = ByteBuffer.fromBinary buf.toString 'binary'
        Email.fromByteBuffer b

    toBuffer: (include_signature) ->
        b=@toByteBuffer(include_signature)
        new Buffer b.toBinary(), 'binary'    

    Email.fromByteBuffer= (b) ->
        subject = b.readVString()
        body = b.readVString()

        # reply_to message Id ripemd 160 (160 bits / 8 = 20 bytes)
        reply_to = new Buffer(b.copy(b.offset, b.offset + 20).toBinary(), 'binary'); b.skip 20

        # FC_REFLECT( bts::mail::attachment, (name)(data) )
        attachments = Array(b.readVarint32())
        throw "Message with attachments has not been implemented" unless attachments.length is 0

        sig_bin = b.copy(b.offset, b.offset + 65).toBinary(); b.skip 65
        sig_buf = new Buffer(sig_bin, 'binary')
        signature = Signature.fromBuffer sig_buf
        
        throw "Message contained #{b.remaining()} unknown bytes" unless b.remaining() is 0
        new Email(subject, body, reply_to, attachments, signature)

    toByteBuffer: (include_signature = true) ->
        b = new ByteBuffer()
        b.writeVString @subject
        b.writeVString @body
        b.append @reply_to.toString('binary'), 'binary'
        b.writeVarint32 @attachments.length
        throw "Message with attachments has not been implemented" unless @attachments.length is 0
        
        b.append @signature.toBuffer().toString('binary'), 'binary' if include_signature
        return b.copy 0, b.offset

    ### <HEX> ###
    
    Email.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex
        return Email.fromByteBuffer b

    toHex: (include_signature) ->
        b=@toByteBuffer(include_signature)
        b.toHex()
        
    ### </HEX> ###

exports.Email = Email
