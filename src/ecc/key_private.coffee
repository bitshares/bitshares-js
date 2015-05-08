ecurve = require 'ecurve'
Point = ecurve.Point
secp256k1 = ecurve.getCurveByName 'secp256k1'
BigInteger = require 'bigi'

class PrivateKey
    
    BigInteger = require 'bigi'
    secp256k1 = require('ecurve').getCurveByName 'secp256k1'
    BigInteger = require 'bigi'
    {PublicKey} = require './key_public'
    {Aes} = require './aes'
    base58 = require 'bs58'
    hash = require './hash'
    assert = require 'assert'
    
    ###*
    @param {BigInteger}
    ###
    constructor: (@d) ->

    PrivateKey.fromBuffer = (buf) ->
        assert.equal 32, buf.length, "Expecting 32 bytes, instead got #{buf.length}"
        new PrivateKey BigInteger.fromBuffer(buf)
        
    PrivateKey.fromWif = (private_wif) ->
        private_wif = new Buffer base58.decode private_wif
        version = private_wif.readUInt8(0)
        assert.equal 0x80, version, "Expected version #{0x80}, instead got #{version}"
        # BTS checksum includes the version
        private_key = private_wif.slice 0, -4
        checksum = private_wif.slice -4
        new_checksum = hash.sha256 private_key
        new_checksum = hash.sha256 new_checksum
        new_checksum = new_checksum.slice 0, 4
        assert.deepEqual checksum, new_checksum#, 'Invalid checksum'
        PrivateKey.fromBuffer private_key.slice 1
        
    toWif: ->
        private_key = @toBuffer()
        # BTS checksum includes the version
        private_key = Buffer.concat [new Buffer([0x80]), private_key]
        checksum = hash.sha256 private_key
        checksum = hash.sha256 checksum
        checksum = checksum.slice 0, 4
        private_wif = Buffer.concat [private_key, checksum]
        base58.encode private_wif

    ###*
    @return {Point}
    ###
    toPublicKeyPoint: ->
        Q = secp256k1.G.multiply(@d)

    toPublicKey: ->
        PublicKey.fromPoint @toPublicKeyPoint()
    
    toBuffer: ->
        @d.toBuffer()
        
    ###* {return} Buffer S, 15 bytes ###
    sharedSecret: (public_key) ->
        ###
        # Alternative method (libraries)... 
        ec = require('elliptic').curves.secp256k1
        ecPoint = ec.curve.point.bind(ec.curve)
        BN = require 'bn.js'

        ecPoint = ec.curve.point.bind(ec.curve);
        KB = public_key.toBuffer() 
        x = new BN KB.slice(1,33)
        y = new BN KB.slice(33,65)
        KB = ecPoint(x, y)
        KB.validate()
        
        r = @toBuffer()
        P = KB.mul new BN(r)
        S = new Buffer P.getX().toArray()
        ###
        KB = public_key.toBuffer() #BigInteger.fromBuffer public_key_point
        KBP = new Point(#.fromAffine(
            secp256k1
            x = BigInteger.fromBuffer KB.slice 1,33
            y = BigInteger.fromBuffer KB.slice 33,65
            BigInteger.ONE
        )
        r = @toBuffer()
        P = KBP.multiply BigInteger.fromBuffer r
        S = P.affineX.toBuffer {size: 32}
        S

    get_shared_secret:(public_key)->
        @sharedSecret public_key.toUncompressed()
    
    sharedAes: (public_key) ->
        S = @get_shared_secret public_key
        Aes.fromSharedSecret_ecies S
        
    ### <helper_functions> ###
    
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    PrivateKey.fromHex = (hex) ->
        PrivateKey.fromBuffer new Buffer hex, 'hex'

    toHex: ->
        @toBuffer().toString 'hex'
        
    ### </helper_functions> ###

exports.PrivateKey = PrivateKey
