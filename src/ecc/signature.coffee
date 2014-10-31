

class Signature

    ecdsa = require './ecdsa'
    hash = require './hash'
    secp256k1 = require('ecurve').getCurveByName 'secp256k1'
    ECSignature = require "./ecsignature"

    constructor: (ecsignature) ->
        #@compressed =  ecsignature.compressed
        #@i = ecsignature.i
        @signature = ecsignature.signature

    Signature.fromBuffer = (buf) ->
        new Signature ECSignature.parseCompact buf

    Signature.fromHex = (hex) ->
        Signature.fromBuffer new Buffer hex, "hex"

    ###*
    @param {Buffer}
    @param {./PublicKey}
    @return {boolean}
    ###
    verifyBuffer: (buf, public_key) ->
        _hash = hash.sha256(buf)
        ecdsa.verify secp256k1, _hash, @signature, public_key.Q

    verifyHex: (hex, public_key) ->
        buf = new Buffer(hex, 'hex')
        @verifyBuffer buf, public_key 

exports.Signature = Signature
