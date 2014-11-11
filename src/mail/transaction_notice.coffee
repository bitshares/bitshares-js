assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fc} = require '../common/fc_parser'
blockchain = require '../blockchain'
SignedTransaction = blockchain.SignedTransaction

ecc = require '../ecc'
Signature = ecc.Signature


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
        extended_memo = fc.variable_data b
        memo_signature = fc.signature fc.optional b
        one_time_key = fc.public_key fc.optional b
        assert.equal b.remaining(), 0, "Error, #{b.remaining()} unparsed bytes"
        new TransactionNotice(signed_transaction, extended_memo, memo_signature, one_time_key)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        
        
        return b.copy 0, b.offset
        
    toSignedTransaction: ->
        SignedTransaction.fromBuffer @signed_transaction
        
    ### <HEX> ###
    
    TransactionNotice.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.TransactionNotice = TransactionNotice