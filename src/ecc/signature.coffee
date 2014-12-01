

class Signature

    ecdsa = require './ecdsa'
    hash = require './hash'
    curve = require('ecurve').getCurveByName 'secp256k1'
    #ECSignature = require "./ecsignature"
    assert = require 'assert'
    BigInteger = require 'bigi'
    {PublicKey} = require './key_public'

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
        
        r = BigInteger.fromBuffer buf.slice 1, 33
        s = BigInteger.fromBuffer buf.slice 33
        new Signature r, s, i

    toBuffer: () ->
        buf = new Buffer 65
        buf.writeUInt8(@i, 0)
        @r.toBuffer(32).copy buf, 1
        @s.toBuffer(32).copy buf, 33
        buf
        
    recoverPublicKeyFromBuffer: (buffer) ->
        @recoverPublicKey hash.sha256 buffer
        
    recoverPublicKey: (sha256_buffer) ->
        e = BigInteger.fromBuffer(sha256_buffer)
        i = @i
        i = i & 3 # Recovery param only
        Q = ecdsa.recoverPubKey(curve, e, this, i)
        PublicKey.fromPoint Q
        
    ###
    @param {Buffer}
    @param {./PrivateKey}
    @return {./Signature}
    ###
    Signature.signBuffer = (buf, private_key) ->
        _hash = hash.sha256 buf
        ecsignature = ecdsa.sign curve, _hash, private_key.d
        e = BigInteger.fromBuffer(_hash);
        i = ecdsa.calcPubKeyRecoveryParam curve, e, ecsignature, private_key.toPublicKey().Q
        i += 4 #compressed
        i += 27 #compact
        new Signature ecsignature.r, ecsignature.s, i
        
    ###*
    @param {Buffer} un-hashed
    @param {./PublicKey}
    @return {boolean}
    ###
    verifyBuffer: (buf, public_key) ->
        _hash = hash.sha256(buf)
        @verifyHash(_hash, public_key)
        
    verifyHash: (hash, public_key) ->
        assert.equal hash.length, 32, "A SHA 256 should be 32 bytes long, instead got #{hash.length}"
        ecdsa.verify curve, hash, {r:@r, s:@s}, public_key.Q

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
