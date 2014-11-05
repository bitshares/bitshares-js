

class Signature

    ecdsa = require './ecdsa'
    hash = require './hash'
    secp256k1 = require('ecurve').getCurveByName 'secp256k1'
    #ECSignature = require "./ecsignature"
    assert = require 'assert'
    BigInteger = require 'bigi'

    constructor: (@r, @s, @i) ->
        assert.equal @r isnt null, true, 'Missing parameter'
        assert.equal @s isnt null, true, 'Missing parameter'
        assert.equal @i isnt null, true, 'Missing parameter'

    Signature.fromBuffer = (buf) ->
        assert.equal buf.length, 65, 'Invalid signature length'
        
        i = buf.readUInt8(0)
        
        # At most 3 bits (bitcoinjs-lib, ecsignature.js::parseCompact)
        assert.equal i - 27, i - 27 & 7, 'Invalid signature parameter'
        
        #compressed = !!(i & 4)
        #
        #// Recovery param only
        #i = i & 3
        
        r = BigInteger.fromBuffer buf.slice 1, 33
        s = BigInteger.fromBuffer buf.slice 33
        new Signature r, s, i

    toBuffer: () ->
        buf = new Buffer 65
        buf.writeUInt8(@i, 0)
        @r.toBuffer(32).copy buf, 1
        @s.toBuffer(32).copy buf, 33
        buf

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
        ecdsa.verify secp256k1, _hash, {r:@r, s:@s}, public_key.Q

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
