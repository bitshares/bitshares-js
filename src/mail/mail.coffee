assert = require 'assert'
{type} = require './type'
{Email} = require './email'

Ecc = require '../ecc'
PublicKey = Ecc.PublicKey

ByteBuffer = require 'bytebuffer'

class Mail

    constructor: (@type_id, @recipient, @nonce, @time, @data) ->

    type: ->
        type[@type_id]
    
    Mail.fromByteBuffer= (b) ->
        #console.log "=Mail"; b.printDebug()
        type_id = b.readUint16() #; console.log 'type',type[_type],_type

        # blockchain::address === Id ripemd 160 (160 bits / 8 = 20 bytes)
        recipient_b = b.copy(b.offset, b.offset + 20); b.skip 20
        recipient = new Buffer(recipient_b.toBinary(), 'binary')

        nonce = b.readUint64() #; console.log 'nonce',nonce #uint64_t

        epoch = b.readInt32() # fc::time_point_sec
        time = new Date(epoch * 1000)
        #console.log 'time',time

        len = b.readVarint32()
        data = new Buffer(b.copy(b.offset, b.offset + len).toBinary(), 'binary'); b.skip len
        
        #ByteBuffer.fromBinary(data.toString('binary')).printDebug()

        assert.equal b.remaining(), 0, "Error, #{b.remaining()} unparsed bytes"
        new Mail(type_id, recipient, nonce, time, data)

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        b.writeUint16 @type_id
        assert.equal 20, @recipient.length
        b.append @recipient.toString('binary'), 'binary'
        b.writeUint64 @nonce
        b.writeInt32 Math.ceil @time.getTime() / 1000
        b.writeVarint32 @data.length
        b.append @data.toString('binary'), 'binary'
        return b.copy 0, b.offset

    toEmail: ->
        assert.equal @type(), 'email'
        Email.fromBuffer @data

    ### <HEX> ###
    
    Mail.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return Mail.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###
    
exports.Mail = Mail
