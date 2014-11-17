assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
{WithdrawSignatureType} = require './withdraw_signature_type'
types = require './types'
type_id = types.type_id
ecc = require '../ecc'
PublicKey = ecc.PublicKey
Address = ecc.Address

###
bts::blockchain::withdraw_condition, (asset_id)(delegate_slate_id)(type)(data)
    varint32 fc::signed_int asset_id_type asset_id
    uint64_t slate_id_type delegate_slate_id
    fc::enum_type<uint8_t, withdraw_condition_types> type
    std::vector<char> data
###
class WithdrawCondition

    constructor: (@asset_id, @delegate_slate_id, @type_id, @condition) ->
        
    type: () ->
        types.withdraw[@type_id]

    WithdrawCondition.fromByteBuffer= (b) ->
        asset_id = b.readVarint32()
        delegate_slate_id = b.readInt64()
        type_id = b.readUint8()
        data = fp.variable_bytebuffer b
        switch types.withdraw[type_id]
            when "withdraw_signature_type"
                condition = WithdrawSignatureType.fromByteBuffer(data)
            else
                throw "Not Implemented"
        
        new WithdrawCondition(asset_id, delegate_slate_id, type_id, condition)
        
    appendByteBuffer: (b) ->
        b.writeVarint32(@asset_id)
        b.writeInt64(@delegate_slate_id)
        b.writeUint8(@type_id)
        fp.variable_buffer b, @condition.toBuffer()
        
    toJson: (o) ->
        o.asset_id = @asset_id
        o.delegate_slate_id = @delegate_slate_id.toString()
        o.type = @type()
        @condition.toJson(o.data = {})
        
    WithdrawCondition.fromJson= (o) ->
        assert.equal "withdraw_signature_type", o.type
        assert data = o.data, 'Missing data property'
        assert memo = data.memo, 'Missing memo property'
        new WithdrawCondition(
            o.asset_id, 
            o.delegate_slate_id=0, 
            type_id(types.withdraw, "withdraw_signature_type"), 
            new WithdrawSignatureType(
                Address.fromString(data.owner).toBuffer(), 
                PublicKey.fromBtsPublic(memo.one_time_key),
                new Buffer(memo.encrypted_memo_data, 'hex')
            )
        )
    
    ### <helper_functions> ###
    
    toByteBuffer: () ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        return b.copy 0, b.offset
        
    toBuffer: () ->
        b = @toByteBuffer()
        new Buffer(b.toBinary(), 'binary')
        
    WithdrawCondition.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </helper_functions> ###

exports.WithdrawCondition = WithdrawCondition
