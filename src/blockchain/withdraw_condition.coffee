assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'

###
bts::blockchain::withdraw_condition, (asset_id)(delegate_slate_id)(type)(data)
    varint32 fc::signed_int asset_id_type asset_id
    uint64_t slate_id_type delegate_slate_id
    fc::enum_type<uint8_t, withdraw_condition_types> type
    std::vector<char> data
###
class WithdrawCondition

    constructor: (@asset_id, @delegate_slate_id, @type_id, @b_data) ->
        
    type: () ->
        types.withdraw[@type_id]

    WithdrawCondition.fromByteBuffer= (b) ->
        asset_id = b.readVarint32()
        delegate_slate_id = b.readVarint64()
        type_id = b.readUint8()
        b_data = fp.variable_data b
        new WithdrawCondition(asset_id, delegate_slate_id, type_id, b_data)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        throw 'Not Implemented'
        return b.copy 0, b.offset
        
    ### <HEX> ###
    
    WithdrawCondition.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.WithdrawCondition = WithdrawCondition
