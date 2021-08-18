#! /bin/bash

if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true"
else
    reset="false"
fi 

# stop axelar core
sudo docker stop tofnd axelar-core
sudo docker rm tofnd axelar-core

# Determining Axelar versions
TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md | grep tofnd | cut -d \` -f 4)
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)

# echo ${TOFND_VERSION} ${CORE_VERSION}

# Clone Axerlar Community Github

# Remove repo for a clean git clone
sudo rm -rf ~axelarate-community/

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community

# start the validator
if [[ "$reset" =~ "false" ]]; then
    echo sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} &>> testnet.log
else
    echo sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} --reset-chain &>> testnet.log
fi
