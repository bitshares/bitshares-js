assert = require 'assert'
hash = require './hash'
BigInteger = require 'bigi'
curve =  require('ecurve').getCurveByName 'secp256k1'
PublicKey = require('./key_public').PublicKey
PrivateKey = require('./key_private').PrivateKey

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
        
    ExtendedAddress.extended_private_key= ( private_key, index ) ->
        child_idx = hash.sha256 new Buffer(index, 'binary')
        chain_code = new Buffer("0000000000000000000000000000000000000000000000000000000000000000", 'hex')
        I = hash.sha512 Buffer.concat [
            new Buffer(0)
            private_key.toBuffer()
            child_idx
            chain_code
        ]
        IL = I.slice 0, 32 # left
        #from seed: private_key, IL
        pIL = BigInteger.fromBuffer(IL)
        ki = pIL.add(private_key.d).mod(curve.n)
        if pIL.compareTo(curve.n) >= 0 or ki.signum() is 0
            # ? truncate lower order values (skip extra bytes)
            # https://github.com/BitShares/fc/blob/master/src/crypto/elliptic.cpp#L308-L312
            # or increment: https://github.com/cryptocoinjs/hdkey/blob/master/lib/hdkey.js#L131-L134
            ExtendedAddress.extended_private_key(private_key, index + 1)
        else
            private_key: PrivateKey.fromBuffer ki.toBuffer(32)
            index: index
            
exports.ExtendedAddress = ExtendedAddress
