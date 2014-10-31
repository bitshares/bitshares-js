Ecc = require("../src/ecc")
Aes = Ecc.Aes
PrivateKey = Ecc.PrivateKey
PublicKey = Ecc.PublicKey
assert = require("assert")

###*
@see https://code.google.com/p/crypto-js/#The_Cipher_Input
###
describe "Crypto", ->
    
    # wallet.json backup under 'encrypted_key'  
    encrypted_key = 
        "37fd6a251d262ec4c25343016a024a3aec543b7a43a208bf66bc80640dff" +
        "8ac8d52ae4ad7500d067c90f26189f9ee6050a13c087d430d24b88e713f1" + 
        "5d32cbd59e61b0e69c75da93f43aabb11039d06f"
    
    # echo -n Password01|sha512|xxd -p
    password_sha512 = 
        "a5d69dffbc219d0c0dd0be4a05505b219b973a04b4f2cd1979a5c9fd65bc0362" + #password (64 hex len)
        "2e4417ec767ffe269e5e53f769ffc6e1" + #initalization vector (32 hex len)
        "6bf05796fddf2771e4dc6d1cb2ac3fcf" #discard (32 hex len)
    
    decrypted_key = 
        "ab0cb9a14ecaa3078bfee11ca0420ea2" + 
        "3f5d49d7a7c97f7f45c3a520106491f8" + 
        "00000000000000000000000000000000000000000000000000000000" + 
        "00000000"
    
    it "Decrypts master key", ->
        aes = Aes.fromSecret "Password01"
        d = aes.decrypt_hex encrypted_key
        assert.equal decrypted_key, d, "decrypted key does not match"
    
    ###it "Computes public key", ->
        private_key = PrivateKey.fromHex decrypted_key.substring 0, 64
        public_key = private_key.toPublicKey()
        console.log public_key.toHex()###
