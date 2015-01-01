
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
            
exports.BlockchainAPI = BlockchainAPI