
class PrivateKey
    
    BigInteger = require 'bigi'
    secp256k1 = require('ecurve').getCurveByName 'secp256k1'
    BigInteger = require 'bigi'
    {PublicKey} = require './key_public'
    
    # npm install bitcore
    ECIES = require '../../node_modules/bitcore/lib/ECIES'

    ###*
    @param {BigInteger}
    ###
    constructor: (@d) ->

    ###*
    @param {string} private key
    @return {PrivateKey}
    ###
    PrivateKey.fromHex = (hex) ->
        new PrivateKey BigInteger.fromHex(hex)

    PrivateKey.fromBuffer = (buf) ->
        new PrivateKey BigInteger.fromBuffer(buf)

    ###*
    @return {Point}
    ###
    toPublicKeyPoint: ->
        Q = secp256k1.G.multiply(@d)

    toPublicKey: ->
        PublicKey.fromPoint @toPublicKeyPoint()
    
    toBuffer: ->
        @d.toBuffer()
    
    toHex: ->
        @toBuffer().toString 'hex'

    sharedSecret: (public_key) ->
        ot_pubkey = public_key.toBuffer()
        ecies = new ECIES.encryptObj ot_pubkey, new Buffer(''), @toBuffer()
        S = ecies.getSfromPubkey()
        ECIES.kdf(S)

exports.PrivateKey = PrivateKey
