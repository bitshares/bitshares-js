assert = require 'assert'
hash = require './hash'
BigInteger = require 'bigi'
curve =  require('ecurve').getCurveByName 'secp256k1'
PublicKey = require('./key_public').PublicKey
PrivateKey = require('./key_private').PrivateKey

# TODO rename to ExtendedPrivateKey to better indicate it contains private info

# https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
class ExtendedAddress
    
    constructor: (@private_key, @chain_code = _private.PAD) ->
        
    ExtendedAddress.fromSha512_zeroChainCode =(data) ->
        throw 'Expecting 64 bytes (512 bits)' unless data.length is 64
        d = PrivateKey.fromBuffer data.slice 0, 32 # left
        #chain_code = data.slice 32, 64 # right
        new ExtendedAddress d#, chain_code
    
    toBuffer: ->
        Buffer.concat [@private_key.toBuffer(), @chain_code]
        
   #ExtendedAddress.fromBuffer= (buffer) ->
   #    ExtendedAddress.fromSha512 buffer
    
    # TODO, convert all methods below using chain_code to insance methods. Update unit tests and re-test scratchpad scripts (like titan)
    
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
        ki = pIL.add(private_key.d).mod(curve.n)
        if pIL.compareTo(curve.n) >= 0 or ki.signum() is 0
            # invalid key (probability of < 2^127)
            throw new Error 'Unable to produce a valid key' # very rare
        
        PrivateKey.fromBuffer ki.toBuffer(32)
        
    ExtendedAddress.private_key_child= ( private_key, public_key ) ->
        secret = hash.sha512 private_key.sharedSecret public_key.toUncompressed()
        PAD = new Buffer("0000000000000000000000000000000000000000000000000000000000000000", 'hex')
        I = hash.sha512 Buffer.concat [
            private_key.toPublicKey().toBuffer()
            hash.sha256 secret
            chain_code = _private.PAD
        ]
        
        IL = I.slice 0, 32 # left
        pIL = BigInteger.fromBuffer(IL)
        ki = pIL.add(private_key.d).mod(curve.n) 
        if pIL.compareTo(curve.n) >= 0 or ki.signum() is 0
            throw 'Unable to produce a valid private child key'
        
        PrivateKey.fromBuffer ki.toBuffer(32)
        
    
    # TODO, in scratchpad tests this variation on
    # deriveS_PublicKey was required.  A little tweaking
    # and this may be unnecessary.
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
    
    ###*
        In the light-weight client: "One time keys are
        hash(wif_active_key + " " + id) for some string ID. A
        transaction OTK ID is its expiration time in seconds since
        epoch."
    ###
    ExtendedAddress.create_one_time_key=(active_PrivateKey, key_id)->
        wif = active_PrivateKey.toWif()
        throw new Error "key_id is required" unless key_id
        h = hash.sha512 wif  + " " + key_id
        h = hash.sha256 h
        PrivateKey.fromBuffer h
    
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
