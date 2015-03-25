BigInteger = require 'bigi'
ByteBuffer = require 'bytebuffer'
{hex2dec} = require '../common/hex2dec'

class Util
    
    Util.read_price=(b)->
        b_copy = b.copy(b.offset, b.offset + 16); b.skip 16
        target_array = new Uint8Array(16)
        index=0
        target_array[index++] = b_copy.readByte(i) for i in [7..0] by -1
        target_array[index++] = b_copy.readByte(i) for i in [15..8] by -1
        #console.log '... target_array', new Buffer(target_array).toString 'hex'
        ratio: BigInteger.fromBuffer new Buffer target_array
        quote: b.readVarint32ZigZag()
        base: b.readVarint32ZigZag()
    
    Util.write_price=(b, price)->
        ratio_array = price.ratio.toByteArray()
        target_array = new Uint8Array(16)
        target_array.set ratio_array, 16-ratio_array.length # pad
        b.writeUint8 target_array[i] for i in [7..0] by -1
        b.writeUint8 target_array[i] for i in [15..8] by -1
        #b.writeUint8 0xFF
        b.writeVarint32ZigZag price.quote
        #b.writeUint8 0xFF
        b.writeVarint32ZigZag price.base
        return
        
    Util.unreal128=(ratio)->
        str = hex2dec ratio.toHex()
        str = "0"+str for i in [0...18-str.length] by 1
        str = str.slice(0,idx=str.length-18)+'.'+str.slice idx
        str = str.replace /^0+/g, "" # remove leading zeros
        str = str.replace /\.?0+$/g, "" # traling zeros
        str = "0"+str if str.indexOf('.') is 0
        str

exports.Util = Util