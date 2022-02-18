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

catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))

while [[ $catchingup == "true" ]]; do
    echo "Your node is NOT fully synced yet"
    echo "we'll wait 30s and retry"
    echo
    sleep 30
    catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))
done

read -rsn1 -p"If funded the addresses press any key to continue";echo

read -p "Do you need to create your validator, answer yes or no: " createvalidator
while [[ "$createvalidator" != @(yes|no) ]]; do
    read wishtocreate
done

if [[ "$createvalidator" == "yes" ]]; then

echo "install validator tools"
KEYRING_PASSWORD=$KEYRING TOFND_PASSWORD=$KEYRING ./scripts/validator-tools-host.sh n $NETWORK

echo "adding path to system PATH"
export PATH="$PATH:$HOME/$NETWORKPATH/bin"
echo "done"
echo

broadcaster=$(tail $HOME/$NETWORKPATH/broadcaster.txt | grep address | cut -f2 -d ":")
echo "broadcaster adress is : $broadcaster"

read -rsn1 -p"If funded the addresses press any key to continue";echo

echo "register proxy"
broadcaster=$(tail $HOME/$NETWORKPATH/broadcaster.address)
echo $KEYRING | axelard tx snapshot register-proxy $broadcaster --from validator --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.core
echo "done"
echo

echo "creating a validator"
balance=$(echo $KEYRING | axelard q bank balances $validator | grep amount | cut -d '"' -f 2)
echo "Current validator balance is: $balance"
echo "Leave some balance to pay for fees"
read -p "Amount of selfstake axltest example: 1000000 (without ${denom}) : " uaxl
read -p "Enter validator details : " details
axelarvalconspub=$(echo $KEYRING | axelard tendermint show-validator --home $HOME/$NETWORKPATH/.core)
echo $KEYRING | axelard tx staking create-validator --yes --amount "${uaxl}${denom}" --moniker "$MONIKER" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey=$axelarvalconspub --home $HOME/$NETWORKPATH --chain-id $CHAIN_ID --details "$details" --from validator -b block
echo "done"
echo

echo "Adding chainmaintainers"
echo
echo "Notice: every chain requires an own  entry"
echo "If a wrong address is send in, your node won't come up"
echo
read -p "Do you want to add ethereum as a chain-maintainer, answer yes or no: " ethereum
while [[ "$ethereum" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$ethereum" == "yes" ]]; then
        # setting up eth rpc
        sed -i '/^name = "Ethereum"/{n;N;d}' $HOME/axelarate-community/config/config.toml
        read -p "Type in your ETH Ropsten node address: " eth
        sed -i "/^name = \"Ethereum\"/a rpc_addr    = \"$eth\"\nstart-with-bridge = true" $HOME/axelarate-community/config/config.toml
        echo
        echo "eth bridge enabled"
        echo

        ethereum=ethereum

    fi

read -p "Do you want to add Avalanche as a chain-maintainer, answer yes or no: " avalanche
while [[ "$avalanche" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$avalanche" == "yes" ]]; then

        # setting up Avalanche rpc
        sed -i '/^name = "Avalanche"/{n;N;d}' $HOME/axelarate-community/config/config.toml
        read -p "Type in your Avalanche node address: " avax
        sed -i "/^name = \"Avalanche\"/a rpc_addr    = \"$avax\"\nstart-with-bridge = true" $HOME/axelarate-community/config/config.toml
        echo
        echo "Avalanche bridge enabled"
        echo

        avalanche=avalanche

    fi

read -p "Do you want to add Fantom as a chain-maintainer, answer yes or no: " fantom
while [[ "$fantom" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$fantom" == "yes" ]]; then

        # setting up Fantom rpc
        sed -i '/^name = "Fantom"/{n;N;d}' $HOME/axelarate-community/config/config.toml
        read -p "Type in your Fantom node address: " fantom
        sed -i "/^name = \"Fantom\"/a rpc_addr    = \"$fantom\"\nstart-with-bridge = true" $HOME/axelarate-community/config/config.toml
        echo
        echo "Fantom bridge enabled"
        echo

        fantom=fantom

    fi

read -p "Do you want to add Moonbeam as a chain-maintainer, answer yes or no: " moonbeam
while [[ "$moonbeam" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$moonbeam" == "yes" ]]; then

        # setting up Moonbeam rpc
        sed -i '/^name = "Moonbeam"/{n;N;d}' $HOME/axelarate-community/config/config.toml
        read -p "Type in your Moonbeam node address: " moonbeam
        sed -i "/^name = \"Moonbeam\"/a rpc_addr    = \"$moonbeam\"\nstart-with-bridge = true" $HOME/axelarate-community/config/config.toml
        echo
        echo "Moonbeam bridge enabled"
        echo

        moonbeam=moonbeam

    fi

read -p "Do you want to add Polygon as a chain-maintainer, answer yes or no: " polygon
while [[ "$polygon" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$polygon" == "yes" ]]; then

        # setting up Polygon rpc
        sed -i '/^name = "Polygon"/{n;N;d}' $HOME/axelarate-community/config/config.toml
        read -p "Type in your Polygon node address: " polygon
        sed -i "/^name = \"Polygon\"/a rpc_addr    = \"$polygon\"\nstart-with-bridge = true" $HOME/axelarate-community/config/config.toml
        echo
        echo "Polygon bridge enabled"
        echo

        polygon=polygon

    fi

echo "restarting vald and tofnd"
kill -9 $(pgrep tofnd)
kill -9 $(pgrep -f "axelard vald-start")

cd $HOME/axelarate-community
KEYRING_PASSWORD=$KEYRING TOFND_PASSWORD=$KEYRING ./scripts/validator-tools-host.sh -n $NETWORK
echo "done"
echo

echo "chain maintainers startup"
    if [[ "$ethereum" == "ethereum" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer ethereum --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "ethereum not maintained"
    fi

    if [[ "$avalanche" == "avalanche" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer avalanche --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "avalanche not maintained"
    fi

    if [[ "$fantom" == "fantom" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer fantom --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "fantom not maintained"
    fi

    if [[ "$moonbeam" == "moonbeam" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer moonbeam --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "moonbeam not maintained"
    fi

    if [[ "$polygon" == "polygon" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer polygon --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "polygon not maintained"
    fi

echo "chain maintainers enabled"
echo "Validator completely enabled"
echo "please check explorer or do health check to determine host status"
echo "done"
else
echo "Default node setup completed"
echo "done"
exit 1
fi