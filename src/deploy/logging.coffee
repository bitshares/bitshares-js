module.exports=
    rpc_hide: #{}
        ## {} means hide nothing
        hide_all:on
        get_info: on
        get_config: on
        wallet_create: on #don't log password and brainkey
        wallet_unlock: on #don't log password
        wallet_get_info: on
        #wallet_list_accounts: on
        wallet_account_yield: on
        #wallet_account_balance: on
        ##wallet_account_transaction_history: on
        ##blockchain_get_info: on
        ##blockchain_get_security_state:on
        blockchain_get_security_state:on
        ##blockchain_list_address_transactions: on
        ##blockchain_list_key_balances: on
        ##blockchain_get_account: on
        ####