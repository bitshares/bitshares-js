assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
{WithdrawCondition} = require './withdraw_condition'

###
bts::blockchain::deposit_operation, (amount)(condition)
    int64_t share_type amount
    withdraw_condition // condition that the funds may be withdrawn
###
class Deposit

    constructor: (@amount, @withdraw_condition) ->
        
    Deposit.fromByteBuffer= (b) ->
        amount = b.readInt64()
        withdraw_condition = WithdrawCondition.fromByteBuffer b
        new Deposit(amount, withdraw_condition)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        throw 'Not Implemented'
        return b.copy 0, b.offset
        
    ### <HEX> ###
    
    Deposit.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.Deposit = Deposit
