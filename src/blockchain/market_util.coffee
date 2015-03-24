BigInteger = require 'bigi'
ByteBuffer = require 'bytebuffer'
{hex2dec} = require '../common/hex2dec'

class Util
    
    Util.read_price=(b)->
        b_copy = b.copy(b.offset, b.offset + 16); b.skip 16
        #console.log '1',b_copy.toHex()
        ratio: BigInteger.fromBuffer new Buffer b_copy.toBinary(), 'binary'
        quote_asset_id: b.readVarint32ZigZag()
        base_asset_id: b.readVarint32ZigZag()
    
    Util.write_price=(b, price)->
        ratio_buffer = price.ratio.toBuffer()
        ratio_buffer_target = new Buffer(16)
        ratio_buffer_target.fill 0
        ratio_buffer.copy ratio_buffer_target, 16 - ratio_buffer.length
        #console.log '2',(ByteBuffer.fromBinary ratio_buffer_target.toString 'binary').toHex()
        b.append ByteBuffer.fromBinary ratio_buffer_target.toString 'binary'
        b.writeVarint32ZigZag price.quote_asset_id
        b.writeVarint32ZigZag price.base_asset_id
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