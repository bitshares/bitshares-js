# Usage (one of these):
# ./client.sh
# ./client.sh 001
# GDB="gdb -ex run --args" ./client.sh

# The first parameter is the client number.  This is different for each client.  It defaults to 000 and is used for both the data-dir and HTTP/RPC port suffix.
# The second parameter is the delegate number (p2p port suffix).  This parameter also default to 000.
client_num=${1-000}
delegate_num=${2-000}

BTS_BUILD=${BTS_BUILD-~/bitshares/bitshares}
BTS_JS=${BTS_JS-~/bitshares/BitShares-JS}

testnet_datadir="$BTS_JS/testnet/tmp/client${client_num}"

HTTP_PORT=${HTTP_PORT-44${client_num}}	# 44000
RPC_PORT=${RPC_PORT-45${client_num}}	# 45000
P2P_HOST=127.0.0.1:10${delegate_num}	# 10000

function rpc {
  method=${1?rpc method name}
  params=${2?rpc parameters in json format}
  echo $method $params
  curl http://test:test@localhost:${HTTP_PORT}/rpc --data-binary '{"method":"'"${method}"'","params":['"${params}"'],"id":0}"'
}

function init {
  if test -d "$testnet_datadir/wallets/default"
  then
    if [ -z "$GDB" ]
    then
        sleep 10
    else
        sleep 10
    fi
    echo "Login..."
    # the process may be gone, re-indexing, etc. just error silently
    rpc open '"default"' > /dev/null 2>&1
    rpc unlock '99999, "Password00"' > /dev/null 2>&1
  else
    sleep 10
    echo "Creating default wallet..."
    rpc wallet_backup_restore '"'$BTS_JS'/testnet/config/wallet.json", "default", "Password00"'
  fi
}
init&

set -o xtrace

${GDB-} \
"${BTS_BUILD}/programs/client/bitshares_client"\
 --data-dir "$testnet_datadir"\
 --genesis-config "$BTS_JS/testnet/config/genesis.json"\
 --server\
 --httpport=$HTTP_PORT\
 --rpcport=$RPC_PORT\
 --rpcuser=test\
 --rpcpassword=test\
 --upnp=false\
 --connect-to=$P2P_HOST\
 --disable-default-peers

