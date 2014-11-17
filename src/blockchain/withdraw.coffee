assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
types = require './types'

###
bts::blockchain::withdraw_operation, (balance_id)(amount)(claim_input_data)
    fc::ripemd160 address balance_id_type balance_id
    int64_t share_type amount
    std::vector<char> claim_input_data
###
class Withdraw

    type = "withdraw_op_type"
    type_id = types.operation[type]
        
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
        
    toJson: (o) ->
        o.balance_id = @balance_id.toString('hex')
        o.amount = @amount.toString()
        o.claim_input_data = @claim_input_data.toString()
    
    ### <helper_functions> ###   
    
    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return new Buffer(b.copy(0, b.offset).toBinary(), 'binary')

    
    Withdraw.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Withdraw = Withdraw
