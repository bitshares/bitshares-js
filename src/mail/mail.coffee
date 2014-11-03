assert = require 'assert'
{type} = require './type'
{Email} = require './email'

ByteBuffer = require 'bytebuffer'
# https://github.com/dcodeIO/ByteBuffer.js/issues/34
ByteBuffer = ByteBuffer.dcodeIO.ByteBuffer if ByteBuffer.dcodeIO

class Mail

    constructor: (@type, @data) ->

    Mail.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex
        return Mail.fromByteBuffer b
        
    toHex: (include_signature) ->
        b=@toByteBuffer(include_signature)
        b.toHex()

    Mail.fromByteBuffer= (b) ->
        console.log "=Mail"; b.printDebug()
        _type = b.readVarint32(); console.log 'type',type[_type]
        
        ###
        i = b.readVarint64();console.log 'readVarint64',i
        i = b.readVarint32();console.log 'readVarint32',i
        i = b.readVarint32();console.log 'readVarint32',i
        
        # Id ripemd 160 (160 bits / 8 = 20 bytes)
        mail_id = b.copy(b.offset, b.offset + 20).toBinary(); b.skip 20
        
        s = b.readVString(); console.log "readVString",s.length,s
        
        recipient = b.readVString()
        console.log recipient.length
        ####
        ##
        recipient = new Buffer b.copy(b.offset, b.offset + 32).toBinary(), 'binary'; b.skip 32
        console.log 'recipient',recipient.toString 'hex'

        nonce = b.readVarint64()
        console.log 'nonce',nonce

        time = b.readVarint32()
        console.log 'time',time
        ####
        
        
        #b.printDebug()

        data = new Buffer b.copy(b.offset, b.remaining()).toBinary(), 'binary'
        b.skip b.remaining()

        new Mail(type[_type], data)
    toByteBuffer: () ->
        assert.equal true, false, "Not Implemented"
        ###
        b = new ByteBuffer()
        b.writeVString @subject
        b.writeVString @body
        b.append @reply_to, 'binary'
        b.writeVarint32 @attachments.length
        throw "Message with attachments has not been implemented" unless @attachments.length is 0
        
        b.append @signature, 'binary' if include_signature
        return b.copy 0, b.offset

        ###

    toEmail: ->
        assert.equal @type, 'email'
        Email.fromBuffer @data

exports.Mail = Mail
