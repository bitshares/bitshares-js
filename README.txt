
## ENVIRONMENT

export BTS_WEB=~/bitshares/bitshares_toolkit/programs/web_wallet

# in-source build OR out-of-source build
export BTS_BUILD=~/bitshares/bitshares_toolkit
export BTS_BUILD=~/bitshares/bitshares_toolkit/build

## INSTALL

npm install
npm install -g coffee-script

## RUN

npm test


## DEVELOP

coffee -w scratchpad_... .coffee

## BROWSER DEPLOY

cake browserify

