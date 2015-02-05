q = require 'q'

# Subset of blockchain api used by jslib.  This file may be generated
# in the future.

class BlockchainAPI

  constructor: (@rpc) ->
  
  # Returns current blockchain information and parameters
  # parameters: 
  # return_type: `json_object`
  get_info: (error_handler = null) ->
    @rpc.request('blockchain_get_info').then (response) ->
      response.result
  
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
  
  # Lists balance records which can be claimed by signature for this key
  # parameters: 
  #   public_key `key` - Key to scan for
  # return_type: `balance_record_map`
  list_key_balances: (key, error_handler = null) ->
    @rpc.request('blockchain_list_key_balances', [key]).then (response) ->
      response.result

  # Takes a signed transaction and broadcasts it to the network.
  # parameters: 
  #   signed_transaction `trx` - The transaction to broadcast
  # return_type: `void`
  broadcast_transaction: (trx, error_handler = null) ->
    @rpc.request('blockchain_broadcast_transaction', [trx]).then (response) ->
      response.result

  # Returns the status of a particular market, including any trading errors.
  # parameters: 
  #   asset_symbol `quote_symbol` - quote symbol
  #   asset_symbol `base_symbol` - base symbol
  # return_type: `market_status`
  market_status: (quote_symbol, base_symbol, error_handler = null) ->
    @rpc.request('blockchain_market_status', [quote_symbol, base_symbol]).then (response) ->
      response.result
  
exports.BlockchainAPI = BlockchainAPI