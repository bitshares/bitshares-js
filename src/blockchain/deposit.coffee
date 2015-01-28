assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
{WithdrawCondition} = require './withdraw_condition'
types = require './types'
type_id = types.type_id
LE = require('../common/exceptions').LocalizationException

###
bts::blockchain::deposit_operation, (amount)(condition)
    int64_t share_type amount
    withdraw_condition // condition that the funds may be withdrawn
###
class Deposit

    constructor: (@amount, @withdraw_condition) ->
        LE.throw 'general.positive_amount',[amount] unless amount > 0
        @type_name = "deposit_op_type"
        @type_id = type_id types.operation, @type_name        
        
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
    
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return b.copy 0, b.offset

    toBuffer: () ->
        b = @toByteBuffer()
        new Buffer(b.toBinary(), 'binary')
    
    #Deposit.fromHex= (hex) ->
    #    b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
    #    return Deposit.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.Deposit = Deposit
