assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'

###
bts::mail::transaction_notice_message, (trx)(extended_memo)(memo_signature)(one_time_key)
    bts::blockchain::signed_transaction trx
    std::string extended_memo
    fc::array<unsigned char,65> fc::optional<fc::ecc::compact_signature> memo_signature
    fc::optional<bts::blockchain::public_key_type> one_time_key
###
class TransactionNotice

    constructor: (@field1) ->
        
    TransactionNotice.fromByteBuffer= (b) ->
        throw 'Not Implemented'
        new TransactionNotice(field1)
        
    appendByteBuffer: (b) ->
        throw 'Not Implemented'
        
    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return new Buffer(b.copy(0, b.offset).toBinary(), 'binary')

    ### <HEX> ###
    
    TransactionNotice.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.TransactionNotice = TransactionNotice
