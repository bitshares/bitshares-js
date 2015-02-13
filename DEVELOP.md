## ENVIRONMENT ##

```
export BTS_JS=~/bitshares/BitShares-JS
export BTS_WEB=~/bitshares/web_wallet
export BTS_BUILD=~/bitshares/master
#export BTS_BUILD=~/bitshares/develop
#export BTS_BUILD=~/bitshares/toolkit
```

## DEVELOP ##

```
BTS_WEB=~/bitshares/web_wallet
npm run-script develop&
cd $BTS_WEB
HTTP_PORT=44000 lineman run
```
