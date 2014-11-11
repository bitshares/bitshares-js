assert = require 'assert'
ByteBuffer = require 'bytebuffer'
{fc} = require '../common/fc_parser'

###
bts::blockchain::withdraw_operation, (balance_id)(amount)(claim_input_data)
    fc::ripemd160 address balance_id_type balance_id
    int64_t share_type amount
    std::vector<char> claim_input_data
###
class Withdraw

    constructor: (@balance_id, @amount, @claim_input_data) ->
        
    Withdraw.fromByteBuffer= (b) ->
        balance_id = fc.ripemd160 b
        amount = b.readInt64()
        claim_input_data = fc.variable_data b
        new Withdraw(balance_id, amount, claim_input_data)
        
    toByteBuffer: () ->
        b = new ByteBuffer ByteBuffer.DEFAULT_CAPACITY, ByteBuffer.LITTLE_ENDIAN
        throw 'Not Implemented'
        return b.copy 0, b.offset
        
    ### <HEX> ###
    
    Withdraw.fromHex= (hex) ->
        b = ByteBuffer.fromHex hex, ByteBuffer.LITTLE_ENDIAN
        return SignedTransaction.fromByteBuffer b

    toHex: () ->
        b=@toByteBuffer()
        b.toHex()
        
    ### </HEX> ###

exports.Withdraw = Withdraw
