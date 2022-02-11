#! /bin/bash

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

echo "Download binary files"
sudo curl  "https://axelar-releases.s3.us-east-2.amazonaws.com/axelard/$CORE_VERSION/axelard-linux-amd64-$CORE_VERSION" -o /usr/local/bin/axelard
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
mkdir $HOME/$NETWORKPATH/config/
echo "done"
echo

echo "Initialize node"
axelard init "$MONIKER" --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH
echo "done"
echo

echo "Downloading config files"
echo "--> Downloading genesis file" 
curl -s --fail https://axelar-$NETWORK.s3.us-east-2.amazonaws.com/genesis.json -o $HOME/$NETWORKPATH/config/genesis.json
echo "--> Downloading latest seeds"
curl -s --fail https://axelar-$NETWORK.s3.us-east-2.amazonaws.com/seeds.txt -o $HOME/$NETWORKPATH/config/seeds.txt
echo "--> Copying config files"
cp $HOME/axelarate-community/configuration/config.toml $HOME/$NETWORKPATH/config/
cp $HOME/axelarate-community/configuration/app.toml $HOME/$NETWORKPATH/config/
echo "done"
echo

echo "Adding seeds to config toml"
add_seeds() {
  seeds=$(cat "$HOME/$NETWORKPATH/config/seeds.txt")
  sed "s/^seeds =.*/seeds = \"$seeds\"/g" "$HOME/$NETWORKPATH/config/config.toml" >"$HOME/$NETWORKPATH/config/config.toml.tmp"
  mv "$HOME/$NETWORKPATH/config/config.toml.tmp" "$HOME/$NETWORKPATH/config/config.toml"
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

sed -i "s/external_address = \"\"/external_address = \"$public_ip:26656\"/" $HOME/$NETWORKPATH/config/config.toml
echo "done"
echo

echo "downloading snapshot file"

cd $HOME/$NETWORKPATH
wget $SNAPSHOTURL
echo "remove any old data"
rm -rf  $HOME/$NETWORKPATH/data
echo "extracting the data"
lz4 -d $SNAPSHOTFILE | tar xf -
echo "done"
echo

echo "creating service"
sudo bash -c "cat > /etc/systemd/system/axelar-node.service << EOF
[Unit]
Description=axelard-node
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/axelard start --home $HOME/$NETWORKPATH
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

echo "creating wallets"
echo "--> creating axelar validator wallet"
echo $KEYRING | axelard keys add validator --home $HOME/$NETWORKPATH &> $HOME/validator.txt
echo "--> creating axelar broadcaster wallet"
echo $KEYRING | axelard keys add broadcaster --home $HOME/$NETWORKPATH &> $HOME/broadcaster.txt
echo "--> creating Tofnd wallet"
echo $KEYRING | tofnd -m create -d "$HOME/$NETWORKPATH/.tofnd"
mv $HOME/$NETWORKPATH/.tofnd/export $HOME/$NETWORKPATH/.tofnd/import

echo "Node setup done"
echo "Please fund broadcaster and validator address"
validator=$(tail $HOME/validator.txt | grep address | cut -f2 -d ":")
echo "validator adress is : $validator"
broadcaster=$(tail $HOME/broadcaster.txt | grep address | cut -f2 -d ":")
echo "broadcaster adress is : $broadcaster"

read -rsn1 -p"If funded the addresses press any key to continue";echo

read -p "Do you need to create your validator, answer yes or no: " createvalidator
while [[ "$createvalidator" != @(yes|no) ]]; do
    read wishtocreate
done

if [[ "$createvalidator" == "yes" ]]; then
echo "Setup validator tools"
echo
echo "-->setup TOFND service"
sudo bash -c "cat > /etc/systemd/system/tofnd.service << EOF
[Unit]
Description=tofnd
After=network-online.target

[Service]
User=$USER
ExecStart=bin/sh -c 'echo $KEYRING | tofnd -m existing -d $HOME/$NETWORK/.tofnd'
Restart=always
RestartSec=3
LimitNOFILE=16384
MemoryMax=4G
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF"
echo
echo "enable and start tofnd service"
sudo systemctl enable tofnd.service 
sudo systemctl start tofnd.service
echo "--> setup vald service"
(cat $HOME/broadcaster.txt | tail -1 ; echo $KEYRING ; echo $KEYRING) | axelard keys add broadcaster --recover --home $HOME/$NETWORK/.vald
cp $HOME/$NETWORK/config/config.toml $HOME/$NETWORK/.vald/config/config.toml
cp $HOME/$NETWORK/config/app.toml $HOME/$NETWORK/.vald/config/app.toml
cp $HOME/$NETWORK/config/genesis.json $HOME/$NETWORK/.vald/config/genesis.json

sudo bash -c "cat > /etc/systemd/system/axelard-val.service << EOF
[Unit]
Description=axelard-val
After=network-online.target

[Service]
User=$USER
ExecStart=bin/sh -c 'echo $KEYRING |axelard vald-start --tofnd-host localhost --node http://localhost:26657 --home $HOME/$NETWORK/.vald --validator-addr $validator --log_level debug --chain-id $CHAIN --from broadcaster'
Restart=always
RestartSec=3
LimitNOFILE=16384
MemoryMax=4G
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF"
echo
echo "--> enable and start vald services"

sudo systemctl enable axelard-val.service
sudo systemctl start axelard-val.service
echo "done"
echo