# BitShares-JS #

Pure JavaScript library for the BitShares platform. 

## Features ##

  Crypto
    ✓ Decrypts master key 

  Key Convert
    ✓ Create BTS short address
    ✓ Blockchain Address 
    ✓ BTS public key import / export 
    ✓ PTS 
    ✓ To WIF 
    ✓ From WIF 
    ✓ Calc public key
    ✓ Decrypt private key 

  Encrypted Mail
    ✓ Parse and generate 

  Mail
    ✓ Parse and generate 
    ✓ Matching one_time_key
    ✓ Decrypt using shared secret 
    ✓ Encrypt using shared secret 

  Email
    ✓ Parse and generate 
    ✓ Check each field 
    ✓ Verify
    ✓ Sign & Verify

  Transactions
    ✓ Decrypt 
    ✓ Parses transaction_notice_message 
    ✓ Regenerates transaction_notice_message 
    ✓ Verify transaction signatures
    ✓ Verify memo signature
    ✓ Extended owner key
    ✓ Extended one-time-key
    ✓ Derive secret private key
    
## INSTALL ##

`npm install`
`npm install -g coffee-script`

## NODEJS TEST ##

`npm test`

## BROWSER TESTS ##
(Mac, Linux or Cygwin needed for packaging)

`npm run-script deploy-test`

Open: test/index.html

## DEPLOY ##
(Mac, Linux or Cygwin needed for packaging)

`npm run-script deploy`

## DEVELOP ##

`coffee -w scratchpad/*.coffee`

## ENVIRONMENT ##

Programs in (`./scratchpad`) may rely on these:

```
export BTS_JS=~/bitshares/BitShares-JS
export BTS_WEB=~/bitshares/web_wallet
export BTS_BUILD=~/bitshares/master
#export BTS_BUILD=~/bitshares/develop
#export BTS_BUILD=~/bitshares/toolkit
...
```
