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
        new TransactionNotice field1
        
    appendByteBuffer: (b) ->
        throw 'Not Implemented'
        return
        
    ### <helper_functions> ###

    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        @appendByteBuffer b
        b.copy 0, b.offset
    
    toBuffer: ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')

    TransactionNotice.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        TransactionNotice.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.TransactionNotice = TransactionNotice
