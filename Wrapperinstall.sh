#! /bin/bash

sudo apt update

REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="liblz4-tool"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

denom=uaxl

if [ -z $MONIKER ]; then
    echo "Please enter Moniker name below"
    read -p "Enter Moniker name :" MONIKER
fi

if  [ -z "$NETWORK" ];then
    read -p "Enter network, testnet or mainnet :" NETWORK
fi

read -p "Enter your KEYRING PASSWORD : " KEYRING

# Determining Axelar versions
echo "Determining Axelar version" 
CORE_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}

echo "Determining Tofnd version" 
TOFND_VERSION=$(curl -s https://docs.axelar.dev/resources/$NETWORK-releases.md  | grep tofnd | cut -d \` -f 4)
echo ${TOFND_VERSION}
echo

if [ "$NETWORK" == testnet ]; then
echo "Setup node for axelar testnet"
echo "Determining testnet chain"
CHAIN_ID=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/scripts/node.sh | grep chain_id=axelar-t | cut -f2 -d "=")
NETWORKPATH=".axelar_testnet"
SNAPSHOTURL=$(curl https://quicksync.io/axelar.json|jq -r '.[] |select(.file=="axelartestnet-lisbon-3-pruned")|.url')
SNAPSHOTFILE=$(curl https://quicksync.io/axelar.json|jq -r '.[] |select(.file=="axelartestnet-lisbon-3-pruned")|.url' | cut -c26-)
else
echo "Setup node for axelar mainnet"
echo "Determining mainnet chain"
CHAIN_ID=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/scripts/node.sh | grep chain_id=axelar-d | cut -f2 -d "=")
NETWORKPATH=".axelar"
SNAPSHOTURL=$(curl https://quicksync.io/axelar.json|jq -r '.[] |select(.file=="axelar-dojo-1-default")|.url')
SNAPSHOTFILE=$(curl https://quicksync.io/axelar.json|jq -r '.[] |select(.file=="axelar-dojo-1-default")|.url' | cut -c26-)
fi

echo "Clone Axerlar Community Github"
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/ 
cd ~ 
git clone https://github.com/axelarnetwork/axelarate-community.git >/dev/null 2>&1 
cd ~/axelarate-community 
echo "done"
echo

echo "make directory"
mkdir $HOME/$NETWORKPATH/
mkdir $HOME/$NETWORKPATH/.core/
echo "done"
echo

echo "Adding external ip to config file"
public_ip=$(curl -s ifconfig.me)
echo "See your public IP: $public_ip, this will be used to update config.toml"

read -p "Press enter to continue, or type ENTERIP to reenter a new one: " reenterip

if [ ! -z $reenterip ] && [ $reenterip == "ENTERIP" ]; then
    read -p "Enter your public ip : " public_ip
    test='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
    while [[ !($public_ip =~ ^$test\.$test\.$test\.$test$) ]]; do
        read -p "invalid ip, pleeas re-enter : " public_ip 
    done
fi
echo "Final public ip used is $public_ip"

sed -i "s/external_address = \"\"/external_address = \"$public_ip:26656\"/" $HOME/axelarate-community/configuration/config.toml
echo "done"
echo

echo "downloading snapshot file"

cd $HOME/$NETWORKPATH/.core/
wget $SNAPSHOTURL
echo "remove any old data"
rm -rf  $HOME/$NETWORKPATH/data
echo "extracting the data"
lz4 -d $SNAPSHOTFILE | tar xf -
echo "done"
echo

echo "starting axelar-core"
cd ~/axelarate-community
KEYRING_PASSWORD=$KEYRING ./scripts/node.sh -a $CORE_VERSION -n $NETWORK

echo "Node setup done"
echo "Please fund validator address and wait for the node to be fully synced"
validator=$(tail $HOME/$NETWORKPATH/validator.txt | grep address | cut -f2 -d ":")
echo "validator adress is : $validator"
echo "If you want to run a validator please choose option 5"
echo "done"