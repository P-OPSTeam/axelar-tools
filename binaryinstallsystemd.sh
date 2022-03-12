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
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}

echo "Determining Tofnd version" 
TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep tofnd | cut -d \` -f 4)
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

echo "Clone Axelar Community Github"
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/ 
cd ~ 
git clone https://github.com/axelarnetwork/axelarate-community.git >/dev/null 2>&1 
cd ~/axelarate-community 
echo "done"
echo

echo "Download binary files"
sudo curl -s "https://axelar-releases.s3.us-east-2.amazonaws.com/axelard/$CORE_VERSION/axelard-linux-amd64-$CORE_VERSION" -o /usr/local/bin/axelard
sudo curl -s --fail https://axelar-releases.s3.us-east-2.amazonaws.com/tofnd/$TOFND_VERSION/tofnd-linux-amd64-$TOFND_VERSION -o /usr/local/bin/tofnd
echo "done"
echo

echo "make the binary executable"
sudo chmod +x /usr/local/bin/axelard
sudo chmod +x /usr/local/bin/tofnd
echo "done"
echo

echo "setting vaiables"

echo "make directory"
mkdir $HOME/$NETWORKPATH
mkdir $HOME/$NETWORKPATH/.core
mkdir $HOME/$NETWORKPATH/.core/config/
echo "done"
echo

echo "Initialize node"
axelard init "$MONIKER" --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH
echo "done"
echo

echo "Downloading config files"
echo "--> Downloading genesis file" 
curl -s --fail https://axelar-$NETWORK.s3.us-east-2.amazonaws.com/genesis.json -o $HOME/$NETWORKPATH/.core/config/genesis.json
echo "--> Downloading latest seeds"
curl -s --fail https://axelar-$NETWORK.s3.us-east-2.amazonaws.com/seeds.txt -o $HOME/$NETWORKPATH/.core/config/seeds.txt
echo "--> Copying config files"
cp $HOME/axelarate-community/configuration/config.toml $HOME/$NETWORKPATH/.core/config/
cp $HOME/axelarate-community/configuration/app.toml $HOME/$NETWORKPATH/.core/config/
echo "done"
echo

echo "Adding seeds to config toml"
add_seeds() {
  seeds=$(cat "$HOME/$NETWORKPATH/.core/config/seeds.txt")
  sed "s/^seeds =.*/seeds = \"$seeds\"/g" "$HOME/$NETWORKPATH/.core/config/config.toml" >"$HOME/$NETWORKPATH/.core/config/config.toml.tmp"
  mv "$HOME/$NETWORKPATH/.core/config/config.toml.tmp" "$HOME/$NETWORKPATH/.core/config/config.toml"
}

add_seeds
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

sed -i "s/external_address = \"\"/external_address = \"$public_ip:26656\"/" $HOME/$NETWORKPATH/.core/config/config.toml
echo "done"
echo

echo "downloading snapshot file"

cd $HOME/$NETWORKPATH/.core
wget $SNAPSHOTURL
echo "remove any old data"
rm -rf  $HOME/$NETWORKPATH/.core/data
echo "extracting the data"
lz4 -d $SNAPSHOTFILE | tar xf -
rm $SNAPSHOTFILE
echo "done"
echo

echo "creating service"
sudo bash -c "cat > /etc/systemd/system/axelar-node.service << EOF
[Unit]
Description=axelard-node
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/axelard start --home $HOME/$NETWORKPATH/.core
Restart=always
RestartSec=3
LimitNOFILE=16384
MemoryMax=8G
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl enable axelar-node.service
sudo systemctl start axelar-node

echo "done"
echo

echo "wait a few seconds to start the node"
sleep 15
echo "done"

echo "creating wallets"
echo "--> creating axelar validator wallet"
(echo $KEYRING ; echo $KEYRING) | axelard keys add validator --home $HOME/$NETWORKPATH/.core &> $HOME/validator.txt
echo "--> creating axelar broadcaster wallet"
(echo $KEYRING ; echo $KEYRING) | axelard keys add broadcaster --home $HOME/$NETWORKPATH/.core &> $HOME/broadcaster.txt
echo "--> creating Tofnd wallet"
echo $KEYRING | tofnd -m create -d "$HOME/$NETWORKPATH/.tofnd"
mv $HOME/$NETWORKPATH/.tofnd/export $HOME/$NETWORKPATH/.tofnd/import

echo access2all | axelard keys show validator --home $HOME/$NETWORKPATH/.core --bech val -a > $HOME/$NETWORKPATH/validator.bech
echo "Node setup done"
echo "Please fund broadcaster and validator address"
validator=$(tail $HOME/validator.txt | grep address | cut -f2 -d ":")
echo "validator adress is : $validator"
broadcaster=$(tail $HOME/broadcaster.txt | grep address | cut -f2 -d ":")
echo "broadcaster adress is : $broadcaster"

echo "Please copy and fund the addresses"
echo "node install is done, use option 6 for setting up the validator for systemd"