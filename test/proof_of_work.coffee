
{Mail} = require '../src/mail/mail'
{Email} = require '../src/mail/email'
{PublicKey} = require '../src/ecc/key_public'
mail_types = require '../src/mail/type'

pow_length = "000ffffffdeadbeeffffffffffffffffffffffff".length # 40
target = 3 # leading zeros

alice_bts_public = "XTS7hjSkcEpa697i9kW2Ltu8f7X19nzp41VTWvKMRgCYKkpQfekes"

describe "Proof-of-Work", ->

    it "Find passing hash", () ->
        BigInteger = require 'bigi'
        type_id = mail_types['email']
        alice = PublicKey.fromBtsPublic alice_bts_public
        recipient = alice.toBlockchainAddress()
        nonce = 0
        time = new Date()
        data = new Email("Subject", "Body").toBuffer(include_signature = false)
        mail = new Mail(type_id, recipient, nonce, time, data)
        id = BigInteger.fromBuffer mail.id()
        #@.timeout(10 * 1000) if @.timeout #mocha only
        # until id starts with at least 3 hex zeros
        until id.shiftRight((pow_length - target)*4).equals BigInteger.ZERO
            ++mail.nonce
            id = BigInteger.fromBuffer mail.id()
        #console.log '\tnonce',mail.nonce,'id',id.toHex(),id.toHex().length