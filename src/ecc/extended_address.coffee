assert = require 'assert'
hash = require './hash'
BigInteger = require 'bigi'
curve =  require('ecurve').getCurveByName 'secp256k1'
PublicKey = require('./key_public').PublicKey
PrivateKey = require('./key_private').PrivateKey

# https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
class ExtendedAddress
    
    ###*  Shared Secret public parent key -> public child key  ###
    ExtendedAddress.deriveS_PublicKey = (private_key, one_time_key) ->
        S = hash.sha512 private_key.sharedSecret one_time_key.toUncompressed()
        public_key = private_key.toPublicKey()
        child_index = hash.sha256 S
        chain_code = _private.PAD
        #console.log 'public_key.toBuffer()',one_time_key.toBuffer().toString 'hex'
        I = hash.sha512 Buffer.concat [
            public_key.toBuffer()
            child_index
            chain_code
        ]
        #console.log 'I',I.toString 'hex'
        IL = I.slice 0, 32 # left
        IR = I.slice 32, 64 # right
        pIL = BigInteger.fromBuffer(IL)
        Ki = curve.G.multiply(pIL).add(public_key.Q)
        # https://github.com/cryptocoinjs/hdkey/issues/1
        if pIL.compareTo(curve.n) >= 0 or curve.isInfinity Ki
            throw 'Unable to produce a valid key' # very rare
        
        #public_key: PublicKey.fromPoint Ki
        #private_key: new PrivateKey(pIL)
        PublicKey.fromPoint Ki
        
    ExtendedAddress.private_key= ( private_key, index ) ->
        child_idx = hash.sha256 _private.uint32_buffer index
        chain_code = _private.PAD
        I = hash.sha512 Buffer.concat [
            _private.pad0
            private_key.toBuffer()
            child_idx
            chain_code
        ]
        IL = I.slice 0, 32 # left
        pIL = BigInteger.fromBuffer(IL)
        #console.log "IL",new PrivateKey(pIL).toHex()
        ki = pIL.add(private_key.d).mod(curve.n)
        if pIL.compareTo(curve.n) >= 0 or ki.signum() is 0
            # invalid key (probability of < 2^127
            throw 'Unable to produce a valid key' # very rare
        
        PrivateKey.fromBuffer ki.toBuffer(32)
    
    # TODO, why is this different from deriveS_PublicKey?
    ExtendedAddress.derivePublic_outbound = (private_key, one_time_key) ->
        S = hash.sha512 private_key.sharedSecret one_time_key.toUncompressed()
        #console.log 'secret\t',S.toString 'hex'
        ##public_key = private_key.toPublicKey()
        child_index = hash.sha256 S
        chain_code = _private.PAD
        I = hash.sha512 Buffer.concat [
            one_time_key.toBuffer()
            child_index
            chain_code
        ]
        #console.log 'ext ikey\t',I.toString 'hex'
        IL = I.slice 0, 32 # left
        IR = I.slice 32, 64 # right
        pIL = BigInteger.fromBuffer(IL) # private key

        Ki = curve.G.multiply(pIL).add(one_time_key.Q)
        # https://github.com/cryptocoinjs/hdkey/issues/1
        if pIL.compareTo(curve.n) >= 0 or curve.isInfinity Ki
            throw 'Unable to produce a valid key' # very rare
        
        #public_key: 
        #private_key: new PrivateKey(pIL)
        PublicKey.fromPoint Ki
            
class _private
    
    @PAD = new Buffer("0000000000000000000000000000000000000000000000000000000000000000", 'hex')
    
    _private.uint32_buffer = (uint) ->
        buffer = new Buffer(4)
        buffer.writeUInt32LE(uint, 0)
        buffer
    
    _pad0 = () ->
        buffer = new Buffer(1)
        buffer.writeUInt8(0, 0)
        buffer
    @pad0 = _pad0()

exports.ExtendedAddress = ExtendedAddress
