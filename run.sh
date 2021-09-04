#! /bin/bash

if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true"
else
    reset="false"
fi 

# stop axelar core
echo Stopping axelar-core container
sudo docker stop axelar-core 2> /dev/null

# Determining Axelar versions
echo Determining latest Axelar version
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)

# echo ${CORE_VERSION}

echo "Clone Axerlar Community Github"
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git  >/dev/null 2>&1
cd ~/axelarate-community

echo "start the Axelar node"

# test if the axelarate_default docker network is created
echo Test network creation
docker network ls | grep axelarate_default > /dev/null
if [[ $? -eq 1 ]]; then
    docker network create axelarate_default
fi

if [[ "$reset" =~ "false" ]]; then    
    sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} &>> testnet.log
else
    sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --reset-chain  &>> testnet.log
fi
