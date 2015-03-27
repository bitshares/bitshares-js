class CommonParser
    
    ###
        Warning: This method expects null (not undefined) to indicate 
        that a value is not present.
    ###
    CommonParser.optional = (b, value) ->
        if value isnt undefined
            if value is null
                b.writeUint8(0)
                return null
            else
                b.writeUint8(1)
                return b
        else
            if b.readUint8() is 1 
                b 
            else 
                null
    
    CommonParser.variable_buffer = (b, data_buffer) ->
        return unless b
        if data_buffer
            b.writeVarint32(data_buffer.length)
            b.append(data_buffer.toString('binary'), 'binary')
            return
        else
            len = b.readVarint32()
            b_copy = b.copy(b.offset, b.offset + len); b.skip len
            new Buffer(b_copy.toBinary(), 'binary')
            
    CommonParser.variable_bytebuffer = (b, data_bytebuffer) ->
        throw "Not Implemented" if data_bytebuffer
        return unless b
        len = b.readVarint32()
        b_copy = b.copy(b.offset, b.offset + len); b.skip len
        b_copy
            
    CommonParser.fixed_data = (b, len, buffer) ->
        return unless b 
        if buffer
            data = buffer.slice(0, len).toString('binary')
            b.append data, 'binary'
            while len-- > data.length
                b.writeUint8 0
            return
        else
            b_copy = b.copy(b.offset, b.offset + len); b.skip len
            new Buffer(b_copy.toBinary(), 'binary')

class EccParser extends CommonParser
    
    {Signature} = require '../ecc/signature'
    {PublicKey} = require '../ecc/key_public'
    
    EccParser.public_key = (b, public_key) ->
        return unless b
        if public_key
            buffer = public_key.toBuffer()
            b.append(buffer.toString('binary'), 'binary')
            return
        else
            buffer = CommonParser.fixed_data b, 33
            PublicKey.fromBuffer buffer
    
    EccParser.signature = (b, signature) ->
        return unless b
        if signature
            buffer = signature.toBuffer()
            CommonParser.fixed_data b, 65, buffer
            return
        else
            buffer = CommonParser.fixed_data b, 65
            Signature.fromBuffer buffer
        
    EccParser.ripemd160 = (b, ripemd160) ->
        return unless b
        if ripemd160
            CommonParser.fixed_data b, 20, ripemd160
            return
        else
            CommonParser.fixed_data b, 20
    
class FastParser extends EccParser
    
    FastParser.time_point_sec = (b, epoch) ->
        if epoch
            # if even the transaction will not 
            # be valid (signature assertion exception)
            epoch = Math.ceil(epoch / 1000)
            #if epoch % 2 is 0
            #    console.log 'WARN: fc may reject epoch value: '+epoch
            b.writeInt32 epoch
            return
        else
            epoch = b.readInt32() # fc::time_point_sec
            new Date epoch * 1000
        
exports.fp = FastParser