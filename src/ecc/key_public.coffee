
class PublicKey

    BigInteger = require 'bigi'
    ecurve = require('ecurve')
    secp256k1 = ecurve.getCurveByName 'secp256k1'
    BigInteger = require 'bigi'
    base58 = require 'bs58'
    hash = require './hash'
    config = require '../config'

    ###*
    @param {BigInteger} public key
    @param {boolean}
    ###
    constructor: (@Q) ->

    PublicKey.fromBinary = (bin) ->
        PublicKey.fromBuffer new Buffer bin, 'binary'

    PublicKey.fromBuffer = (buf) ->
        new PublicKey ecurve.Point.decodeFrom secp256k1, buf

    PublicKey.fromPoint = (point) ->
        new PublicKey point

    toBuffer: ->
        @Q.getEncoded @Q.compressed
        
    toUncompressed: ->
        buf = @Q.getEncoded(false)
        point = ecurve.Point.decodeFrom secp256k1, buf
        PublicKey.fromPoint point
    
    toBtsAddy: ->
        pub_buf = @toBuffer()
        pub_sha = hash.sha512 pub_buf
        addy = hash.ripemd160 pub_sha
        checksum = hash.ripemd160 addy
        addy = Buffer.concat [addy, checksum.slice 0, 4]
        config.bts_address_prefix + base58.encode addy
        
    toPtsAddy: ->
        pub_buf = @toBuffer()
        pub_sha = hash.sha256 pub_buf
        addy = hash.ripemd160 pub_sha
        addy = Buffer.concat [new Buffer([0x38]), addy] #version 56(decimal)
        
        checksum = hash.sha256 addy
        checksum = hash.sha256 checksum
        
        addy = Buffer.concat [addy, checksum.slice 0, 4]
        base58.encode addy

    ### <HEX> ###
    
    PublicKey.fromHex = (hex) ->
        new PublicKey BigInteger.fromHex(hex)

    toHex: ->
        @toBuffer().toString 'hex'
        
    ### </HEX> ###


exports.PublicKey = PublicKey
