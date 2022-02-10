#! /bin/bash

if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true" 
    else
    reset="false" 
fi

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


# Determining Axelar versions
echo "Determining Axelar version" 
CORE_VERSION=$(curl -s https://docs.axelar.dev/resources/testnet-releases.md | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}

echo "Determining Tofnd version" 
TOFND_VERSION=$(curl -s https://docs.axelar.dev/resources/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo ${TOFND_VERSION}
echo

echo "Determining Testnet chain"
CHAIN_ID=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/scripts/node.sh | grep chain_id=axelar-t | cut -f2 -d "=")

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

## replace <node-name> with your value
echo 'export ACCOUNT=$MONIKER' >> $HOME/.bashrc
echo 'export CHAIN=$CHAIN_ID' >> $HOME/.bashrc
source $HOME/.bashrc

axelard init "$MONIKER" --chain-id $CHAIN_ID --home $HOME/.axelar_testnet
echo "done"
echo

echo "make directory"
mkdir $HOME/.axelar_testnet/
mkdir $HOME/.axelar_testnet/config/
echo "done"
echo

echo "Downloading config files"
echo "--> Downloading genesis file" 
curl -s --fail https://axelar-testnet.s3.us-east-2.amazonaws.com/genesis.json -o $HOME/.axelar_testnet/config/genesis.json
echo "--> Downloading latest seeds"
curl -s --fail https://axelar-testnet.s3.us-east-2.amazonaws.com/seeds.txt -o $HOME/.axelar_testnet/config/seeds.txt
echo "--> Copying config files"
cp $HOME/axelarate-community/configuration/config.toml $HOME/.axelar_testnet/config/
cp $HOME/axelarate-community/configuration/app.toml $HOME/.axelar_testnet/config/
echo "done"
echo

echo "downloading snapshot file"
cd $HOME/.axelar_testnet/
wget https://dl2.quicksync.io/axelartestnet-lisbon-3-pruned.20220209.2240.tar.lz4
echo "remove any old data"
rm -rf  $HOME/.axelar_testnet/data
echo "extracting the data"
lz4 -d axelartestnet-lisbon-3-pruned.20220209.2240.tar.lz4 | tar xf -
echo "done"
echo

echo "creating service"
sudo bash -c "cat > /etc/systemd/system/axelar-node.service << EOF
[Unit]
Description=axelard-node
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/axelard start --home $HOME/.axelar_testnet
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
axelard keys add validator --home $HOME/.axelar_testnet > $HOME/validator.txt
echo "--> creating axelar broadcaster wallet"
axelard keys add broadcaster --home $HOME/.axelar_testnet > $HOME/broadcaster.txt
echo "--> creating Tofnd wallet"
tofnd -m create -d "$HOME/.axelar_testnet/.tofnd"
mv $HOME/.axelar_testnet/.tofnd/export $HOME/.axelar_testnet/.tofnd/import