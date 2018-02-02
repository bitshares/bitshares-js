# BitShares-JS #

JavaScript library for the BitShares platform.  This repository does not contain a graphical user interface.  

## Features ##

* Enables the the BitShares platform to run from the [web](https://wallet.bitshares.org).

## INSTALL ##

```
npm install
npm install -g coffee-script
```

## NODEJS TEST ##

`npm test`

## BROWSER TESTS ##
(Mac, Linux or Cygwin needed for packaging)

`npm run-script package_tests`

Open: test/index.html

## DEPLOY ##

```
BTS_WEB=~/bitshares/web_wallet
npm run-script web_wallet
```
