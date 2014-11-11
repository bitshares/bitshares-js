assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{Operation} = require './operation'
{fp} = require '../common/fast_parser'

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
        expiration = fp.time_point_sec b
        throw "Delegate slate is not implemented" if fp.optional b
        delegate_slate_id = null
        operations = []
        operations_count = b.readVarint32()
        for i in [1..operations_count]
            operations.push Operation.fromByteBuffer b 
        
        new Transaction(expiration, delegate_slate_id, operations)
      
    appendByteBuffer: (b) ->
        fp.time_point_sec b, @expiration
        fp.optional b, null # delegate_slate_id
        b.writeVarint32(@operations.length)
        for operation in @operations
            operation.appendByteBuffer(b)
        
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b.copy 0, b.offset
    
    toBuffer: () ->
        new Buffer(@toByteBuffer().toBinary(), 'binary')
    
    ### <HEX> ###
    
    Transaction.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###
    
exports.Transaction = Transaction
