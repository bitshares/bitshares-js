assert = require 'assert'
ByteBuffer = require 'bytebuffer'
types = require './types'
{fc} = require '../common/fc_parser'
Deposit = require './deposit'
Withdraw = require './withdraw'

###
bts::blockchain::operation, (type)(data)
    fc::enum_type<uint8_t,operation_type_enum> type;
    std::vector<char> data;
###
class Operation

    constructor: (@type_id, @b_data) ->
        
    type: () ->
        types.operation[@type_id]
    
    Operation.fromByteBuffer= (b) ->
        type_id = b.readUint8()
        b_data = fc.variable_data b
        new Operation(type_id, b_data)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        throw 'Not Implemented'
        return b.copy 0, b.offset
        
    toDeposit: ->
        assert.equal "deposit_op_type", @type()
        Deposit.fromByteBuffer @data
        
    toWithdraw: ->
        assert.equal "withdraw_op_type", @type()
        Withdraw.fromByteBuffer @data
        
    ### <HEX> ###
    
    Operation.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.Operation = Operation
