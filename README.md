# BitShares-JS #

Pure JavaScript library for the BitShares platform. 

## Features ##

Run the Mocha unit tests and view sample code from your [browser](http://dev.jcalfee.info/bts/mocha).

## INSTALL ##

```
npm install
npm install -g coffee-script
```

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
