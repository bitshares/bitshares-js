
class PublicKey

    BigInteger = require 'bigi'
    ecurve = require('ecurve')
    secp256k1 = ecurve.getCurveByName 'secp256k1'
    BigInteger = require 'bigi'

    ###*
    @param {BigInteger} public key
    @param {boolean}
    ###
    constructor: (@Q) ->

    PublicKey.fromBinary = (bin) ->
        PublicKey.fromBuffer new Buffer bin, 'binary'

    PublicKey.fromBuffer = (buf) ->
        new PublicKey ecurve.Point.decodeFrom secp256k1, buf

    PublicKey.fromHex = (hex) ->
        new PublicKey BigInteger.fromHex(hex)

    PublicKey.fromPoint = (point) ->
        new PublicKey point

    toBuffer: ->
        @Q.getEncoded()
        
    toHex: ->
        @toBuffer().toString 'hex'

    toUncompressed: ->
        buf = @Q.getEncoded(false)
        point = ecurve.Point.decodeFrom secp256k1, buf
        PublicKey.fromPoint point

exports.PublicKey = PublicKey
