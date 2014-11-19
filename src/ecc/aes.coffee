# https://code.google.com/p/crypto-js
class Aes

    CryptoJS = require("crypto-js")
    assert = require("assert")
    hash = require("./hash")

    constructor: (@iv, @key) ->

    Aes.fromSha512 = (hash) ->
        assert.equal hash.length, 128, "A Sha512 in HEX should be 128 characters long, instead got #{hash.length}"
        #https://github.com/InvictusInnovations/fc/blob/978de7885a8065bc84b07bfb65b642204e894f55/src/crypto/aes.cpp#L330
        #Bitshares aes_decrypt uses part of the password hash as the initilization vector
        iv = CryptoJS.enc.Hex.parse(hash.substring(64, 96))
        key = CryptoJS.enc.Hex.parse(hash.substring(0, 64))
        new Aes(iv, key)

    Aes.fromSecret = (password) ->
        assert password, "password is required"
        _hash = hash.sha512 password
        _hash = _hash.toString('hex')
        Aes.fromSha512(_hash)
        
    Aes.fromSharedSecret_ecies = (S) ->
        assert S, "Shared secret is required"
        Aes.fromSha512 hash.sha512(S).toString('hex')
        

    _decrypt_word_array: (cipher) ->
        # https://code.google.com/p/crypto-js/#Custom_Key_and_IV
        # see wallet_records.cpp master_key::decrypt_key
        CryptoJS.AES.decrypt(
          ciphertext: cipher
          salt: null
        , @key,
          iv: @iv
        )
    
    _encrypt_word_array: (plaintext) ->
        #https://code.google.com/p/crypto-js/issues/detail?id=85
        cipher = CryptoJS.AES.encrypt plaintext, @key, {iv: @iv}
        CryptoJS.enc.Base64.parse cipher.toString()

    decrypt: (cipher_buffer) ->
        assert cipher_buffer, "Missing cipher text"
        # hex is the only common format
        hex = @decryptHex(cipher_buffer.toString('hex'))
        new Buffer(hex, 'hex')
        
    encrypt: (plaintext_buffer) ->
        #assert plaintext_buffer, "Missing plain text"
        # hex is the only common format
        hex = @encryptHex(plaintext_buffer.toString('hex'))
        new Buffer(hex, 'hex')

    ### <helper_functions> ###
    
    decryptHex: (cipher) ->
        assert cipher, "Missing cipher text"
        # Convert data into word arrays (used by Crypto)
        cipher_array = CryptoJS.enc.Hex.parse cipher
        plainwords = @_decrypt_word_array cipher_array
        CryptoJS.enc.Hex.stringify plainwords
        
    encryptHex: (plainhex) ->
        #assert plainhex, "Missing plain text"
        plain_array = CryptoJS.enc.Hex.parse plainhex
        cipher_array = @_encrypt_word_array plain_array
        CryptoJS.enc.Hex.stringify cipher_array
        
    ### </helper_functions> ###

exports.Aes = Aes

