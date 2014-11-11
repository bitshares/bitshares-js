assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{Operation} = require './operation'
{fc} = require '../common/fc_parser'

###
bts::blockchain::transaction, (expiration)(delegate_slate_id)(operations)
    fc::time_ _sec expiration
    optional slait_id_type uint64_t
    vector<operation>           operations
    
bts::blockchain::operation, (type)(data)
    fc::enum_type<uint8_t,operation_type_enum> type;
    std::vector<char> data;
###
class Transaction
    
    constructor: (@expiration, @delegate_slate_id, @operations) ->
        
    Transaction.fromByteBuffer = (b) ->
        expiration = fc.time_point_sec b
        throw "Delegate slate is not implemented" if fc.optional b
        delegate_slate_id = null
        operations = []
        operations_count = b.readVarint32()
        for i in [1..operations_count]
            operations.push Operation.fromByteBuffer b 
        
        new Transaction(expiration, delegate_slate_id, operations)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        
        
        return b.copy 0, b.offset
        
    ### <HEX> ###
    
    Transaction.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###
    
exports.Transaction = Transaction
