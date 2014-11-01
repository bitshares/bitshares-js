# Usage (one of these):
# ./client.sh
# ./client.sh 001
# GDB="gdb -ex run --args" ./client.sh

# The first parameter is the client number.  This is different for each client.  It defaults to 000 and is used for both the data-dir and HTTP/RPC port suffix.
# The second parameter is the test net number (p2p port suffix).  This parameter also default to 000.
client_num=${1-000}
testnet_num=${2-000}

testnet_datadir="tmp/client${client_num}"

BTS_BUILD=${BTS_BUILD-~/bitshares/bitshares_toolkit}
BTS_WEBKIT=${BTS_WEBKIT-~/bitshares/bitshares_webkit}

HTTP_PORT=${HTTP_PORT-44${client_num}}	# 44000
RPC_PORT=${RPC_PORT-45${client_num}}	# 45000
P2P_HOST=127.0.0.1:10${testnet_num}	# 10000

function init {
  . ./bin/rpc_function.sh
  if test -d "$testnet_datadir/wallets/default"
  then
    if [ -z "$GDB" ]
    then
        sleep 3
    else
        sleep 10
    fi
    echo "Login..."
    # the process may be gone, re-indexing, etc. just error silently
    rpc open '"default"' > /dev/null 2>&1
    rpc unlock '9999, "Password00"' > /dev/null 2>&1
  else
    sleep 3
    echo "Creating default wallet..."
    rpc wallet_backup_restore '"config/wallet.json", "default", "Password00"'
  fi
}
init&

set -o xtrace

${GDB-} \
"${BTS_BUILD}/programs/client/bitshares_client"\
 --data-dir "$testnet_datadir"\
 --genesis-config "$BTS_WEBKIT/testnet/config/genesis.json"\
 --server\
 --httpport=$HTTP_PORT\
 --rpcport=$RPC_PORT\
 --rpcuser=test\
 --rpcpassword=test\
 --upnp=false\
 --connect-to=$P2P_HOST\
 --disable-default-peers
