console.log "-------------------"
JSON_PORT=process.argv[2] or 45000
console.log "(param 1) JSON_PORT=",JSON_PORT

#Ecc = require '../src/ecc'
#Aes = Ecc.Aes
#Signature = Ecc.Signature
#PrivateKey = Ecc.PrivateKey
#PublicKey = Ecc.PublicKey

_Mail = require '../src/mail'
Mail = _Mail.Mail
Email = _Mail.Email
EncryptedMail = _Mail.EncryptedMail

{Rpc} = require "./rpc_json"
{Common} = require "./rpc_common"

@rpc=new Rpc(on, JSON_PORT, "localhost", "test", "test")
@common=new Common(@rpc)

class TestNet

    WEB_ROOT=process.env.WEB_ROOT
    console.log "(param 1) WEB_ROOT=",WEB_ROOT

    WALLET_JSON="#{WEB_ROOT}/test/testnet/config/wallet.json"

    constructor: (@rpc, @common) ->

    unlock: ->
        @rpc.run """
            open default
            unlock 9999 Password00
        """

    mkdefault: ->
        @rpc.run """
            wallet_backup_restore #{WALLET_JSON} default Password00
        """

        
###
   check: ->
       @rpc.run("mail_get_processing_messages").then (response) ->
           for x in response
               if x[1] == @message_id
                   console.log "check (status) ", x[0]

###

class MailTest
    
    constructor: (@rpc, @common) ->
    
    send: ->
        @rpc.run("mail_send", ["delegate0", "delegate1", "Subject", 
        """
        Body
        end of transmission
        """]).then (response) ->
            @message_id = response
            console.log "Submitted Message ID",message_id

    inbox: ->
        @rpc.run "mail_inbox"

    processing: =>
        @rpc.run("mail_get_processing_messages").then (response) ->
            for x in response
                console.log "processing_message", x

    processing_cancel_all: ->
        #https://github.com/BitShares/bitshares_toolkit/commit/57d04e8fb2b0dda15623e83a6855f77b2dc1cbd6
        @rpc.run("mail_get_processing_messages").then (response) ->
            for x in response
                console.log("mail_cancel_message #{x[1]}")
                @rpc.run("mail_cancel_message #{x[1]}")

    publish_mail_server: ->
        #TODO, merge public_data
        # blockchain_get_account delegate1
        public_data =
            mail_servers: ["delegate1"]
            mail_server_endpoint: "127.0.0.1:#{JSON_PORT}"

        @rpc.run("wallet_account_update_registration", ["delegate1", "delegate1", public_data, "44"]).then () ->
            @rpc.run "blockchain_list_pending_transactions"

    mail_store_message: ->
        now = new Date()
        isoDate = now.toISOString()
        # until v0.4.24 https://github.com/BitShares/bitshares_toolkit/issues/857
        isoDate = isoDate.replace /[-:]/g, ''
        isoDate = isoDate.split('.')[0]
        console.log isoDate
        encrypted_mail_test =
            type: "encrypted"
            recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
            nonce: 474
            timestamp: isoDate
            data: "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2a001636588df76269f78eda0d98453a5e16266317ed78ae9bb013898b4cbf52ddf54959aaf2a4b0ffa4ac4dcd52edcfe179c0127bd8b02e90ba60697a34ac2a40ed6a5adf997d5f49952a9c274f018f8d9331228749a9bd899b7bcf3f52bbb7a4c1ada1e062885767fc11ceb70f72751ce86a484096a1d2e32d7cafd23469d207da2ec535b9c971b9923ca2a7db902f627a47f654435a1ccf7d822293386d69d5f50"

        enc = EncryptedMail.fromHex encrypted_mail_test.data
        @rpc.run "mail_store_message", [encrypted_mail_test]

    decrypt: ->
        
###
open default
unlock 9999 Password00
mail_send delegate0 delegate1 subject body

mail_get_processing_messages

wallet_set_preferred_mail_servers "delegate1"  ["delegate1"] "delegate1"
blockchain_get_account delegate1

mail_fetch_message ... #encrypted
mail_get_message ...  #unencrypted
mail_retry_send "b784d94a16fdca48fcd90eeaad08cd861fac259f"

###
Test = =>

    tn=new TestNet(@rpc, @common)
    tn.unlock()

    ## Edit tmp/client000/config.json  -> "mail_server_enabled": true

    m=new MailTest(@rpc, @common)
    #m.send()
    #m.publish_mail_server()
    m.mail_store_message()
    #m.processing_cancel_all()

    @rpc.run "mail_check_new_messages"
    #m.clear()
    m.processing()
    m.inbox()

Test()

@rpc.close()

