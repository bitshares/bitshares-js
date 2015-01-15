q = require 'q'

# Subset of blockchain api used by jslib.  This file may be generated
# in the future.

class BlockchainAPI

  constructor: (@rpc) ->
  
  # Retrieves the record for the given asset ticker symbol or ID
  # parameters: 
  #   string `asset` - asset ticker symbol or ID to retrieve
  # return_type: `optional_asset_record`
  get_asset: (asset) ->
    @rpc.request('blockchain_get_asset', [asset]).then (response) ->
       response.result
  
  # Retrieves the record for the given account name or ID
  # parameters: 
  #   string `account` - account name, ID, or public key to retrieve the record for
  # return_type: `optional_account_record`
  get_account: (account) ->
    @rpc.request('blockchain_get_account', [account]).then (response) ->
       response.result
  
  # Lists balance records which are the balance IDs or which can be claimed by signature for this address
  # parameters: 
  #   string `addr` - address to scan for
  # return_type: `balance_record_list`
  list_address_balances: (addr, error_handler = null) ->
    @rpc.request('blockchain_list_address_balances', [addr]).then (response) ->
      response.result

  # Takes a signed transaction and broadcasts it to the network.
  # parameters: 
  #   signed_transaction `trx` - The transaction to broadcast
  # return_type: `void`
  broadcast_transaction: (trx, error_handler = null) ->
    @rpc.request('blockchain_broadcast_transaction', [trx]).then (response) ->
      response.result

exports.BlockchainAPI = BlockchainAPI