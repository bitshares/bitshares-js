ByteBuffer = require 'bytebuffer'
hash = require '../src/ecc/hash'
asset = require 'assert'
{Transaction} = require '../src/blockchain/transaction'
{PrivateKey} = require '../src/ecc/key_private'
{Address} = require '../src/ecc/address'
assert = require 'assert'
{hex2dec} = require '../src/common/hex2dec'
{ChainInterface} = require '../src/blockchain/chain_interface'
{Short} = require '../src/blockchain/short'
BigInteger = require 'bigi'

###
# wallet_market_submit_short guest 200 XTS 1 USD 0.01
# 200   collateral
# XTS   asset qty symbol
# 1     interest rate
# USD   asset base symbol
# 0.01  price limit
###
market_submit_short=
    cli:"wallet_market_submit_short delegate0 200 XTS 1 USD 0.01"
    hex:"ccea095500020e41002d31010000000000000000000000000000c16ff28623002c00da383fc8f3635e7a7fa85dadd0d4726b69b122160100000000000000000080c6a47e8d03002c00011dffeb59d299f429ecdcd0b91c8d7bcad657f453af50f031010000000000"
    guest:
        wif: wif="5KDCBM2G5Wp7eVuERmw3M8oSwFnanNax47KQNaFmgAuR2VFFwqY"
        pub: pub=PrivateKey.fromWif(wif).toPublicKey()
        #owner: Address.fromPublic(pub).toBuffer()#pub.toBlockchainAddress()#hash.ripemd160 pub.toBuffer()
#console.log '... owner', market_submit_short.guest.owner.toString 'hex'


describe "Market Support", ->
    it "Parses Short", ->
        #console.log market_submit_short.cli
        hex = market_submit_short.hex
        console.log '... market_submit_short.hex'
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        b.printDebug()
        trx = Transaction.fromByteBuffer b
        throw "#{b.remaining()} unknown bytes" unless b.remaining() is 0
        assert.equal market_submit_short.hex, trx.toHex()
    
    it "Handles large price ratios", ->
        s2r=(num_string)->
            hex= ChainInterface.string_to_Ratio128(num_string).toHex()
            return "0" if hex is "" # issue #?
            hex2dec hex
        
        assert.equal "10000000000000000", s2r "0.01"
        assert.equal "123456789012345678901234567890123456789012345678", 
            s2r "123456789012345678901234567890.123456789012345678"
        assert.equal "0", s2r "0"
        assert.equal "100000000000000000", s2r "0.1"
        assert.equal "1000000000000000000", s2r "1.0"
        assert.equal "1100000000000000000", s2r "1.1"
    
    it "scratchpad", ->
        #console.log 'unreal128=',Short.unreal128 BigInteger "0.0"
        short_collateral = ChainInterface.to_ugly_asset(
            "200", {id:0,precision: 100000}
        )
        console.log short_collateral
        