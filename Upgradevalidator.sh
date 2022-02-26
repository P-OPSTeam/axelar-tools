#! /bin/bash

sudo apt update

REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo "Checking for $REQUIRED_PKG: $PKG_OK"
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

###    CONFIG    ##################################################################################################
CONFIG=""                # config.toml file for node, eg. $HOME/.gaia/config/config.toml
NETWORK=""               # Network for choosing testnet or mainnet, no caps!
KEYRING=""      # if left empty monitoring won't work

if  [ -z "$NETWORK" ];then
    read -p "Enter network, testnet or mainnet :" NETWORK
fi

read -p "Do you run a validator, answer yes or no: " validator

if [ "$NETWORK" == testnet ]; then
    echo "Network switched to Testnet"
    NETWORKPATH=".axelar_testnet"
    CONFIG=$HOME/$NETWORKPATH/.core/config/config.toml
    CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep axelar-core | cut -d \` -f 4)
    TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep tofnd | cut -d \` -f 4)
else
    echo "Network switched to Mainnet"
    NETWORKPATH=".axelar"
    CONFIG=$HOME/$NETWORKPATH/.core/config/config.toml
    CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep axelar-core | cut -d \` -f 4)
    TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep tofnd | cut -d \` -f 4)
fi

if [ -z "$CONFIG" ]; then 
    echo "please configure config.toml in script"
    exit 1
fi

if [ -z "$KEYRING" ]; then
    echo "Please enter the password one time below, if setting up as a service fill the field in the script"
    read -p "Enter your password for polling the keys :" KEYRING
fi

url=$(sudo sed '/^\[rpc\]/,/^\[/!d;//d' "$CONFIG" | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
if [ -z "$url" ]; then
    echo "please configure config.toml in script correctly"
    exit 1
fi
url="http://${url}"

# stop validator binary tools
echo Stopping axelar-core, vald and tofnd processes
pkill -f 'axelard start'
pkill -f tofnd
kill -9 $(pgrep -f "axelard vald-start")
echo "done"
echo 

echo "Clone/Refresh Axerlar Community Github"
cd ~/axelarate-community
git clone
echo "done"
echo

# Backup .axelar_testnet folder
echo "Backup the $NETWORKPATH folder"
cp -r $HOME/$NETWORKPATH $HOME/${NETWORKPATH}_backup
backupdir=$HOME/${NETWORKPATH}_backup
echo "Copy created, you can find it at $backupdir"
echo

# starting Axelar-core
echo "restoring old config file regarding chainmaintainers"
cp $backupdir/shared/config.toml ~/axelarate-community/configuration/config.toml
echo "done"
echo
echo "Starting axelar core"
cd ~/axelarate-community/
KEYRING_PASSWORD=$KEYRING ./scripts/node.sh -e host -n "$NETWORK" -a "$CORE_VERSION"

echo "Checking if node is on latest block"
catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))

while [[ $catchingup == "true" ]]; do
    echo "Your node is NOT fully synced yet"
    echo "we'll wait 30s and retry"
    echo
    sleep 30
    catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))
done
echo "Node is on latest block"
echo

if [[ "$validator" == "yes" ]]; then
echo "start axelar validator tools"
KEYRING_PASSWORD=$KEYRING TOFND_PASSWORD=$KEYRING ./scripts/validator-tools-host.sh -n "$NETWORK" -a "$CORE_VERSION" -q "$TOFND_VERSION"
echo "done"
fi
echo