assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
{WithdrawCondition} = require './withdraw_condition'
types = require './types'

###
bts::blockchain::deposit_operation, (amount)(condition)
    int64_t share_type amount
    withdraw_condition // condition that the funds may be withdrawn
###
class Deposit

    type_id = types.operation["deposit_op_type"]

    constructor: (@amount, @withdraw_condition) ->
        
    Deposit.fromByteBuffer= (b) ->
        amount = b.readInt64()
        withdraw_condition = WithdrawCondition.fromByteBuffer b
        new Deposit(amount, withdraw_condition)
        
    appendByteBuffer: (b) ->
        b.writeInt64(@amount)
        @withdraw_condition.appendByteBuffer(b)
        
    toJson: (o) ->
        o.amount = @amount.toString()
        o.condition = {}
        @withdraw_condition.toJson(o.condition)
        
    ### <helper_functions> ###
    
    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b_copy = b.copy(0, b.offset)
        return new Buffer(b_copy.toBinary(), 'binary')
    
    Deposit.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Deposit = Deposit
