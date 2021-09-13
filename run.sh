#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>run.log 2>&1
# Everything below will go to the file 'run.log':
echo "logs can be found in ~/axelar-tools/run.log

echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT` 
echo "done" >&3
echo >&3

if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true"
else
    reset="false"
fi 

# stop axelar core
echo Stopping axelar-core container >&3
sudo docker stop axelar-core
echo "done" >&3
echo >&3

# Determining Axelar versions
echo "Determining latest Axelar version" >&3
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo "done" >&3
echo >&3

echo ${CORE_VERSION}

echo "Clone Axerlar Community Github" >&3
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community
echo "done" >&3
echo >&3

echo "start the Axelar node" >&3

# test if the axelarate_default docker network is created
echo "--> Test network creation" >&3
docker network ls | grep axelarate_default
if [[ $? -eq 1 ]]; then
    docker network create axelarate_default
fi

echo "--> starting the node" >&3
if [[ "$reset" =~ "false" ]]; then    
    sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} &>> testnet.log
else
    sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --reset-chain  &>> testnet.log
fi

echo >&3
echo "Node is restarted" >&3
echo >&3

echo "press any key to go back to the menu" >&3
read -n 1 -s -r -p "press any key to go back to the menu" 

sudo bash $SCRIPTPATH/AxelarMenu.sh
