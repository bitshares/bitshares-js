BigInteger = require 'bigi'
ByteBuffer = require 'bytebuffer'
Long = ByteBuffer.Long
config = require '../config'

class Util
    
    REAL128_PRECISION = BigInteger("10").pow 18
    
    Util.string_to_ratio128=(number_string)->
        Util.to_bigi number_string, REAL128_PRECISION
    
    Util.to_bigi=(number_string, precision)->
        if number_string is null or number_string is undefined
            throw new Error "Missing parameter: number_string"
        if typeof number_string is "number"
            if number_string > 9007199254740991
                throw new Error "overflow"
            number_string = ""+number_string
        unless BigInteger.isBigInteger precision
            throw new Error "Invalid precision"
        
        number_string = number_string.trim()
        number_parts = number_string.match /^([0-9]*)\.?([0-9]*)$/
        unless number_parts
            throw new Error "Invalid number: #{number_string}"
        
        int_part = number_parts[1]
        decimal_part = number_parts[2]
        
        ratio = if int_part isnt undefined
            lhs = BigInteger(int_part)
            # bit limit here has nothing to do with precision below
            if lhs.bitLength() > 128 
                throw new Error "Integer digits require #{lhs.bitLength()} bits which exceeds #{128} bits"
            lhs.multiply precision
        else
            BigInteger.ZERO
        
        if decimal_part isnt undefined and decimal_part isnt ""
            precision_length = precision.toString().length - 1
            if decimal_part.length > precision_length
                #throw new Error "More than #{precision_length} decimal digits"
                decimal_part = decimal_part.substring 0, precision_length
            
            frac_magnitude = BigInteger("10").pow decimal_part.length
            ratio = ratio.add BigInteger(decimal_part).multiply (
                precision.divide frac_magnitude
            )
        ratio
    
    Util.ratio128_to_string=(ratio)->
        str = ratio.toString()
        str = "0"+str for i in [0...18-str.length] by 1
        str = str.slice(0,idx=str.length-18)+'.'+str.slice idx
        str = str.replace /^0+/g, "" # remove leading zeros
        str = str.replace /\.?0+$/g, "" # traling zeros
        str = "0"+str if /^\./.test str
        str
    
    ###* @return asset ###
    Util.to_ugly_asset=(amount, asset)->
        amount = Util.to_bigi amount, BigInteger ""+asset.precision
        #example: 100.500019 becomes 10050001
        amount = Long.fromString amount.toString()
        amount: amount
        asset_id: asset.id
    
    Util.to_ugly_price=(
        price_string, base_asset, quote_asset
        needs_satoshi_conversion # do_precision_dance
    )->
        throw new Error 'base_asset is required' unless base_asset
        throw new Error 'quote_asset is required' unless quote_asset
        ratio = Util.string_to_ratio128 price_string
        if needs_satoshi_conversion
            ratio = ratio.multiply BigInteger ""+quote_asset.precision
            ratio = ratio.divide BigInteger ""+base_asset.precision
        ratio:ratio
        base:base_asset.id
        quote:quote_asset.id
    
    Util.to_pretty_price = (ratio, base_asset, quote_asset)->
        ratio = Util.string_to_ratio128 ratio
        ratio = ratio.multiply BigInteger ""+base_asset.precision
        ratio = ratio.divide BigInteger ""+quote_asset.precision
        ratio = Util.ratio128_to_string ratio
        ratio + " " + quote_asset.symbol + " / " + base_asset.symbol
    
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
    
    Util.toJson_Price=(price)->
        ratio: Util.ratio128_to_string price.ratio
        quote_asset_id: price.quote
        base_asset_id: price.base
    
    Util.fromJson_Price=(price)->
        ratio: Util.string_to_ratio128 price.ratio
        quote: price.quote_asset_id
        base: price.base_asset_id
    
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
        amount:Long.fromString ""+order.state.balance
    
    ###* @return {amount: BigInteger, asset_id: int} ###
    Util.asset_multiply_price=(asset, price)->
        if asset.asset_id is price.base
            asset = BigInteger ""+asset.amount
            result = asset.multiply price.ratio
            result = result.divide REAL128_PRECISION
            if result.bitLength() >= 128
                throw new Error "overflow #{asset} * #{price.ratio} = #{result} bits = #{result.bitLength()} >= 128"
            
            amount: result
            asset_id: price.quote
        
        else if asset.asset_id is price.quote
            amount = BigInteger ""+asset.amount
            amount = amount.multiply REAL128_PRECISION
            result = amount.divide price.ratio
            if result.bitLength() >= 128
                throw new Error "overflow #{asset} / #{price.ratio} = #{result} bits = #{result.bitLength()} >= 128"
            
            amount: result
            asset_id: price.base
        
        else
            throw new Error "Type mismatch multiplying assset #{asset} by price #{price}"
    
    Util.bigi_to_long=(bigi)->
        unless BigInteger.isBigInteger bigi
            throw new Error "Required BigInteger parameter"
        throw new Error "Overflow #{bigi.toString()}" if bigi.bitLength() > 64
        Long.fromString bigi.toString()
    
    Util.long_to_bigi=(long)->
        unless Long.isLong long
            throw new Error "Required Long parameter"
        BigInteger long.toString()
    
    Util.get_interest_owed_asset=(order)->
        unless order.expiration
            throw Error "order.expiration is required"
        
        balance_asset = Util.get_balance_asset order
        order_expiration_sec = (new Date order.expiration).getTime()/1000
        apr_price = Util.fromJson_Price order.interest_rate
        
        # about 1 month (in seconds)
        age_seconds = # age_at_earliest_confirmation
            (Date.now()/1000) + config.BTS_BLOCKCHAIN_BLOCK_INTERVAL_SEC -
                (order_expiration_sec - config.BTS_BLOCKCHAIN_MAX_SHORT_PERIOD_SEC)
        
        max_shares_base_asset = {amount:config.BTS_BLOCKCHAIN_MAX_SHARES, asset_id:apr_price.base}
        
        iapr = Util.asset_multiply_price(
            max_shares_base_asset
            apr_price
        ).amount.divide BigInteger ""+config.BTS_BLOCKCHAIN_MAX_SHARES
        
        #Does not truncate decimal digits (worse, ignorged it and makes a larger number)
        #https://github.com/cryptocoinjs/bigi/issues/19
        #percent_of_year = BigInteger(""+age_seconds).divide (
        #    BigInteger ""+(365 * 24 * 60 * 60)
        #)
        #console.log '... percent_of_year', percent_of_year.toString()
        
        percent_of_year = age_seconds / (
            sec_per_year = 365 * 24 * 60 * 60
        )
        if /e-[0-9]+$/.test ""+percent_of_year
            percent_of_year = 0
        
        balance_amount = BigInteger ""+order.state.balance
        interest_owed = balance_amount.multiply iapr.multiply(
            Util.string_to_ratio128 percent_of_year
        )
        interest_owed = interest_owed.divide REAL128_PRECISION
        
        console.log '... amount(interest_owed)\t', interest_owed.toString()
        console.log '... principle.asset_id\t', balance_asset.asset_id
        
        amount: interest_owed
        asset_id: balance_asset.asset_id
    
    #Util.isSafeInteger_orThrow:(number_string)->
    #    unless Number.isSafeInteger new Number number_string
    #        throw new Error "Number #{number_string} is too large"
    
    #Util.order_id=(order)->
    #    type_name = switch order.type_name
    #        when 'short_op_type'
    #            'short_order'
    #        when 'ask_op_type'
    #            'ask_order'
    #        when 'bid_op_type'
    #            'bid_order'
    #        else
    #            throw new Error "Not Implemented"
    #    ratio_string = Util.ratio128_to_string order.order_price.ratio
    #    owner_string = new Address(order.owner).toString()
    #    hash_str = type_name + ratio_string + " " +
    #        order.order_price.base + "/" +
    #        order.order_price.quote +
    #        owner_string
    #    console.log '... Util.order_id example: short_order0.01 22/0XTS4NjtfjcaMkJsUiWSTz5sGQkxWr5Xwogqt', hash_str
    #    hash.ripemd160 hash_str
    
exports.Util = Util