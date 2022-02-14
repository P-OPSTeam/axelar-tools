#! /bin/bash

sudo apt update

if  [ -z "$NETWORK" ];then
    read -p "Enter network, testnet or mainnet :" NETWORK
fi

read -p "Do you run a validator, answer yes or no: " validator

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
NETWORKPATH=".axelar_testnet"
else
echo "Setup node for axelar mainnet"
echo "Determining mainnet chain"
NETWORKPATH=".axelar"
fi

echo "Clone Axerlar Community Github"
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/ 
cd ~ 
git clone https://github.com/axelarnetwork/axelarate-community.git >/dev/null 2>&1 
cd ~/axelarate-community 
echo "done"
echo

echo "stop Axelar services"
sudo systemctl stop axelar-node
if [[ "$validator" == "yes" ]]; then
sudo systemctl stop tofnd.service
sudo systemctl stop axelard-val.service
fi

echo "Download binary files"
sudo curl -s "https://axelar-releases.s3.us-east-2.amazonaws.com/axelard/$CORE_VERSION/axelard-linux-amd64-$CORE_VERSION" -o /usr/local/bin/axelard
sudo curl -s --fail https://axelar-releases.s3.us-east-2.amazonaws.com/tofnd/$TOFND_VERSION/tofnd-linux-amd64-$TOFND_VERSION -o /usr/local/bin/tofnd
echo "done"
echo

read -p "Did axelar announce genesis file upgrade, answer yes or no: " genesis
if [[ "$genesis" == "yes" ]]; then
echo "Downloading new genesis file"
curl -s --fail https://axelar-$NETWORK.s3.us-east-2.amazonaws.com/genesis.json -o $HOME/$NETWORKPATH/config/genesis.json
    if [[ "$validator" == "yes" ]]; then
    cp $HOME/$NETWORKPATH/config/genesis.json $HOME/$NETWORKPATH/.vald/config/genesis.json
    fi
fi

echo "starting Axelar services"
sudo systemctl start axelar-node
echo "check Axelar service log"
sudo journalctl --unit=axelar-node.service | tail -n 3

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
echo "Starting Axelar tools"
sudo systemctl start tofnd.service
sudo systemctl start axelard-val.service
echo "Axelar tools started, check if your node is working correctly again"
echo "wait 10 seconds to see if vald and tofnd are working properly"
sleep 10
echo "Check vald log"
sudo journalctl --unit=axelard-val.service | tail -n 3
echo "check Tofnd log"
sudo journalctl --unit=tofnd.service | tail -n 3
fi

echo "Node upgrade executed"
