'use strict'

module.exports = {
    BtsKey : BtsKey
}

var assert = require('assert')
var Bitcoin = require('bitcoinjs-lib')
var ECKey = Bitcoin.ECKey;
var base58check = require('./base58check')

//var ecurve = require('ecurve')
//var curve = ecurve.getCurveByName('secp256k1')

var KEY_VERSION = 0x80;// 128
var EC_VERSION = 0;
var COMPRESSED = false;
var BTS_ADDRESS_PREFIX = "XTS";

/**
 * Creates a new random key
 */
function BtsKey(ecKey) {
    assert(ecKey)
    this.ecKey = ecKey;
    this.pub = new BtsPubKey(ecKey.pub)
}

BtsKey.makeRandom = function(rng) {
    var ecKey = ECKey.makeRandom(COMPRESSED)
    return new BtsKey(ecKey);
}

// Export functions

/**
 * @returns string
 */
BtsKey.prototype.toWIF = function() {

    var ecPub = this.pub.pub;
    var bufferLen = ecPub.compressed ? 34 : 33
    var buffer = new Buffer(bufferLen)

    buffer.writeUInt8(0x80, 0)
    this.ecKey.d.toBuffer(32).copy(buffer, 1)

    if (ecPub.compressed) {
        buffer.writeUInt8(0x01, 33)
    }

    // BTS encoder uses a single SHA256 hash to make the checksum
    // Bitcoin uses double SHA256 hashes to make the checksum
    return base58check.encode(buffer)
}

// public key

function BtsPubKey(ecPubKey) {
    this.pub = ecPubKey

}
// Export functions
BtsPubKey.prototype.toBuffer = function() {
    return Buffer.concat([ BTS_ADDRESS_PREFIX, this.pub.toBuffer() ])
}

BtsPubKey.prototype.toHex = function() {
    return Buffer.concat([ new Buffer(BTS_ADDRESS_PREFIX),
            this.pub.toBuffer() ]).toString('hex')
}
