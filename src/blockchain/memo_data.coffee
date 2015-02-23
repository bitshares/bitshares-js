assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
config = require './config'

MEMO_SIZE = config.BTS_BLOCKCHAIN_MAX_MEMO_SIZE

###
FC_REFLECT( bts::blockchain::memo_data,
        (from) (from_signature) (message) (memo_flags) )

    public_key_type                      from;
    uint64_t                             from_signature = 0;
    
    ** messages are a constant length to preven analysis of
    * transactions with the same length memo_data
    fc::array<char,BTS_BLOCKCHAIN_MAX_MEMO_SIZE>     message;
    fc::enum_type<uint8_t,memo_flags_enum>           memo_flags;
###
class MemoData

    constructor: (@from, @from_signature, @message, @memo_flags) ->
    
    MemoData.fromByteBuffer= (b) ->
        from = fp.public_key b
        from_signature = b.readUint64()
        message = fp.fixed_data b, MEMO_SIZE
        memo_flags = b.readUint8()
        new MemoData(from, from_signature, message, memo_flags)
    
    appendByteBuffer: (b) ->
        fp.public_key b, @from
        b.writeUint64 @from_signature
        fp.fixed_data b, MEMO_SIZE, @message
        b.writeUint8 @memo_flags
        return
    
    ### <helper_functions> ###
    
    MemoData.fromCheckSecret= (from, check_secret, message, memo_flags) ->
        # serilize a 64bit number
        from_signature = (->
            return 0 unless check_secret
            check_secret_b = ByteBuffer.fromBinary check_secret.toString('binary'), ByteBuffer.LITTLE_ENDIAN
            check_secret_b.readUint64()
        )()
        new MemoData(
            from
            from_signature
            message
            memo_flags
        )
    
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return new Buffer(b.copy(0, b.offset).toBinary(), 'binary')
    
    MemoData.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return MemoData.fromByteBuffer b
    
    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
    
    ### </helper_functions> ###

exports.MemoData = MemoData
