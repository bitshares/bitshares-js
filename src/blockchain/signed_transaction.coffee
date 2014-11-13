assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{Transaction} = require './transaction'
{Signature} = require '../ecc/signature'
{fp} = require '../common/fast_parser'

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
            signatures.push fp.signature b
        
        new SignedTransaction(transaction, signatures)
        
    appendByteBuffer: (b) ->
        @transaction.appendByteBuffer(b)
        b.writeVarint32(@signatures.length)
        for signature in @signatures
            fp.signature b, signature
            
    toJson: (o) ->
        @transaction.toJson(o)
        o.signatures=[]
        for signature in @signatures
            signature.toJson(sig={})
            o.signatures.push sig
    
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
