assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
BigInteger = require 'bigi'
{Address} = require '../ecc/address'
{hex2dec} = require '../common/hex2dec'

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
    
    Short.read_price=(b)->
        b_copy = b.copy(b.offset, b.offset + 16); b.skip 16
        console.log '1',b_copy.toHex()
        ratio: BigInteger.fromBuffer new Buffer b_copy.toBinary(), 'binary'
        quote_asset_id: b.readVarint32ZigZag()
        base_asset_id: b.readVarint32ZigZag()
    
    Short.write_price=(b, price)->
        ratio_buffer = price.ratio.toBuffer()
        ratio_buffer_target = new Buffer(16)
        ratio_buffer_target.fill 0
        ratio_buffer.copy ratio_buffer_target, 16 - ratio_buffer.length
        #console.log '2',(ByteBuffer.fromBinary ratio_buffer_target.toString 'binary').toHex()
        b.append ByteBuffer.fromBinary ratio_buffer_target.toString 'binary'
        b.writeVarint32ZigZag price.quote_asset_id
        b.writeVarint32ZigZag price.base_asset_id
        return
        
    Short.unreal128=(ratio)->
        str = hex2dec ratio.toHex()
        str = "0"+str for i in [0...18-str.length] by 1
        str = str.slice(0,idx=str.length-18)+'.'+str.slice idx
        str = str.replace /^0+/g, "" # remove leading zeros
        str = str.replace /\.?0+$/g, "" # traling zeros
        str = "0"+str if str.indexOf('.') is 0
        str
    
    Short.fromByteBuffer= (b) ->
        amount = b.readInt64()
        order_price = Short.read_price b
        (->
            r = order_price.ratio
            console.log '... order_price.ratio r=', hex2dec r.toHex()
        )()
        owner = fp.ripemd160 b
        limit_price = if fp.optional b
            Short.read_price b
        new Short amount, order_price, owner, limit_price
    
    appendByteBuffer: (b) ->
        b.writeInt64 @amount
        #b.writeUint8 0xFF
        Short.write_price b, @order_price
        #b.writeUint8 0xFF
        #b.printDebug()
        fp.ripemd160 b, @owner
        if fp.optional b, @limit_price
            Short.write_price b, @limit_price
        return
    
    REAL128_PRECISION = BigInteger("10").pow 18
    
    toJson: (o) ->
        o.amount = @amount.toString()
        o.short_index=
            order_price:
                ratio: Short.unreal128 @order_price.ratio
                quote_asset_id: @order_price.quote
                base_asset_id: @order_price.base
            owner:new Address(@owner).toString()
            limit_price:
                ratio: Short.unreal128 @limit_price.ratio
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
