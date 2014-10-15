// Warning: this is a generated file, any changes made here will be overwritten by the build process
'use strict'

module.exports = {
  WalletAPI : WalletAPI
}

function WalletAPI(rpc) {
   this.rpc=rpc
}


// Extra information about the wallet.
// parameters: 
// return_type: `json_object`
WalletAPI.prototype.get_info = function() {
  return this.rpc.request('wallet_get_info', []).then (function(response) {
    return response.result;
  });
};

// Opens the wallet of the given name
// parameters: 
  //   wallet_name `wallet_name` - the name of the wallet to open
// return_type: `void`
WalletAPI.prototype.open = function(wallet_name) {
  return this.rpc.request('wallet_open', [wallet_name]).then (function(response) {
    return response.result;
  });
};

// Creates a wallet with the given name
// parameters: 
  //   wallet_name `wallet_name` - name of the wallet to create
  //   new_passphrase `new_passphrase` - a passphrase for encrypting the wallet
  //   brainkey `brain_key` - a strong passphrase that will be used to generate all private keys, defaults to a large random number
// return_type: `void`
WalletAPI.prototype.create = function(wallet_name, new_passphrase, brain_key) {
  return this.rpc.request('wallet_create', [wallet_name, new_passphrase, brain_key]).then (function(response) {
    return response.result;
  });
};

// Returns the wallet name passed to wallet_open
// parameters: 
// return_type: `optional_wallet_name`
WalletAPI.prototype.get_name = function() {
  return this.rpc.request('wallet_get_name', []).then (function(response) {
    return response.result;
  });
};

// Loads the private key into the specified account. Returns which account it was actually imported to.
// parameters: 
  //   wif_private_key `wif_key` - A private key in bitcoin Wallet Import Format (WIF)
  //   account_name `account_name` - the name of the account the key should be imported into, if null then the key must belong to an active account
  //   bool `create_new_account` - If true, the wallet will attempt to create a new account for the name provided rather than import the key into an existing account
  //   bool `rescan` - If true, the wallet will rescan the blockchain looking for transactions that involve this private key
// return_type: `account_name`
WalletAPI.prototype.import_private_key = function(wif_key, account_name, create_new_account, rescan) {
  return this.rpc.request('wallet_import_private_key', [wif_key, account_name, create_new_account, rescan]).then (function(response) {
    return response.result;
  });
};

// Imports a Bitcoin Core or BitShares PTS wallet
// parameters: 
  //   filename `wallet_filename` - the Bitcoin/PTS wallet file path
  //   passphrase `passphrase` - the imported wallet's password
  //   account_name `account_name` - the account to receive the contents of the wallet
// return_type: `void`
WalletAPI.prototype.import_bitcoin = function(wallet_filename, passphrase, account_name) {
  return this.rpc.request('wallet_import_bitcoin', [wallet_filename, passphrase, account_name]).then (function(response) {
    return response.result;
  });
};

// Imports an Armory wallet
// parameters: 
  //   filename `wallet_filename` - the Armory wallet file path
  //   passphrase `passphrase` - the imported wallet's password
  //   account_name `account_name` - the account to receive the contents of the wallet
// return_type: `void`
WalletAPI.prototype.import_armory = function(wallet_filename, passphrase, account_name) {
  return this.rpc.request('wallet_import_armory', [wallet_filename, passphrase, account_name]).then (function(response) {
    return response.result;
  });
};

// Imports an Electrum wallet
// parameters: 
  //   filename `wallet_filename` - the Electrum wallet file path
  //   passphrase `passphrase` - the imported wallet's password
  //   account_name `account_name` - the account to receive the contents of the wallet
// return_type: `void`
WalletAPI.prototype.import_electrum = function(wallet_filename, passphrase, account_name) {
  return this.rpc.request('wallet_import_electrum', [wallet_filename, passphrase, account_name]).then (function(response) {
    return response.result;
  });
};

// Imports a Multibit wallet
// parameters: 
  //   filename `wallet_filename` - the Multibit wallet file path
  //   passphrase `passphrase` - the imported wallet's password
  //   account_name `account_name` - the account to receive the contents of the wallet
// return_type: `void`
WalletAPI.prototype.import_multibit = function(wallet_filename, passphrase, account_name) {
  return this.rpc.request('wallet_import_multibit', [wallet_filename, passphrase, account_name]).then (function(response) {
    return response.result;
  });
};

// Create the key from keyhotee config and import it to the wallet, creating a new account using this key
// parameters: 
  //   name `firstname` - first name in keyhotee profile config, for salting the seed of private key
  //   name `middlename` - middle name in keyhotee profile config, for salting the seed of private key
  //   name `lastname` - last name in keyhotee profile config, for salting the seed of private key
  //   brainkey `brainkey` - brainkey in keyhotee profile config, for salting the seed of private key
  //   keyhoteeid `keyhoteeid` - using keyhotee id as account name
// return_type: `void`
WalletAPI.prototype.import_keyhotee = function(firstname, middlename, lastname, brainkey, keyhoteeid) {
  return this.rpc.request('wallet_import_keyhotee', [firstname, middlename, lastname, brainkey, keyhoteeid]).then (function(response) {
    return response.result;
  });
};

// Closes the curent wallet if one is open
// parameters: 
// return_type: `void`
WalletAPI.prototype.close = function() {
  return this.rpc.request('wallet_close', []).then (function(response) {
    return response.result;
  });
};

// Exports the current wallet to a JSON file
// parameters: 
  //   filename `json_filename` - the full path and filename of JSON file to generate, example: /path/to/exported_wallet.json
// return_type: `void`
WalletAPI.prototype.backup_create = function(json_filename) {
  return this.rpc.request('wallet_backup_create', [json_filename]).then (function(response) {
    return response.result;
  });
};

// Creates a new wallet from an exported JSON file
// parameters: 
  //   filename `json_filename` - the full path and filename of JSON wallet to import, example: /path/to/exported_wallet.json
  //   wallet_name `wallet_name` - name of the wallet to create
  //   passphrase `imported_wallet_passphrase` - passphrase of the imported wallet
// return_type: `void`
WalletAPI.prototype.backup_restore = function(json_filename, wallet_name, imported_wallet_passphrase) {
  return this.rpc.request('wallet_backup_restore', [json_filename, wallet_name, imported_wallet_passphrase]).then (function(response) {
    return response.result;
  });
};

// Enables or disables automatic wallet backups
// parameters: 
  //   bool `enabled` - true to enable and false to disable
// return_type: `bool`
WalletAPI.prototype.set_automatic_backups = function(enabled) {
  return this.rpc.request('wallet_set_automatic_backups', [enabled]).then (function(response) {
    return response.result;
  });
};

// Lists transaction history for the specified account
// parameters: 
  //   string `account_name` - the name of the account for which the transaction history will be returned, "" for all accounts, example: alice
  //   string `asset_symbol` - only include transactions involving the specified asset, or "" to include all
  //   int32_t `limit` - limit the number of returned transactions; negative for most recent and positive for least recent. 0 does not limit
  //   uint32_t `start_block_num` - the earliest block number to list transactions from; 0 to include all transactions starting from genesis
  //   uint32_t `end_block_num` - the latest block to list transaction from; -1 to include all transactions ending at the head block
// return_type: `pretty_transactions`
WalletAPI.prototype.account_transaction_history = function(account_name, asset_symbol, limit, start_block_num, end_block_num) {
  return this.rpc.request('wallet_account_transaction_history', [account_name, asset_symbol, limit, start_block_num, end_block_num]).then (function(response) {
    return response.result;
  });
};

// Removes the specified transaction record from your transaction history. USE WITH CAUTION! Rescan cannot reconstruct all transaction details
// parameters: 
  //   string `transaction_id` - the id (or id prefix) of the transaction record
// return_type: `void`
WalletAPI.prototype.transaction_remove = function(transaction_id) {
  return this.rpc.request('wallet_transaction_remove', [transaction_id]).then (function(response) {
    return response.result;
  });
};

// Return any errors for your currently pending transactions
// parameters: 
  //   string `filename` - filename to save pending transaction errors to
// return_type: `map<transaction_id_type, fc::exception>`
WalletAPI.prototype.get_pending_transaction_errors = function(filename) {
  return this.rpc.request('wallet_get_pending_transaction_errors', [filename]).then (function(response) {
    return response.result;
  });
};

// Lock the private keys in wallet, disables spending commands until unlocked
// parameters: 
// return_type: `void`
WalletAPI.prototype.lock = function() {
  return this.rpc.request('wallet_lock', []).then (function(response) {
    return response.result;
  });
};

// Unlock the private keys in the wallet to enable spending operations
// parameters: 
  //   uint32_t `timeout` - the number of seconds to keep the wallet unlocked
  //   passphrase `passphrase` - the passphrase for encrypting the wallet
// return_type: `void`
WalletAPI.prototype.unlock = function(timeout, passphrase) {
  return this.rpc.request('wallet_unlock', [timeout, passphrase]).then (function(response) {
    return response.result;
  });
};

// Change the password of the current wallet
// parameters: 
  //   passphrase `passphrase` - the passphrase for encrypting the wallet
// return_type: `void`
WalletAPI.prototype.change_passphrase = function(passphrase) {
  return this.rpc.request('wallet_change_passphrase', [passphrase]).then (function(response) {
    return response.result;
  });
};

// Return a list of wallets in the current data directory
// parameters: 
// return_type: `wallet_name_array`
WalletAPI.prototype.list = function() {
  return this.rpc.request('wallet_list', []).then (function(response) {
    return response.result;
  });
};

// Add new account for receiving payments
// parameters: 
  //   account_name `account_name` - the name you will use to refer to this receive account
  //   json_variant `private_data` - Extra data to store with this account record
// return_type: `public_key`
WalletAPI.prototype.account_create = function(account_name, private_data) {
  return this.rpc.request('wallet_account_create', [account_name, private_data]).then (function(response) {
    return response.result;
  });
};

// Updates the favorited status of the specified account
// parameters: 
  //   account_name `account_name` - the name of the account to set favorited status on
  //   bool `is_favorite` - true if account should be marked as a favorite; false otherwise
// return_type: `void`
WalletAPI.prototype.account_set_favorite = function(account_name, is_favorite) {
  return this.rpc.request('wallet_account_set_favorite', [account_name, is_favorite]).then (function(response) {
    return response.result;
  });
};

// Updates your approval of the specified account
// parameters: 
  //   account_name `account_name` - the name of the account to set approval for
  //   int8_t `approval` - 1, 0, or -1 respectively for approve, neutral, or disapprove
// return_type: `int8_t`
WalletAPI.prototype.account_set_approval = function(account_name, approval) {
  return this.rpc.request('wallet_account_set_approval', [account_name, approval]).then (function(response) {
    return response.result;
  });
};

// Add new account for sending payments
// parameters: 
  //   account_name `account_name` - the name you will use to refer to this sending account
  //   public_key `account_key` - the key associated with this sending account
// return_type: `void`
WalletAPI.prototype.add_contact_account = function(account_name, account_key) {
  return this.rpc.request('wallet_add_contact_account', [account_name, account_key]).then (function(response) {
    return response.result;
  });
};

// Sends given amount to the given account, with the from field set to the payer.  This transfer will occur in a single transaction and will be cheaper, but may reduce your privacy.
// parameters: 
  //   real_amount `amount_to_transfer` - the amount of shares to transfer
  //   asset_symbol `asset_symbol` - the asset to transfer
  //   sending_account_name `from_account_name` - the source account to draw the shares from
  //   receive_account_name `to_account_name` - the account to transfer the shares to
  //   string `memo_message` - a memo to store with the transaction
  //   vote_selection_method `vote_method` - enumeration [vote_none | vote_all | vote_random | vote_recommended] 
// return_type: `transaction_record`
WalletAPI.prototype.transfer = function(amount_to_transfer, asset_symbol, from_account_name, to_account_name, memo_message, vote_method) {
  return this.rpc.request('wallet_transfer', [amount_to_transfer, asset_symbol, from_account_name, to_account_name, memo_message, vote_method]).then (function(response) {
    return response.result;
  });
};

// Sends given amount to the given name, with the from field set to a different account than the payer.  This transfer will occur in a single transaction and will be cheaper, but may reduce your privacy.
// parameters: 
  //   real_amount `amount_to_transfer` - the amount of shares to transfer
  //   asset_symbol `asset_symbol` - the asset to transfer
  //   sending_account_name `paying_account_name` - the source account to draw the shares from
  //   sending_account_name `from_account_name` - the account to show the recipient as being the sender (requires account's private key to be in wallet). Leave empty to send anonymously.
  //   receive_account_name `to_account_name` - the account to transfer the shares to
  //   string `memo_message` - a memo to store with the transaction
  //   vote_selection_method `vote_method` - enumeration [vote_none | vote_all | vote_random | vote_recommended] 
// return_type: `transaction_record`
WalletAPI.prototype.transfer_from = function(amount_to_transfer, asset_symbol, paying_account_name, from_account_name, to_account_name, memo_message, vote_method) {
  return this.rpc.request('wallet_transfer_from', [amount_to_transfer, asset_symbol, paying_account_name, from_account_name, to_account_name, memo_message, vote_method]).then (function(response) {
    return response.result;
  });
};

// Scans the blockchain history for operations relevant to this wallet.
// parameters: 
  //   uint32_t `first_block_number` - the first block to scan
  //   uint32_t `num_blocks` - the number of blocks to scan
// return_type: `void`
WalletAPI.prototype.rescan_blockchain = function(first_block_number, num_blocks) {
  return this.rpc.request('wallet_rescan_blockchain', [first_block_number, num_blocks]).then (function(response) {
    return response.result;
  });
};

// Scans the specified transaction
// parameters: 
  //   uint32_t `block_num` - the block containing the transaction
  //   string `transaction_id` - the id (or id prefix) of the transaction
// return_type: `void`
WalletAPI.prototype.transaction_scan = function(block_num, transaction_id) {
  return this.rpc.request('wallet_transaction_scan', [block_num, transaction_id]).then (function(response) {
    return response.result;
  });
};

// Rebroadcasts the specified transaction
// parameters: 
  //   string `transaction_id` - the id (or id prefix) of the transaction
// return_type: `void`
WalletAPI.prototype.transaction_rebroadcast = function(transaction_id) {
  return this.rpc.request('wallet_transaction_rebroadcast', [transaction_id]).then (function(response) {
    return response.result;
  });
};

// Updates the data published about a given account
// parameters: 
  //   account_name `account_name` - the account that will be updated
  //   account_name `pay_from_account` - the account from which fees will be paid
  //   json_variant `public_data` - public data about the account
  //   uint32_t `delegate_pay_rate` - A value between 0 and 100 for delegates, 255 for non delegates
// return_type: `signed_transaction`
WalletAPI.prototype.account_register = function(account_name, pay_from_account, public_data, delegate_pay_rate) {
  return this.rpc.request('wallet_account_register', [account_name, pay_from_account, public_data, delegate_pay_rate]).then (function(response) {
    return response.result;
  });
};

// Updates the local private data for an account
// parameters: 
  //   account_name `account_name` - the account that will be updated
  //   json_variant `private_data` - private data about the account
// return_type: `void`
WalletAPI.prototype.account_update_private_data = function(account_name, private_data) {
  return this.rpc.request('wallet_account_update_private_data', [account_name, private_data]).then (function(response) {
    return response.result;
  });
};

// Updates the data published about a given account
// parameters: 
  //   account_name `account_name` - the account that will be updated
  //   account_name `pay_from_account` - the account from which fees will be paid
  //   json_variant `public_data` - public data about the account
  //   uint8_t `delegate_pay_rate` - delegate pay rate: 0 to 100 if updating or upgrading to a delegate, and 255 for a normal account
// return_type: `signed_transaction`
WalletAPI.prototype.account_update_registration = function(account_name, pay_from_account, public_data, delegate_pay_rate) {
  return this.rpc.request('wallet_account_update_registration', [account_name, pay_from_account, public_data, delegate_pay_rate]).then (function(response) {
    return response.result;
  });
};

// Updates the specified account's active key and broadcasts the transaction.
// parameters: 
  //   account_name `account_to_update` - The name of the account to update the active key of.
  //   account_name `pay_from_account` - The account from which fees will be paid.
  //   string `new_active_key` - WIF private key to update active key to. If empty, a new key will be generated.
// return_type: `signed_transaction`
WalletAPI.prototype.account_update_active_key = function(account_to_update, pay_from_account, new_active_key) {
  return this.rpc.request('wallet_account_update_active_key', [account_to_update, pay_from_account, new_active_key]).then (function(response) {
    return response.result;
  });
};

// Lists all accounts associated with this wallet
// parameters: 
// return_type: `wallet_account_record_array`
WalletAPI.prototype.list_accounts = function() {
  return this.rpc.request('wallet_list_accounts', []).then (function(response) {
    return response.result;
  });
};

// Lists all accounts which have been marked as favorites.
// parameters: 
// return_type: `wallet_account_record_array`
WalletAPI.prototype.list_favorite_accounts = function() {
  return this.rpc.request('wallet_list_favorite_accounts', []).then (function(response) {
    return response.result;
  });
};

// Lists all unregistered accounts belonging to this wallet
// parameters: 
// return_type: `wallet_account_record_array`
WalletAPI.prototype.list_unregistered_accounts = function() {
  return this.rpc.request('wallet_list_unregistered_accounts', []).then (function(response) {
    return response.result;
  });
};

// Lists all accounts for which we have a private key in this wallet
// parameters: 
// return_type: `wallet_account_record_array`
WalletAPI.prototype.list_my_accounts = function() {
  return this.rpc.request('wallet_list_my_accounts', []).then (function(response) {
    return response.result;
  });
};

// Get the account record for a given name
// parameters: 
  //   account_name `account_name` - the name of the account to retrieve
// return_type: `wallet_account_record`
WalletAPI.prototype.get_account = function(account_name) {
  return this.rpc.request('wallet_get_account', [account_name]).then (function(response) {
    return response.result;
  });
};

// Remove a contact account from your wallet
// parameters: 
  //   account_name `account_name` - the name of the contact
// return_type: `void`
WalletAPI.prototype.remove_contact_account = function(account_name) {
  return this.rpc.request('wallet_remove_contact_account', [account_name]).then (function(response) {
    return response.result;
  });
};

// Rename an account in wallet
// parameters: 
  //   account_name `current_account_name` - the current name of the account
  //   new_account_name `new_account_name` - the new name for the account
// return_type: `void`
WalletAPI.prototype.account_rename = function(current_account_name, new_account_name) {
  return this.rpc.request('wallet_account_rename', [current_account_name, new_account_name]).then (function(response) {
    return response.result;
  });
};

// Creates a new user issued asset
// parameters: 
  //   asset_symbol `symbol` - the ticker symbol for the new asset
  //   string `asset_name` - the name of the asset
  //   string `issuer_name` - the name of the issuer of the asset
  //   string `description` - a description of the asset
  //   json_variant `data` - arbitrary data attached to the asset
  //   real_amount `maximum_share_supply` - the maximum number of shares of the asset
  //   int64_t `precision` - defines where the decimal should be displayed, must be a power of 10
  //   bool `is_market_issued` - creation of a new BitAsset that is created by shorting
// return_type: `signed_transaction`
WalletAPI.prototype.asset_create = function(symbol, asset_name, issuer_name, description, data, maximum_share_supply, precision, is_market_issued) {
  return this.rpc.request('wallet_asset_create', [symbol, asset_name, issuer_name, description, data, maximum_share_supply, precision, is_market_issued]).then (function(response) {
    return response.result;
  });
};

// Issues new shares of a given asset type
// parameters: 
  //   real_amount `amount` - the amount of shares to issue
  //   asset_symbol `symbol` - the ticker symbol for asset
  //   account_name `to_account_name` - the name of the account to receive the shares
  //   string `memo_message` - the memo to send to the receiver
// return_type: `signed_transaction`
WalletAPI.prototype.asset_issue = function(amount, symbol, to_account_name, memo_message) {
  return this.rpc.request('wallet_asset_issue', [amount, symbol, to_account_name, memo_message]).then (function(response) {
    return response.result;
  });
};

// Lists the total asset balances for the specified account
// parameters: 
  //   account_name `account_name` - the account to get a balance for, or leave empty for all accounts
// return_type: `account_balance_summary_type`
WalletAPI.prototype.account_balance = function(account_name) {
  return this.rpc.request('wallet_account_balance', [account_name]).then (function(response) {
    return response.result;
  });
};

// Lists all public keys in this account
// parameters: 
  //   account_name `account_name` - the account for which public keys should be listed
// return_type: `public_key_summary_array`
WalletAPI.prototype.account_list_public_keys = function(account_name) {
  return this.rpc.request('wallet_account_list_public_keys', [account_name]).then (function(response) {
    return response.result;
  });
};

// Used to transfer some of the delegate's pay from their balance
// parameters: 
  //   account_name `delegate_name` - the delegate whose pay is being cashed out
  //   account_name `to_account_name` - the account that should receive the funds
  //   real_amount `amount_to_withdraw` - the amount to withdraw
  //   string `memo` - memo to add to transaction
// return_type: `signed_transaction`
WalletAPI.prototype.delegate_withdraw_pay = function(delegate_name, to_account_name, amount_to_withdraw, memo) {
  return this.rpc.request('wallet_delegate_withdraw_pay', [delegate_name, to_account_name, amount_to_withdraw, memo]).then (function(response) {
    return response.result;
  });
};

// Set the fee to add to new transactions
// parameters: 
  //   real_amount `fee` - the wallet transaction fee to set
// return_type: `asset`
WalletAPI.prototype.set_transaction_fee = function(fee) {
  return this.rpc.request('wallet_set_transaction_fee', [fee]).then (function(response) {
    return response.result;
  });
};

// Used to place a request to buy a quantity of assets at a price specified in another asset
// parameters: 
  //   account_name `from_account_name` - the account that will provide funds for the bid
  //   real_amount `quantity` - the quantity of items you would like to buy
  //   asset_symbol `quantity_symbol` - the type of items you would like to buy
  //   real_amount `base_price` - the price you would like to pay
  //   asset_symbol `base_symbol` - the type of asset you would like to pay with
  //   bool `allow_stupid_bid` - Allow user to place bid at more than 5% above the current sell price.
// return_type: `signed_transaction`
WalletAPI.prototype.market_submit_bid = function(from_account_name, quantity, quantity_symbol, base_price, base_symbol, allow_stupid_bid) {
  return this.rpc.request('wallet_market_submit_bid', [from_account_name, quantity, quantity_symbol, base_price, base_symbol, allow_stupid_bid]).then (function(response) {
    return response.result;
  });
};

// Used to place a request to sell a quantity of assets at a price specified in another asset
// parameters: 
  //   account_name `from_account_name` - the account that will provide funds for the ask
  //   real_amount `sell_quantity` - the quantity of items you would like to sell
  //   asset_symbol `sell_quantity_symbol` - the type of items you would like to sell
  //   real_amount `ask_price` - the price per unit sold.
  //   asset_symbol `ask_price_symbol` - the type of asset you would like to be paid
  //   bool `allow_stupid_ask` - Allow user to place ask at more than 5% below the current buy price.
// return_type: `signed_transaction`
WalletAPI.prototype.market_submit_ask = function(from_account_name, sell_quantity, sell_quantity_symbol, ask_price, ask_price_symbol, allow_stupid_ask) {
  return this.rpc.request('wallet_market_submit_ask', [from_account_name, sell_quantity, sell_quantity_symbol, ask_price, ask_price_symbol, allow_stupid_ask]).then (function(response) {
    return response.result;
  });
};

// Used to place a request to short sell a quantity of assets at a price specified
// parameters: 
  //   account_name `from_account_name` - the account that will provide funds for the ask
  //   real_amount `short_quantity` - the quantity of items you would like to short sell (borrow into existance and sell)
  //   real_amount `short_price` - the price (ie: 2.0 USD) per XTS that you would like to short at
  //   asset_symbol `short_symbol` - the type of asset you would like to short, ie: USD
  //   bool `allow_stupid_short` - Allow user to place short at more than 5% above the current sell price.
// return_type: `signed_transaction`
WalletAPI.prototype.market_submit_short = function(from_account_name, short_quantity, short_price, short_symbol, allow_stupid_short) {
  return this.rpc.request('wallet_market_submit_short', [from_account_name, short_quantity, short_price, short_symbol, allow_stupid_short]).then (function(response) {
    return response.result;
  });
};

// Used to place a request to cover an existing short position
// parameters: 
  //   account_name `from_account_name` - the account that will provide funds for the ask
  //   real_amount `quantity` - the quantity of items you would like to cover
  //   asset_symbol `quantity_symbol` - the type of asset you are covering (ie: USD)
  //   address `order_id` - the order ID you would like to cover
// return_type: `signed_transaction`
WalletAPI.prototype.market_cover = function(from_account_name, quantity, quantity_symbol, order_id) {
  return this.rpc.request('wallet_market_cover', [from_account_name, quantity, quantity_symbol, order_id]).then (function(response) {
    return response.result;
  });
};

// List an order list of a specific market
// parameters: 
  //   asset_symbol `base_symbol` - the base symbol of the market
  //   asset_symbol `quote_symbol` - the quote symbol of the market
  //   int64_t `limit` - the maximum number of items to return
  //   account_name `account_name` - the account for which to get the orders, or 'ALL' to get them all
// return_type: `market_order_array`
WalletAPI.prototype.market_order_list = function(base_symbol, quote_symbol, limit, account_name) {
  return this.rpc.request('wallet_market_order_list', [base_symbol, quote_symbol, limit, account_name]).then (function(response) {
    return response.result;
  });
};

// Cancel an order
// parameters: 
  //   address `order_id` - the address of the order to cancel
// return_type: `signed_transaction`
WalletAPI.prototype.market_cancel_order = function(order_id) {
  return this.rpc.request('wallet_market_cancel_order', [order_id]).then (function(response) {
    return response.result;
  });
};

// Reveals the private key corresponding to an account, public key, or address
// parameters: 
  //   string `input` - an account name, public key, or address (quoted hash of public key)
// return_type: `string`
WalletAPI.prototype.dump_private_key = function(input) {
  return this.rpc.request('wallet_dump_private_key', [input]).then (function(response) {
    return response.result;
  });
};

// Returns the allocation of votes by this account
// parameters: 
  //   account_name `account_name` - the account to report votes on, or empty for all accounts
// return_type: `account_vote_summary`
WalletAPI.prototype.account_vote_summary = function(account_name) {
  return this.rpc.request('wallet_account_vote_summary', [account_name]).then (function(response) {
    return response.result;
  });
};

// Set a property in the GUI settings DB
// parameters: 
  //   string `name` - the name of the setting to set
  //   variant `value` - the value to set the setting to
// return_type: `void`
WalletAPI.prototype.set_setting = function(name, value) {
  return this.rpc.request('wallet_set_setting', [name, value]).then (function(response) {
    return response.result;
  });
};

// Get the value of the given setting
// parameters: 
  //   string `name` - The name of the setting to fetch
// return_type: `optional_variant`
WalletAPI.prototype.get_setting = function(name) {
  return this.rpc.request('wallet_get_setting', [name]).then (function(response) {
    return response.result;
  });
};

// Enable or disable block production for a particular delegate account
// parameters: 
  //   string `delegate_name` - The delegate to enable/disable block production for; ALL for all delegate accounts
  //   bool `enabled` - true to enable block production, false otherwise
// return_type: `void`
WalletAPI.prototype.delegate_set_block_production = function(delegate_name, enabled) {
  return this.rpc.request('wallet_delegate_set_block_production', [delegate_name, enabled]).then (function(response) {
    return response.result;
  });
};

// Enable or disable wallet transaction scanning
// parameters: 
  //   bool `enabled` - true to enable transaction scanning, false otherwise
// return_type: `bool`
WalletAPI.prototype.set_transaction_scanning = function(enabled) {
  return this.rpc.request('wallet_set_transaction_scanning', [enabled]).then (function(response) {
    return response.result;
  });
};

// Signs the provided message digest with the account key
// parameters: 
  //   string `signing_account` - Name of the account to sign the message with
  //   sha256 `hash` - SHA256 digest of the message to sign
// return_type: `compact_signature`
WalletAPI.prototype.sign_hash = function(signing_account, hash) {
  return this.rpc.request('wallet_sign_hash', [signing_account, hash]).then (function(response) {
    return response.result;
  });
};

// Initiates the login procedure by providing a BitShares Login URL
// parameters: 
  //   string `server_account` - Name of the account of the server. The user will be shown this name as the site he is logging into.
// return_type: `string`
WalletAPI.prototype.login_start = function(server_account) {
  return this.rpc.request('wallet_login_start', [server_account]).then (function(response) {
    return response.result;
  });
};

// Completes the login procedure by finding the user's public account key and shared secret
// parameters: 
  //   public_key `server_key` - The one-time public key from wallet_login_start.
  //   public_key `client_key` - The client's one-time public key.
  //   compact_signature `client_signature` - The client's signature of the shared secret.
// return_type: `variant`
WalletAPI.prototype.login_finish = function(server_key, client_key, client_signature) {
  return this.rpc.request('wallet_login_finish', [server_key, client_key, client_signature]).then (function(response) {
    return response.result;
  });
};

// Publishes the current wallet delegate slate to the public data associated with the account
// parameters: 
  //   account_name `publishing_account_name` - The account to publish the slate ID under
  //   account_name `paying_account_name` - The account to pay transaction fees; leave empty to pay with publishing account.
// return_type: `signed_transaction`
WalletAPI.prototype.publish_slate = function(publishing_account_name, paying_account_name) {
  return this.rpc.request('wallet_publish_slate', [publishing_account_name, paying_account_name]).then (function(response) {
    return response.result;
  });
};

// Attempts to recover accounts created after last backup was taken and returns number of successful recoveries. Use if you have restored from backup and are missing accounts.
// parameters: 
  //   int32_t `accounts_to_recover` - The number of accounts to attept to recover
  //   int32_t `maximum_number_of_attempts` - The maximum number of keys to generate trying to recover accounts
// return_type: `int32_t`
WalletAPI.prototype.recover_accounts = function(accounts_to_recover, maximum_number_of_attempts) {
  return this.rpc.request('wallet_recover_accounts', [accounts_to_recover, maximum_number_of_attempts]).then (function(response) {
    return response.result;
  });
};

// publishes a price feed for BitAssets, only active delegates may do this
// parameters: 
  //   account_name `delegate_account` - the delegate to publish the price under
  //   real_amount `price` - the number of this asset per XTS
  //   asset_symbol `asset_symbol` - the type of asset being priced
// return_type: `signed_transaction`
WalletAPI.prototype.publish_price_feed = function(delegate_account, price, asset_symbol) {
  return this.rpc.request('wallet_publish_price_feed', [delegate_account, price, asset_symbol]).then (function(response) {
    return response.result;
  });
};



