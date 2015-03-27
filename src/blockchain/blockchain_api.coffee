q = require 'q'

# Subset of blockchain api used by jslib.  This file may be generated
# in the future.

class BlockchainAPI

  constructor: (@rpc) ->
  
  # Returns current blockchain information and parameters
  # parameters: 
  # return_type: `json_object`
  get_info: (error_handler = null) ->
    @rpc.request('blockchain_get_info',[], error_handler).then (response) ->
      response.result
  
  # Retrieves the record for the given asset ticker symbol or ID
  # parameters: 
  #   string `asset` - asset ticker symbol or ID to retrieve
  # return_type: `optional_asset_record`
  get_asset: (asset, error_handler = null) ->
    @rpc.request('blockchain_get_asset', [asset], error_handler).then (response) ->
       response.result
  
  # Retrieves the record for the given account name or ID
  # parameters: 
  #   string `account` - account name, ID, or public key to retrieve the record for
  # return_type: `optional_account_record`
  get_account: (account, error_handler = null) ->
    @rpc.request('blockchain_get_account', [account], error_handler).then (response) ->
       response.result
  
  # Lists balance records which can be claimed by signature for this key
  # parameters: 
  #   public_key `key` - Key to scan for
  # return_type: `balance_record_map`
  list_key_balances: (key, error_handler = null) ->
    @rpc.request('blockchain_list_key_balances', [key], error_handler).then (response) ->
      response.result

  # Takes a signed transaction and broadcasts it to the network.
  # parameters: 
  #   signed_transaction `trx` - The transaction to broadcast
  # return_type: `void`
  broadcast_transaction: (trx, error_handler = null) ->
    @rpc.request('blockchain_broadcast_transaction', [trx], error_handler).then (response) ->
      response.result

  # Returns hash of block in best-block-chain at index provided
  # parameters: 
  #   uint32_t `block_number` - index of the block, example: 42
  # return_type: `block_id_type`
  get_block_hash: (block_number, error_handler = null) ->
    @rpc.request('blockchain_get_block_hash', [block_number], error_handler).then (response) ->
      response.result

  # Returns the status of a particular market, including any trading errors.
  # parameters: 
  #   asset_symbol `quote_symbol` - quote symbol
  #   asset_symbol `base_symbol` - base symbol
  # return_type: `market_status`
  market_status: (quote_symbol, base_symbol, error_handler = null) ->
    @rpc.request('blockchain_market_status', [quote_symbol, base_symbol], error_handler).then (response) ->
      response.result

  # Returns the long and short sides of the order book for a given market
  # parameters: 
  #   asset_symbol `quote_symbol` - the symbol name the market is quoted in
  #   asset_symbol `base_symbol` - the item being bought in this market
  #   uint32_t `limit` - the maximum number of items to return, -1 for all
  # return_type: `pair<market_order_array,market_order_array>`
  market_order_book: (quote_symbol, base_symbol, limit, error_handler = null) ->
    @rpc.request('blockchain_market_order_book', [quote_symbol, base_symbol, limit], error_handler).then (response) ->
      response.result
  
  list_address_orders: (quote_symbol, base_symbol, address, limit, error_handler = null) ->
    @rpc.request('blockchain_list_address_orders', [quote_symbol, base_symbol, address, limit], error_handler).then (response) ->
      response.result

  get_market_order: (order_id, error_handler = null) ->
    @rpc.request('blockchain_get_market_order', [order_id], error_handler).then (response) ->
      response.result

  
exports.BlockchainAPI = BlockchainAPI
