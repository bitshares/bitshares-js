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
    