
{Rpc} = require "../lib/rpc_json"
{RelayNode} = require '../../src/net/relay_node'

describe "Network", ->
    
    beforeEach ->
        RPC_DEBUG=process.env.RPC_DEBUG
        RPC_DEBUG=off if RPC_DEBUG is undefined
        @rpc=new Rpc(RPC_DEBUG, 45000, "localhost", "test", "test")
    
    afterEach ->
        @rpc.close()
    
    it "fetch_welcome_package", (done) ->
        rn = new RelayNode @rpc
        rn.initialize().then( ->
            rn.initialized_or_throw()
            done()
        ).done()
    