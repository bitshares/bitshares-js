$q = require 'q'

{Wallet} = require '../wallet/wallet'
{WalletDb} = require '../wallet/wallet_db'

class WalletAPI
    
    constructor: (@rpc = null) ->
        
    open:(wallet_name = "default",resolve,reject)-> #)-> $q
        @wallet_db = WalletDb.open wallet_name
        unless @wallet_db
            reject { key:'wallet.not_found', v1:wallet_name}
        else
            resolve @wallet_db
        return
        

    ###* 
        @return {promise}
        
        Save a new wallet and resovles with a WalletDb object.  Resolves as an error 
        if wallet exists or is unable to save in local storage.
    ###
    backup_restore_object:(wallet_object, wallet_name,resolve,reject)-> #)-> $q (resolve,reject)->
        if WalletDb.open wallet_name
            reject { key:'wallet.already_exists', v1: wallet_name }
        else
            try
                wallet_db = new WalletDb wallet_object, wallet_name
                wallet_db.save()
                resolve wallet_db
            catch error
                reject { key:'wallet.save_error', v1: wallet_name, v2: error }
        return

    
    # work-around
    # http://stackoverflow.com/questions/27490089/creating-own-angularjs-q-promise
    ###
    _$q: (resolve,reject) ->
        _this=@
        then: (result, error)->
            _this.result = result
            _this.error = error
            done: ->
        reject: (obj)->
            reject obj
            return
        resolve: (obj)->
            resolve obj
            return
    ###
exports.WalletAPI = WalletAPI