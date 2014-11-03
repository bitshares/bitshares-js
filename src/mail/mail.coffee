assert = require 'assert'
{type} = require './type'
{Email} = require './email'

ByteBuffer = require 'bytebuffer'
# https://github.com/dcodeIO/ByteBuffer.js/issues/34
ByteBuffer = ByteBuffer.dcodeIO.ByteBuffer if ByteBuffer.dcodeIO

class Mail

    constructor: (@type, @recipient, @nonce, @time, @data) ->

    Mail.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return Mail.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()

    Mail.fromByteBuffer= (b) ->
        #console.log "=Mail"; b.printDebug()
        _type = b.readUint16(); console.log 'type',type[_type],_type

        # blockchain::address === Id ripemd 160 (160 bits / 8 = 20 bytes)
        recipient = new Buffer b.copy(b.offset, b.offset + 20).toBinary(), 'binary'; b.skip 20
        #console.log 'recipient',recipient.toString 'hex'

        nonce = b.readUint64() #; console.log 'nonce',nonce #uint64_t

        epoch = b.readInt32() # fc::time_point_sec
        time = new Date(epoch * 1000)
        #console.log 'time',time

        len = b.readVarint32()
        data = new Buffer(b.copy(b.offset, b.offset + len).toBinary(), 'binary'); b.skip len
        
        #ByteBuffer.fromBinary(data.toString('binary')).printDebug()

        assert.equal b.remaining(), 0, "Error, #{b.remaining()} unparsed bytes"
        new Mail(type[_type], recipient, nonce, time, data)

    toByteBuffer: () ->
        
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        
        b.writeUint16 parseInt k for k,v of type when v is @type
        b.append @recipient.toString('binary'), 'binary'
        b.writeUint64 @nonce.low
        b.writeInt32 @time.getTime() / 1000
        b.writeVarint32 @data.length
        b.append @data.toString('binary'), 'binary'
        return b.copy 0, b.offset

    toEmail: ->
        assert.equal @type, 'email'
        Email.fromBuffer @data

exports.Mail = Mail
