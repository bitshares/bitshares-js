console.log(__dirname)
var assert = require('assert')
//var Address = require('..').Address

var Bitcoin = require("bitcoinjs-lib");

var Bitshares = require('../src/index');
var BtsKey = Bitshares.BtsKey;

// ./node_modules/.bin/istanbul test ./node_modules/.bin/_mocha -- --reporter
// list -w test/BtsKey_test.js

var crypto = require('crypto')
var convert = require('bitcoinjs-lib/src/convert')

describe('BTS', function() {

    it('creates a private key', function() {
        var btsKey = new BtsKey.makeRandom();
        console.log("priv=" + btsKey.toWIF());
    });

    // it(
    // 'given private key, computes public key',
    // function() {
    // var priv =
    // '62f6142a21dc171a105c1845f5dc1457b02c7f5c0c956459f1e7afd09fe0d220';
    // // var key=PrivKey.fromHex(priv);
    // var key = new Bitcoin.ECKey();
    // key.import(priv, true);
    // var pub = new Buffer(key.getPub().toBytes());// key.pub.toBuffer();
    // var pubSha = new Buffer(crypto.createHash('sha512')
    // .update(pub).digest());
    // var addy = new Buffer(crypto.createHash('ripemd160')
    // .update(pubSha).digest());
    // var checksum = new Buffer(crypto
    // .createHash('ripemd160').update(addy).digest());
    // addy = Buffer.concat([ addy, checksum.slice(0, 4) ]);
    // assert.equal(base58.encode(addy),
    // "KXhLdYWRy2cdo9L8362AD7vLHhTjN8Rbg");
    // });
});

// describe(
// 'PTS',
// function() {
// it(
// 'given private key, computes public key',
// function() {
// var priv =
// '62f6142a21dc171a105c1845f5dc1457b02c7f5c0c956459f1e7afd09fe0d220';
//
// // var key=PrivKey.fromHex(priv, false);//not compressed
// var key = new Bitcoin.ECKey.fromWIF(priv);
// assert
// .equal(
// key.getPub().toHex(),
// "04f8574d8affe9f335dbe6a7cac28167a0fc01c75652615ee2d8eb27dafeda4c8b9b825c6d5997a9dbc0e831fdd791cfee3379efcb89a3caf03a407e80721d1f34");
// // console.log("\npub hex\t" + key.pub.toHex());
// // var pub=key.pub.toBuffer();
// var pub = new Buffer(key.getPub().toBytes());
// var pubSha256 = new Buffer(crypto.createHash('sha256')
// .update(pub).digest());
// // console.log("SHA256\t"+pubSha256.toString("hex"));
// assert
// .equal(pubSha256.toString("hex"),
// "168032925ab94c96deb940989373108735ab1b4323a5d7f02d399aa223b9f51d");
//
// var addy = new Buffer(crypto.createHash('ripemd160')
// .update(pubSha256).digest());
// // console.log("ripe\t"+addy.toString("hex"));
// assert.equal(addy.toString("hex"),
// "aec8f8554c31664c7ecaf09d0455106b9fa7ea49");
//
// addy = Buffer.concat([ new Buffer([ 0x38 ]), addy ]);// version
// // 56(decimal)
// // console.log("+ver\t"+addy.toString("hex"));
// assert.equal(addy.toString("hex"),
// "38aec8f8554c31664c7ecaf09d0455106b9fa7ea49");
//
// var check = new Buffer(crypto.createHash('sha256')
// .update(addy).digest());
// // double hash
// check = new Buffer(crypto.createHash('sha256').update(
// check).digest());
//
// addy = Buffer.concat([ addy, check.slice(0, 4) ]);
// assert.equal(base58.encode(addy),
// "PorxU6zjX8VUrH2T8afdZmzgvxqdi4ScLY");
//
// });
// });

/*
 * - std::cout << "bts address: " + std::cout << "public key:\t" + <<
 * fc::variant( key.get_public_key() ).as_string() <<"\n"
 */
