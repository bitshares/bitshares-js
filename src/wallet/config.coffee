exports.config = 
    BTS_WALLET_VERSION: 109

    BTS_WALLET_MIN_PASSWORD_LENGTH: 8
    BTS_WALLET_MIN_BRAINKEY_LENGTH: 32
    
    BTS_WALLET_DEFAULT_UNLOCK_TIME_SEC: (60*60)
    
    BTS_WALLET_DEFAULT_TRANSACTION_EXPIRATION_SEC: 360
    
    DEFAULT_SETTING:
        transaction_fee: 50000 # .05
        interface_theme: "flowers"
        interface_locale: navigator?.language.split('-')[0]