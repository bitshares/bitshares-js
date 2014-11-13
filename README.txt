
## INSTALL

npm install
npm install -g coffee-script

## TEST

npm test


## DEVELOP

coffee -w scratchpad/... .coffee

## BROWSER TESTS

npm run-script deploy-test

Open: test/index.html

## TESTNET ENVIRONMENT (./scratchpad)

export BTS_JS=~/bitshares/BitShares-JS
export BTS_BUILD=~/bitshares/develop
export BTS_BUILD=~/bitshares/toolkit
export BTS_BUILD=~/bitshares/master
...

