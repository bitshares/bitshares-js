assert = require 'assert'
ByteBuffer = require 'bytebuffer'
Long = ByteBuffer.Long

{fp} = require '../common/fast_parser'
{Address} = require '../ecc/address'
{Util} = require './market_util'

###
bts::blockchain::bid_operation, (amount)(bid_index)
    int64_t share_type amount
    market_index_key bid_index

    bts::blockchain::market_index_key, (order_price)(owner)
        price                 order_price
        fc::ripemd160 address owner
    
    bts::blockchain::price, (ratio)(quote_asset_id)(base_asset_id)
        fc::uint128_t ratio
        int32_t fc::signed_int asset_id_type quote_asset_id
        int32_t fc::signed_int asset_id_type base_asset_id
###
class Bid

    constructor: (@amount, @order_price, @owner) ->
        unless Long.isLong @amount
            throw new Error "Amount must be of type Long"
        @type_name = "bid_op_type"
        @type_id = 12
    
    Bid.fromByteBuffer= (b) ->
        amount = b.readInt64()
        order_price = Util.read_price b
        owner = fp.ripemd160 b
        new Bid amount, order_price, owner
    
    appendByteBuffer: (b) ->
        #b.writeUint8 0xFF # debugging
        b.writeInt64 @amount
        Util.write_price b, @order_price
        fp.ripemd160 b, @owner
        return
    
    toJson: (o) ->
        o.amount = @amount.toString()
        o.bid_index=
            order_price: Util.toJson_Price @order_price
            owner:new Address(@owner).toString()
        return
    
    Bid.fromJson= (o)->
        if o.type isnt "bid_order"
            throw new Error "Not a bid_order: #{o.type}"
        amount = Long.fromString ""+o.state.balance
        p = o.market_index.order_price
        order_price = Util.fromJson_Price p
        owner = Address.fromString(o.market_index.owner).toBuffer()
        new Bid amount, order_price, owner
    
    ### <helper_functions> ###

    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')
    
    Bid.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        Bid.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Bid = Bid
