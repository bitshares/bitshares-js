# Keep the same structure as ./deploy_public_api.coffee but only include what is 
# required by a private API client such as github.com/bitshares/web_wallet.
module.exports =
    mail: 
        Email: require("../mail/email").Email
