assert = require 'assert'
hash = require './hash'
BigInteger = require 'bigi'
curve =  require('ecurve').getCurveByName 'secp256k1'
PublicKey = require('./key_public').PublicKey

class ExtendedAddress
    
    ###*  Shared Secret public parent key -> public child key  ###
    ExtendedAddress.deriveS_PublicKey = (private_key, one_time_key) ->
        S = hash.sha512 private_key.sharedSecret one_time_key.toUncompressed()
        public_key = private_key.toPublicKey()
        child_index = hash.sha256 S
        chain_code = new Buffer("0000000000000000000000000000000000000000000000000000000000000000", 'hex')
        I = hash.sha512 Buffer.concat [
            public_key.toBuffer()
            child_index
            chain_code
        ]
        IL = I.slice 0, 32 # left
        IR = I.slice 32, 64 # right
        pIL = BigInteger.fromBuffer(IL)
        Ki = curve.G.multiply(pIL).add(public_key.Q)
        if curve.isInfinity Ki
            throw 'Point at infinity' #derive(index + 1)
        
        PublicKey.fromPoint Ki
            
exports.ExtendedAddress = ExtendedAddress
