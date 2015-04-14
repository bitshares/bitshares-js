assert = require 'assert'
ByteBuffer = require 'bytebuffer'
Long = ByteBuffer.Long

{fp} = require '../common/fast_parser'
{Address} = require '../ecc/address'
{Util} = require './market_util'

###
bts::blockchain::cover_operation  (amount)(cover_index)(new_cover_price)
    share_type          amount;
    market_index_key    cover_index;
    fc::optional<price> new_cover_price

    
    bts::blockchain::market_index_key, (order_price)(owner)
        price                 order_price
        fc::ripemd160 address owner
    
    bts::blockchain::price, (ratio)(quote_asset_id)(base_asset_id)
        fc::uint128_t ratio
        int32_t fc::signed_int asset_id_type quote_asset_id
        int32_t fc::signed_int asset_id_type base_asset_id
###
class Cover

    constructor: (@amount, @order_price, @owner, @new_cover_price = null) ->
        unless Long.isLong @amount
            throw new Error "Amount must be of type Long"
        @type_name = "cover_op_type"
        @type_id = 15
    
    Cover.fromByteBuffer= (b) ->
        amount = b.readInt64()
        order_price = Util.read_price b
        owner = fp.ripemd160 b
        new_cover_price = if fp.optional b
            Util.read_price b
        else null
        new Cover amount, order_price, owner, new_cover_price
    
    appendByteBuffer: (b) ->
        #b.writeUint8 0xFF
        b.writeInt64 @amount
        #b.writeUint8 0xFF
        Util.write_price b, @order_price
        #b.writeUint8 0xFF
        fp.ripemd160 b, @owner
        #b.writeUint8 0xFF
        if fp.optional b, @new_cover_price
            Util.write_price b, @new_cover_price
        return
    
    toJson: (o) ->
        o.amount = @amount.toString()
        o.cover_index=
            order_price: Util.toJson_Price @order_price
            owner:new Address(@owner).toString()
        if @new_cover_price isnt null
            o.cover_index.new_cover_price=
                Util.toJson_Price @new_cover_price
        return
    
    Cover.fromJson= (o)->
        if o.type isnt "cover_order"
            throw new Error "Not a cover_order: #{o.type}"
        amount = Long.fromString ""+o.state.balance
        p = o.market_index.order_price
        order_price = Util.fromJson_Price p
        owner = Address.fromString(o.market_index.owner).toBuffer()
        new_cover_price = if p = o.interest_rate
            Util.fromJson_Price p
        new Cover amount, order_price, owner, new_cover_price

    ### <helper_functions> ###

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')
    
    Cover.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        Cover.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Cover = Cover
