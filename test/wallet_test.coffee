wallet_object = require './fixtures/wallet.json'
{WalletAPI} = require '../src/client/wallet_api'
{WalletDb} = require '../src/wallet/wallet_db'

describe "Wallet API", ->
    ###
    rpc_on: ->
        @rpc=new Rpc(debug=on, process.env.RPC_PORT, "localhost", "test", "test")
    
    rpc_off: ->
        @rpc.close()
    ###
    
    it "backup_restore_object", (done) ->
        wallet_api = new WalletAPI()
        WalletDb.delete "default" # prior run failed
        wallet_api.backup_restore_object(wallet_object, "default",#).then(
            (wallet_db)->
                throw 'missing wallet_db' unless wallet_db
                WalletDb.delete wallet_db.wallet_name
                done()
        )#.done()