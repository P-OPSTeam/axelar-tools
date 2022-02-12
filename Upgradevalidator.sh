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
VALIDATORADDRESS=""      # if left empty default is from status call (validator)

if  [ -z "$NETWORK" ];then
    echo "please configure Network variable in script"
    exit 1
fi

if [ "$NETWORK" == testnet ]; then
    echo "Network switched to Testnet"
    NETWORKPATH=".axelar_testnet"
    CONFIG=$HOME/$NETWORKPATH/.core/config/config.toml
    CORE_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md | grep axelar-core | cut -d \` -f 4)
    TOFND_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md | grep tofnd | cut -d \` -f 4)
else
    echo "Network switched to Mainnet"
    NETWORKPATH=".axelar"
    CONFIG=$HOME/$NETWORKPATH/.core/config/config.toml
    CORE_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md | grep axelar-core | cut -d \` -f 4)
    TOFND_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md | grep tofnd | cut -d \` -f 4)
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

if [ -z "$VALIDATORADDRESS" ]; then VALIDATORADDRESS=$(jq -r ''.result.validator_info.address'' <<<$(curl -s "$url"/status)); fi
if [ -z "$VALIDATORADDRESS" ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

# Checking validator RPC endpoints status
consdump=$(curl -s "$url"/dump_consensus_state)
validators=$(jq -r '.result.round_state.validators[]' <<<"$consdump")
isvalidator=$(grep -c "$VALIDATORADDRESS" <<<"$validators")

# stop validator binary tools
echo Stopping axelar-core, vald and tofnd processes
pkill -f 'axelard start'
pkill -f tofnd
kill -9 $(pgrep -f "axelard vald-start")
echo "done"
echo 

echo "Clone/Refresh Axerlar Community Github"
rm -rf ~/axelarate-community/
cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community
echo "done"
echo

# Backup .axelar_testnet folder
echo "Backup the $NETWORKPATH folder"
cp -r ~/$NETWORKPATH ~/${NETWORKPATH}_backup
backupdir=~/${NETWORKPATH}_backup
echo "Copy created, you can find it at $backupdir"
echo

# starting Axelar-core
echo "restoring old config file regarding chainmaintainers"
cp -r ~/$backupdir/shared/config.toml ~/axelarate-community/configuration/config.toml
echo "done"
echo
echo "Starting axelar core"
cd ~/axelarate-community/
KEYRING_PASSWORD=$KEYRING ./scripts/node.sh -e host -n "$NETWORK" -a "$CORE_VERSION"
if [ "$isvalidator" != "0" ]; then
echo "start axelar validator tools"
KEYRING_PASSWORD=$KEYRING TOFND_PASSWORD=$KEYRING ./scripts/validator-tools-host.sh -n "$NETWORK" -a "$CORE_VERSION" -q "$TOFND_VERSION"
echo "done"
fi
echo