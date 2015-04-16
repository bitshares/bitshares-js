module.exports =
    bts_address_prefix: "XTS"
    
    ###*
    # This is a hash of the genesis block (genesis.json for example).  It must
    # match for transactions to be accepted.
    #
    # The bitshares_client will store this value.  Here is how you might find it:
    # >>> blockchain_dump_state /tmp/blockchain
    # less /tmp/blockchain/_property_db.json
    # [[4, ...]]
    ###
    chain_id: "74cef39d88afd6123d40c5822632b753e5b25da6ca196218c2364560bbf3171f"
    
    BTS_BLOCKCHAIN_BLOCK_INTERVAL_SEC: 10
    BTS_WALLET_DEFAULT_TRANSACTION_EXPIRATION_SEC: 60 * 60
    #BTS_BLOCKCHAIN_MAX_SHORT_PERIOD_SEC: 30*24*60*60 # 1 month (prodnet)
    BTS_BLOCKCHAIN_MAX_SHORT_PERIOD_SEC: 2*60*60 # 2 hours (testnet)
    BTS_BLOCKCHAIN_MAX_SHARES: Math.pow 10, 15
    