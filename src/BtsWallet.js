'use strict'

module.exports = {
    BtsWallet : BtsWallet
}

var RPC = require('./rpc').RPC;
var API = require('./wallet_api').WalletAPI;

/**
 * @class
 * @param {string}
 *            options.rpc.[url|user|password] - See Rpc module for usage
 * @example var BtsWallet = new Bitshares.BtsWallet({ 'rpc' : { 'url' :
 *          'http://localhost:5680/rpc', 'user' : 'user', 'password' :
 *          'password' } });
 * 
 */
function BtsWallet(options) {
    if (!options)
        options = {};

    this.rpc = new RPC(options.rpc);
    this.api = new API(this.rpc);
}

