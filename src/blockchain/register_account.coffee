assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fp} = require '../common/fast_parser'
{WithdrawCondition} = require './withdraw_condition'
types = require './types'
type_id = types.type_id

###
bts::blockchain::register_account_operation, 
    (name)(public_data)(owner_key)(active_key)(delegate_pay_rate)(meta_data)
    string name
    variant public_data
    public_key_type             owner_key;
    public_key_type             active_key;
    uint8_t                     delegate_pay_rate = -1;
    optional<account_meta_info> meta_data

bts::blockchain::public_key_type, (key_data)
    fc::array<char,33> fc::ecc::public_key_data key_data

bts::blockchain::account_meta_info, (type) (data)
    fc::enum_type<fc::unsigned_int,account_type> type;
    vector<char>                                 data;
    
struct unsigned_int { ... unsigned_int( uint32_t

enum account_type {
    titan_account    = 0,
    public_account   = 1,
    multisig_account = 2
}
###
class RegisterAccount

    RegisterAccount.type=
        titan_account: 0
        public_account: 1
        multisig_account: 2
    
    constructor: (
        @name, @public_data, @owner_key, @active_key
        @delegate_pay_rate, @meta_data
    ) ->
        @type_name = "register_account_op_type"
        @type_id = type_id types.operation, @type_name        
        
    RegisterAccount.fromByteBuffer= (b) ->
        name = fp.variable_buffer b
        public_data = {} #JSON.parse fp.variable_buffer b
        owner_key = fp.public_key
        active_key = fp.public_key
        delegate_pay_rate = b.readUint8()
        if delegate_pay_rate is 255
            delegate_pay_rate = -1
        
        meta_data = null
        if fc.optional b
            meta_data=
                type: b.readUint32()
                data: fp.variable_buffer b
                
        new RegisterAccount(
            name, public_data, owner_key, active_key
            delegate_pay_rate, meta_data
        )
    
    appendByteBuffer: (b) ->
        fp.variable_buffer b, @name.toString()
        fp.variable_buffer b, new Buffer("")#JSON.stringify @public_data)
        fp.public_key b, @owner_key
        fp.public_key b, @active_key
        if @delegate_pay_rate is -1
            b.writeUint8 255
        else
            b.writeUint8 @delegate_pay_rate
        
        if fp.optional b, @meta_data
            b.writeUint32 @meta_data.type
            fp.variable_buffer b, @meta_data.data

    toBuffer: ->
        b = new ByteBuffer(ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN)
        @appendByteBuffer(b)
        b_copy = b.copy(0, b.offset)
        return new Buffer(b_copy.toBinary(), 'binary')
    
    toJson: (o) ->
        o.name = @name.toString()
        o.public_data = @public_data
        o.owner_key = @owner_key.toBtsPublic()
        o.active_key = @active_key.toBtsPublic()
        if @delegate_pay_rate is -1
            o.delegate_pay_rate = 255
        else
            o.delegate_pay_rate = @delegate_pay_rate
        o.meta_data = unless @meta_data then null
        else
            o.meta_data =
                type: @meta_data.type
                data: @meta_data.data.toString()
    
exports.RegisterAccount = RegisterAccount
