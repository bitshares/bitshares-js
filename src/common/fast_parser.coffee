class CommonParser
    
    CommonParser.optional = (b) ->
        if b.readUint8() is 1 then b
    
    CommonParser.variable_data = (b) ->
        return unless b 
        len = b.readVarint32()
        b_copy = b.copy(b.offset, b.offset + len); b.skip len
        new Buffer(b_copy.toBinary(), 'binary')
            
    CommonParser.fixed_data = (b, len) ->
        return unless b 
        b_copy = b.copy(b.offset, b.offset + len); b.skip len
        new Buffer(b_copy.toBinary(), 'binary')

class EccParser extends CommonParser
    
    {Signature} = require '../ecc/signature'
    {PublicKey} = require '../ecc/key_public'
    
    EccParser.public_key = (b) ->
        return unless b
        buffer = CommonParser.fixed_data b, 33
        PublicKey.fromBuffer buffer
    
    EccParser.signature = (b) ->
        return unless b
        buffer = CommonParser.fixed_data b, 65
        Signature.fromBuffer buffer
        
    EccParser.ripemd160 = (b) ->
        return unless b
        CommonParser.fixed_data b, 20
    
class FastParser extends EccParser
    
    FastParser.time_point_sec = (b) ->
        epoch = b.readInt32() # fc::time_point_sec
        new Date(epoch * 1000)
        
exports.fp = FastParser