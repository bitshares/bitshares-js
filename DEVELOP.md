## ENVIRONMENT ##

```
export BTS_JS=~/bitshares/BitShares-JS
export BTS_WEB=~/bitshares/web_wallet
export BTS_BUILD=~/bitshares/master
#export BTS_BUILD=~/bitshares/develop
#export BTS_BUILD=~/bitshares/toolkit
```

## DEVELOP ##

`coffee -w scratchpad/*.coffee`

The `coffee -w` command will monitor and re-run localized changes in the one scratchpad file.  If your changes are not localized use the "test" command from ./packages.json and you may add a `--watch` parameter.  You'll need to add extra mocha methods (`describe` and `it`) to get things going.  Be aware that, in both cases, line numbers will drift as you add or remove lines so restart as-needed.

`npm run-script web_wallet&`

The `web_wallet` task will monitor files for changes and re-deploy bitshares-js into the github.com/bitshares/web_wallet's $BTS_WEB/vendor/js hot-deploy directory.  The web_wallet's bitshares-js branch has code to detect this library and re-direct wallet RPC commands.  This command works in parallel with the web_wallet's own change monitoring and deploy command: `HTTP_PORT=44000 lineman run&`

