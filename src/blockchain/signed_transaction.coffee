assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{Transaction} = require './transaction'
{Signature} = require '../ecc/signature'
{fc} = require '../common/fc_parser'

###
bts::blockchain::signed_transaction, (bts::blockchain::transaction), (signatures)
    fc::array<unsigned char,65> vector<fc::ecc::compact_signature> signatures
###
class SignedTransaction

    constructor: (@transaction, @signatures) ->
        
    SignedTransaction.fromByteBuffer= (b) ->
        transaction = Transaction.fromByteBuffer b
        signature_count = b.readVarint32()
        signatures = []
        for i in [1..signature_count]
            signatures.push fc.signature b
        
        new SignedTransaction(transaction, signatures)
        
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        
        
        return b.copy 0, b.offset
        
    toTransaction: ->
        
        
    ### <HEX> ###
    
    SignedTransaction.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.SignedTransaction = SignedTransaction

exports.SignedTransaction = SignedTransaction
