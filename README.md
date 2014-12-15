# BitShares-JS #

Pure JavaScript library for the BitShares platform. 

## Features ##
```
  Crypto
    ✓ Decrypts master key 

  Key Convert
    ✓ Create BTS short address (64ms)
    ✓ Blockchain Address 
    ✓ BTS public key import / export 
    ✓ PTS (39ms)
    ✓ To WIF 
    ✓ From WIF 
    ✓ Calc public key (44ms)
    ✓ Decrypt private key 

  Encrypted Mail
    ✓ Parse and generate 

  Mail
    ✓ Parse and generate (binary) 
    ✓ Matching one_time_key 
    ✓ Decrypt using shared secret 
    ✓ Encrypt using shared secret 

  Email
    ✓ Parse and generate (binary) 
    ✓ Check each field 
    ✓ Verify (78ms)
    ✓ Sign & Verify (464ms)

  Transactions
    ✓ Decrypt 
    ✓ Parses transaction_notice_message 
    ✓ Regenerates transaction_notice_message 
    ✓ Verify transaction signatures (50ms)
    ✓ Verify memo signature (51ms)
    ✓ Extended owner key (72ms)
    ✓ Extended one-time-key 
    ✓ Derive secret private (39ms)

  Proof-of-Work
    ✓ Find passing hash (43ms)

  Wallet
    ✓ Serializes unchanged 

```
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
