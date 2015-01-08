


class MailClient
    ###
    send_encrypted_message:(
        ciphertext, from, to
        recipient_key
    )->
        if ciphertext.type isnt 0 # encrypted
            throw new Error "must be encrypted message type"
        ciphertext.recipient = recipient_key
        mail_rec = new Mail(from, to, recipient_key, ciphertext)
        @process_outgoing_mail mail_rec
        return mail_rec.id
    ###
exports.MailClient = MailClient