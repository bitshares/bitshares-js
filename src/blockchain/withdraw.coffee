assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'

###
bts::blockchain::withdraw_operation, (balance_id)(amount)(claim_input_data)
    fc::ripemd160 address balance_id_type balance_id
    int64_t share_type amount
    std::vector<char> claim_input_data
###
class Withdraw

    constructor: (@balance_id, @amount, @claim_input_data) ->
        
    Withdraw.fromByteBuffer= (b) ->
        balance_id = fp.ripemd160 b
        amount = b.readInt64()
        claim_input_data = fp.variable_buffer b
        new Withdraw(balance_id, amount, claim_input_data)
        
    appendByteBuffer: (b) ->
        fp.ripemd160 b, @balance_id
        b.writeInt64(@amount)
        fp.variable_buffer b, @claim_input_data
        
    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return new Buffer(b.copy(0, b.offset).toBinary(), 'binary')
    
    ### <HEX> ###
    
    Withdraw.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.Withdraw = Withdraw
