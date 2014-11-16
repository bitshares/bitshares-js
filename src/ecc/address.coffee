assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
config = require '../config'
hash = require './hash'

class Address

    constructor: (@addr) ->
        
    Address.fromBinary = (buffer) ->
        _hash = hash.sha512(buffer)
        addr = hash.ripemd160(_hash)
        new Address(addr)
    
    Address.fromString = (string) ->
        prefix = public_key.slice 0, config.bts_address_prefix.length
        assert.equal config.bts_address_prefix, prefix, "Expecting key to begin with #{config.bts_address_prefix}, instead got #{prefix}"
        addy = public_key.slice config.bts_address_prefix.length
        addy = new Buffer(base58.decode addy, 'binary')
        checksum = addy.slice -4
        addy = addy.slice 0, -4
        new_checksum = hash.ripemd160 addy
        new_checksum = new_checksum.slice 0, 4
        assert.deepEqual checksum, new_checksum, 'Checksum did not match'
        new Address(addy)
        
    Address.toString = ->
        buffer = @addy
        checksum = hash.ripemd160 buffer
        addy = Buffer.concat [buffer, checksum.slice 0, 4]
        config.bts_address_prefix + base58.encode addy

exports.Address = Address
