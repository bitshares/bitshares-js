assert = require("assert")

wallet_object = require './fixtures/wallet.json'
wallet = require '../src/wallet'
Wallet = wallet.Wallet

describe "Wallet", ->
    it "Serilizes unchanged", ->
        wallet = Wallet.fromObject wallet_object
        wallet_json = wallet.toJson(0)
        assert.equal JSON.stringify(wallet_object, undefined, 0), wallet_json
        
        