assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
BigInteger = require 'bigi'
{Address} = require '../ecc/address'
{hex2dec} = require '../common/hex2dec'
{Util} = require './market_util'

###
bts::blockchain::ask_operation, (amount)(ask_index)
    int64_t share_type amount
    market_index_key ask_index

    bts::blockchain::market_index_key, (order_price)(owner)
        price                 order_price
        fc::ripemd160 address owner
    
    bts::blockchain::price, (ratio)(quote_asset_id)(base_asset_id)
        fc::uint128_t ratio
        int32_t fc::signed_int asset_id_type quote_asset_id
        int32_t fc::signed_int asset_id_type base_asset_id
###
class Ask

    constructor: (@amount, @order_price, @owner) ->
        @type_name = "ask_op_type"
        @type_id = 13
    
    Ask.fromByteBuffer= (b) ->
        amount = b.readInt64()
        order_price = Util.read_price b
        owner = fp.ripemd160 b
        new Ask amount, order_price, owner
    
    appendByteBuffer: (b) ->
        #b.writeUint8 0xFF # debugging
        b.writeInt64 @amount
        Util.write_price b, @order_price
        fp.ripemd160 b, @owner
        return
    
    toJson: (o) ->
        o.amount = @amount.toString()
        o.short_index=
            order_price:
                ratio: Util.unreal128 @order_price.ratio
                quote_asset_id: @order_price.quote
                base_asset_id: @order_price.base
            owner:new Address(@owner).toString()
        return

    ### <helper_functions> ###

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')
    
    Ask.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        Ask.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Ask = Ask
