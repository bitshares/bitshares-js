main_config = require '../config'
CHAIN_SYMBOL = main_config.bts_address_prefix

module.exports = window?.localStorage ||
    # WARNING: NodeJs get and set are not atomic
    # https://github.com/lmaccherone/node-localstorage/issues/6
    new (
        require('node-localstorage').LocalStorage
    ) './localstorage-bitsharesjs-'+CHAIN_SYMBOL