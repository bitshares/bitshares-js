assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
BigInteger = require 'bigi'
{Address} = require '../ecc/address'
{hex2dec} = require '../common/hex2dec'
{Util} = require './market_util'

###
bts::blockchain::short_operation, (amount)(short_index)
    int64_t share_type amount
    market_index_key_ext short_index
        FC_REFLECT_DERIVED( (TYPE, INHERITS, MEMBERS)
            bts::blockchain::market_index_key_ext, 
                (bts::blockchain::market_index_key), (limit_price)
        )
        bts::blockchain::market_index_key, (order_price)(owner)
            price                 order_price
            fc::ripemd160 address owner
        
        optional<price> limit_price
        
        bts::blockchain::price, (ratio)(quote_asset_id)(base_asset_id)
            fc::uint128_t ratio
            int32_t fc::signed_int asset_id_type quote_asset_id
            int32_t fc::signed_int asset_id_type base_asset_id
###
class Short

    constructor: (@amount, @order_price, @owner, @limit_price) ->
        @type_name = "short_op_type"
        @type_id = 14
    
    Short.fromByteBuffer= (b) ->
        amount = b.readInt64()
        order_price = Util.read_price b
        (->
            r = order_price.ratio
            console.log '... order_price.ratio r=', hex2dec r.toHex()
        )()
        owner = fp.ripemd160 b
        limit_price = if fp.optional b
            Util.read_price b
        new Short amount, order_price, owner, limit_price
    
    appendByteBuffer: (b) ->
        b.writeInt64 @amount
        #b.writeUint8 0xFF
        Util.write_price b, @order_price
        #b.writeUint8 0xFF
        #b.printDebug()
        fp.ripemd160 b, @owner
        if fp.optional b, @limit_price
            Util.write_price b, @limit_price
        return
    
    REAL128_PRECISION = BigInteger("10").pow 18
    
    toJson: (o) ->
        o.amount = @amount.toString()
        o.short_index=
            order_price:
                ratio: Util.unreal128 @order_price.ratio
                quote_asset_id: @order_price.quote
                base_asset_id: @order_price.base
            owner:new Address(@owner).toString()
            limit_price:
                ratio: Util.unreal128 @limit_price.ratio
                quote_asset_id: @limit_price.quote
                base_asset_id: @limit_price.base
        return

    ### <helper_functions> ###

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')
    
    Short.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        b.printDebug()
        Short.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Short = Short
