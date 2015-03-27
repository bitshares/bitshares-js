BigInteger = require 'bigi'
ByteBuffer = require 'bytebuffer'
{hex2dec} = require '../common/hex2dec'

class Util
    
    REAL128_PRECISION = BigInteger("10").pow 18
    
    #ChainInterface.isSafeInteger_orThrow:(precision)->
    #    unless Number.isSafeInteger new Number number_string
    #        throw new Error "Number #{number_string} is too large"
    
    Util.string_to_ratio128=(number_string)->
        throw new Error "Missing parameter: number_string" unless number_string
        number_string = ""+number_string if typeof number_string is "number"
        number_string = number_string.trim()
        number_parts = number_string.match /^([0-9]*)\.?([0-9]*)$/
        unless number_parts
            throw new Error "Invalid number: #{number_string}"
        
        int_part = number_parts[1]
        decimal_part = number_parts[2]
        
        ratio = if int_part isnt undefined
            lhs = BigInteger(int_part)
            if lhs.bitCount() > 128 # 128 bit limit here has nothing to do with precision below
                throw new Error "Integer digits require #{lhs.bitCount()} bits which exceeds 128 bits"
            lhs.multiply REAL128_PRECISION
        else
            BigInteger.ZERO
        
        if decimal_part isnt undefined
            throw new Error "More than 18 decimal digits" if decimal_part.length > 18
            frac_magnitude = BigInteger("10").pow decimal_part.length
            ratio = ratio.add BigInteger(decimal_part).multiply (
                REAL128_PRECISION.divide frac_magnitude
            )
        ratio
    
    Util.ratio128_to_string=(ratio)->
        str = hex2dec ratio.toHex()
        str = "0"+str for i in [0...18-str.length] by 1
        str = str.slice(0,idx=str.length-18)+'.'+str.slice idx
        str = str.replace /^0+/g, "" # remove leading zeros
        str = str.replace /\.?0+$/g, "" # traling zeros
        str = "0"+str if /^\./.test str
        str
    
    ###* @return asset ###
    Util.to_ugly_asset=(amount_to_transfer, asset)->
        #amount = ChainInterface.toNumber_orThrow amount_to_transfer # TODO
        amount = amount_to_transfer
        amount *= asset.precision
        #example: 100.500019 becomes 10050001
        amount = parseInt amount.toString().split('.')[0]
        amount:amount
        asset_id:asset.id
    
    Util.to_ugly_price=(
        price_string, base_asset, quote_asset
        needs_satoshi_conversion # do_precision_dance
    )->
        throw new Error 'price is required' unless price_string
        throw new Error 'base_asset is required' unless base_asset
        throw new Error 'quote_asset is required' unless quote_asset
        ratio = Util.string_to_ratio128 price_string
        if needs_satoshi_conversion
            ratio = ratio.multiply BigInteger ""+quote_asset.precision
            ratio = ratio.divide BigInteger ""+base_asset.precision
        ratio:ratio
        base:base_asset.id
        quote:quote_asset.id
    
    Util.read_price=(b)->
        b_copy = b.copy(b.offset, b.offset + 16); b.skip 16
        target_array = new Uint8Array(16)
        index=0
        target_array[index++] = b_copy.readByte(i) for i in [7..0] by -1
        target_array[index++] = b_copy.readByte(i) for i in [15..8] by -1
        #console.log '... target_array', new Buffer(target_array).toString 'hex'
        ratio: BigInteger.fromBuffer new Buffer target_array
        quote: b.readVarint32ZigZag()
        base: b.readVarint32ZigZag()
    
    Util.write_price=(b, price)->
        #b.writeUint8 0xFF # debugging
        ratio_array = price.ratio.toByteArray()
        target_array = new Uint8Array(16)
        target_array.set ratio_array, 16-ratio_array.length # pad
        b.writeUint8 target_array[i] for i in [7..0] by -1
        b.writeUint8 target_array[i] for i in [15..8] by -1
        #b.writeUint8 0xFF # debugging
        b.writeVarint32ZigZag price.quote
        #b.writeUint8 0xFF # debugging
        b.writeVarint32ZigZag price.base
        #b.writeUint8 0xFF # debugging
        return
        
    Util.get_balance_asset=(order)->
        asset_id: switch order.type
            when 'bid_order'
                order.market_index.order_price.quote_asset_id
            when 'ask_order'
                order.market_index.order_price.base_asset_id
            when 'short_order'
                order.market_index.order_price.base_asset_id
            when 'cover_order'
                order.market_index.order_price.quote_asset_id
        amount:order.state.balance

exports.Util = Util