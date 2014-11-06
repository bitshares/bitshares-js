# Bitshares Web Toolkit

## Development

Install dependencies
```
npm install
# bitcoinjs-lib submodule
git submodule init
git submodule update

# todo, is sub-module bitcoinjs-lib locked to 106e00e6f104443a5628662baf8ac2bb417b7df8
pushd node_modules/bitcoinjs-lib && npm install && popd
```
### Run Unit Tests

Some unit tests require the RPC server.  This server is in the bitshares_toolkit:
```
pushd ~/bitshares/bitshares_toolkit/programs/client
./bitshares_client --server --httpport 9989 --rpcuser user --rpcpassword password --daemon
```
On the same host, run:
```
export HTTP_PORT=2201
npm test
```
### Commands

Compile `bitshares-webtoolkit-min.js` with the following command:
```
TODO npm run-script compile
```
Create API documentation (see: ./out):
```
npm run-script jsdoc
```
Code coverage reports (see: ./coverage)
```
npm run-script coverage
```
