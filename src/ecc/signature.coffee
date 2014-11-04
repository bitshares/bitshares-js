

class Signature

    ecdsa = require './ecdsa'
    hash = require './hash'
    secp256k1 = require('ecurve').getCurveByName 'secp256k1'
    ECSignature = require "./ecsignature"
    assert = require 'assert'

    constructor: (ecsignature) ->
        assert.equal ecsignature.r isnt null, true, 'ECSignature object expected'
        assert.equal ecsignature.s isnt null, true, 'ECSignature object expected'
        @ecsignature = ecsignature

    Signature.fromBuffer = (buf) ->
        result = ECSignature.parseCompact buf
        new Signature result.signature

    toBuffer: () ->
        # TODO, bitshares source code reference to 31
        i = 31
        compressed = !!(i & 4)
        @ecsignature.toCompact i, compressed

    ###
    @param {Buffer}
    @param {./PrivateKey}
    @return {./Signature}
    ###
    Signature.signBuffer = (buf, private_key) ->
        _hash = hash.sha256 buf
        new Signature ecdsa.sign secp256k1, _hash, private_key.d
        
    ###*
    @param {Buffer}
    @param {./PublicKey}
    @return {boolean}
    ###
    verifyBuffer: (buf, public_key) ->
        _hash = hash.sha256(buf)
        ecdsa.verify secp256k1, _hash, @ecsignature, public_key.Q

    ### <HEX> ###
     
    Signature.fromHex = (hex) ->
        Signature.fromBuffer new Buffer hex, "hex"

    toHex: () ->
        @toBuffer().toString "hex"
        
    Signature.signHex = (hex, private_key) ->
        buf = new Buffer hex, 'hex'
        @signBuffer buf, private_key

    verifyHex: (hex, public_key) ->
        buf = new Buffer hex, 'hex'
        @verifyBuffer buf, public_key

    ### </HEX> ###
        

exports.Signature = Signature
