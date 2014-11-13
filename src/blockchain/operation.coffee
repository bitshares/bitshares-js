assert = require 'assert'
ByteBuffer = require 'bytebuffer'
types = require './types'
{fp} = require '../common/fast_parser'
{Deposit} = require './deposit'
{Withdraw} = require './withdraw'

###
bts::blockchain::operation, (type)(data)
    fc::enum_type<uint8_t,operation_type_enum> type;
    std::vector<char> data;
###
class Operation

    constructor: (@type_id, @operation) ->
        
    type: () ->
        types.operation[@type_id]
    
    Operation.fromByteBuffer= (b) ->
        type_id = b.readUint8()
        data_b = fp.variable_bytebuffer b
        operation = switch types.operation[type_id]
            when "deposit_op_type"
                Deposit.fromByteBuffer data_b
            when "withdraw_op_type"
                Withdraw.fromByteBuffer data_b
            else
                throw "Not Implemented"
        
        new Operation(type_id, operation)
        
    appendByteBuffer: (b) ->
        b.writeUint8(@type_id)
        fp.variable_buffer b, @operation.toBuffer()
        
    toJson: (o) ->
        o.type = @type()
        o.data = {}
        @operation.toJson(o.data)
        
    ### <HEX> ###
    
    Operation.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.Operation = Operation
