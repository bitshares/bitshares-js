assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
blockchain = require '../blockchain'
SignedTransaction = blockchain.SignedTransaction

###
bts::mail::transaction_notice_message, (trx)(extended_memo)(memo_signature)(one_time_key)
    bts::blockchain::signed_transaction trx
    std::string extended_memo
    fc::array<unsigned char,65> fc::optional<fc::ecc::compact_signature> memo_signature
    fc::optional<bts::blockchain::public_key_type> one_time_key
###
class TransactionNotice

    constructor: (@signed_transaction, @extended_memo, @memo_signature, @one_time_key) ->
        
    TransactionNotice.fromByteBuffer= (b) ->
        signed_transaction = SignedTransaction.fromByteBuffer b
        extended_memo = fp.variable_buffer b
        memo_signature = fp.signature fp.optional b
        one_time_key = fp.public_key fp.optional b
        throw "Error, #{b.remaining()} unparsed bytes" if b.remaining() isnt 0
        new TransactionNotice(signed_transaction, extended_memo, memo_signature, one_time_key)
        
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @signed_transaction.appendByteBuffer(b)
        fp.variable_buffer b, @extended_memo
        fp.signature fp.optional(b, @memo_signature), @memo_signature
        fp.public_key fp.optional(b, @one_time_key), @one_time_key
        return b.copy 0, b.offset
        
    
    ### <CONVERSION_FUNCTIONS> ###
    
    TransactionNotice.fromBuffer= (buffer) ->
        b = ByteBuffer.fromBinary buffer.toString('binary'), ByteBuffer.LITTLE_ENDIAN
        return TransactionNotice.fromByteBuffer(b)
    
    TransactionNotice.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </CONVERSION_FUNCTIONS> ###

exports.TransactionNotice = TransactionNotice