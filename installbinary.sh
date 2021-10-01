#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>installbinary.log 2>&1
# Everything below will go to the file 'installbinary.log':
echo "logs can be found in installbinary.log"

echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done" >&3
echo >&3

# run the validator
# Determining Axelar versions
echo "Determining latest Axelar version" >&3
AXELAR_CORE_VERSION="$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)"
echo "done" >&3
echo >&3

echo "Clone Axerlar Community Github" >&3

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community
echo "done" >&3
echo >&3

# Determining Directory's
echo "Defining and creating directory's axelar node" >&3
GIT_ROOT="$HOME/axelarate-community"
ROOT_DIRECTORY="$HOME/.axelar_testnet"
mkdir -p "$ROOT_DIRECTORY"
TOFND_DIRECTORY="$HOME/.tofnd"
mkdir -p "$TOFND_DIRECTORY"
BIN_DIRECTORY="$ROOT_DIRECTORY/bin"
mkdir -p "$BIN_DIRECTORY"
LOGS_DIRECTORY="${ROOT_DIRECTORY}/logs"
mkdir -p "$LOGS_DIRECTORY"
CORE_DIRECTORY="${ROOT_DIRECTORY}/.core"
mkdir -p "$CORE_DIRECTORY"
CONFIG_DIRECTORY="${CORE_DIRECTORY}/config"
mkdir -p "$CONFIG_DIRECTORY"

AXELARD="$BIN_DIRECTORY/axelard"
echo "Done" >&3
echo >&3

# Defining CPU and OS
OS="$(uname | awk '{print tolower($0)}')"
ARCH="$(uname -m)"

# override ARCH with amd64 for x86 arch
if [ "x86_64" =  "$ARCH" ]; then
  ARCH=amd64
fi

# Determining core version to download
echo "Downloading Axelar files" >&3
AXELARD_BINARY="axelard-${OS}-${ARCH}-${AXELAR_CORE_VERSION}"

if [ ! -f "${AXELARD}" ]; then
  echo "--> Downloading axelard binary $AXELARD_BINARY" >&3
  curl -s --fail https://axelar-releases.s3.us-east-2.amazonaws.com/axelard/${AXELAR_CORE_VERSION}/${AXELARD_BINARY} -o "${AXELARD}" && chmod +x "${AXELARD}"
fi

if [ ! -f "${CONFIG_DIRECTORY}/genesis.json" ]; then
  echo "--> Downloading genesis.json" >&3
  curl -s --fail https://axelar-testnet.s3.us-east-2.amazonaws.com/genesis.json -o "${CONFIG_DIRECTORY}/genesis.json"
fi

if [ ! -f "${CONFIG_DIRECTORY}/peers.txt" ]; then
  echo "--> Downloading peers.txt" >&3
  curl -s --fail https://axelar-testnet.s3.us-east-2.amazonaws.com/peers.txt -o "${CONFIG_DIRECTORY}/peers.txt"
fi

if [ ! -f "${CONFIG_DIRECTORY}/config.toml" ]; then
  echo "--> Moving config.toml to config directory" >&3
  cp "${GIT_ROOT}/join/config.toml" "${CONFIG_DIRECTORY}/config.toml"
fi

if [ ! -f "${CONFIG_DIRECTORY}/app.toml" ]; then
  echo "--> Moving app.toml to config directory" >&3
  cp "${GIT_ROOT}/join/app.toml" "${CONFIG_DIRECTORY}/app.toml"
fi

echo "Done" >&3
echo >&3

# Adding peers
echo "Adding peers" >&3

addPeers() {
  echo "Adding peers to config.toml"
  sed "s/^seeds =.*/seeds = \"$1\"/g" "$CONFIG_DIRECTORY/config.toml" >"$CONFIG_DIRECTORY/config.toml.tmp" &&
  mv "$CONFIG_DIRECTORY/config.toml.tmp" "$CONFIG_DIRECTORY/config.toml"
}

addPeers "$(cat "${CONFIG_DIRECTORY}/peers.txt")"

echo "Done" >&3
echo >&3

# run the validator
echo "start the Axelar node" >&3

export NODE_MONIKER=${NODE_MONIKER:-"$(hostname)"}
export AXELARD_CHAIN_ID=${AXELARD_CHAIN_ID:-"axelar-testnet-adelaide"}
ACCOUNTS=$($AXELARD keys list -n --home $CORE_DIRECTORY)
for ACCOUNT in $ACCOUNTS; do
    if [ "$ACCOUNT" == "validator" ]; then
        HAS_VALIDATOR=true
    fi
done

touch "$ROOT_DIRECTORY/validator.txt"
if [ -z "$HAS_VALIDATOR" ]; then
  if [ -f "$AXELAR_MNEMONIC_PATH" ]; then
    "$AXELARD" keys add validator --recover --home $CORE_DIRECTORY <"$AXELAR_MNEMONIC_PATH"
  else
    "$AXELARD" keys add validator --home $CORE_DIRECTORY > "$ROOT_DIRECTORY/validator.txt" 2>&1
  fi
fi

"$AXELARD" keys show validator -a --bech val --home $CORE_DIRECTORY > "$ROOT_DIRECTORY/validator.bech"

if [ ! -f "$CONFIG_DIRECTORY/genesis.json" ]; then
  "$AXELARD" init "$NODE_MONIKER" --chain-id "$AXELARD_CHAIN_ID" --home $CORE_DIRECTORY
  if [ -f "$TENDERMINT_KEY_PATH" ]; then
    cp -f "$TENDERMINT_KEY_PATH" "$CONFIG_DIRECTORY/priv_validator_key.json"
  fi
fi

export START_REST=true

"$AXELARD" start --home $CORE_DIRECTORY > "$LOGS_DIRECTORY/axelard.log" 2>&1 &

VALIDATOR=$("$AXELARD" keys show validator -a --bech val --home $CORE_DIRECTORY)
echo >&3
echo "Axelar node running."  >&3
echo  >&3
echo "Validator address: $VALIDATOR"  >&3
echo  >&3
cat "$ROOT_DIRECTORY/validator.txt" >&3
rm "$ROOT_DIRECTORY/validator.txt"
echo >&3
echo "Do not forget to also backup the tendermint key (${CONFIG_DIRECTORY}/priv_validator_key.json)" >&3
echo  >&3
echo "To follow execution, run 'tail -f ${LOGS_DIRECTORY}/axelard.log'" >&3
echo "To stop the node, run 'killall -9 \"axelard\"'"  >&3
echo  >&3