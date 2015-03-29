module.exports =
    bts_address_prefix: "BTS"
    
    ###*
    # This is a hash of the genesis block (genesis.json for example).  It must
    # match for transactions to be accepted.
    #
    # The bitshares_client will store this value.  Here is how you might find it:
    # >>> blockchain_dump_state /tmp/blockchain
    # less /tmp/blockchain/_property_db.json
    # [[4, ...]]
    ###
    chain_id: "75c11a81b7670bbaa721cc603eadb2313756f94a3bcbb9928e9101432701ac5f"
    
