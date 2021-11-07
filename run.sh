#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>run.log 2>&1
# Everything below will go to the file 'run.log':
echo "logs can be found in run.log"

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
docker stop axelar-core
docker rm axelar-core
echo "done" >&3
echo >&3

# Determining Axelar versions
echo "Determining latest Axelar version" >&3
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo "done" >&3
echo >&3

echo ${CORE_VERSION}

# Get the axelarate-community tag
echo "Get axelarate-community tag" >&3
AXEL_TAG=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelarate-community | cut -d \` -f 4)
echo "done" >&3
echo >&3

echo "Clone/Refresh Axerlar Community Github" >&3
rm -rf ~/axelarate-community/
cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community
git checkout $AXEL_TAG
echo "done" >&3
echo >&3

echo "Start the Axelar node" >&3

# test if the axelarate_default docker network is created
echo "--> Test network creation" >&3
docker network ls | grep axelarate_default
if [[ $? -eq 1 ]]; then
    docker network create axelarate_default
fi

exec 2>&4 1>&3

public_ip=$(curl -s ifconfig.me)
echo "See your public IP: $public_ip, this will be used to update config.toml" >&3

read -p "Press enter to continue, or type ENTERIP to reenter a new one: " reenterip

if [ ! -z $reenterip ] && [ $reenterip == "ENTERIP" ]; then
    read -p "Enter your public ip : " public_ip
    test='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
    while [[ !($public_ip =~ ^$test\.$test\.$test\.$test$) ]]; do
        read -p "invalid ip, pleeas re-enter : " public_ip 
    done
fi
echo "Final public ip used is $public_ip"

sed -i "s/external_address = \"\"/external_address = \"$public_ip:26656\"/" ~/axelarate-community/join/config.toml

# setting up btc rpc
read -p "Type in your btc node address: " btc
btc="$(<<< "$btc" sed -e 's`[][\\/.*^$]`\\&`g')" #escaping sed special characters
sed -i "s/<your-bitcoin-rpc-and-port>/$btc/" ~/axelarate-community/join/config.toml
echo 

# setting up eth rpc
read -p "Type in your ETH Ropsten node address: " eth
eth="$(<<< "$eth" sed -e 's`[][\\/.*^$]`\\&`g')" #escaping sed special characters
sed -i "s/<your-ethereum-rpc>/$eth/" ~/axelarate-community/join/config.toml
echo

echo "Note that if the eth/btc endpoint is not setup correctly, your container may not start."

echo

if [[ "$reset" =~ "false" ]]; then
    echo "--> Starting the node"
    join/join-testnet.sh --axelar-core ${CORE_VERSION} &>> testnet.log
else
    echo "--> Starting the node with reset"
    echo "WARNING! This will erase all previously stored data. Your node will catch up from the beginning"
    echo "Do you wish to proceed \"y/n\" ? "
    join/join-testnet.sh --axelar-core ${CORE_VERSION} --reset-chain  &>> testnet.log
fi

sed -n '10,32p' testnet.log

echo 
echo "Node is restarted"
echo

echo "Backing up your keys in ~/axelar_backup"
sudo chown -R $USER:$USER ~/.axelar_testnet
mkdir -p ~/axelar_backup
cp ~/.axelar_testnet/.core/config/priv_validator_key.json ~/axelar_backup/
if [[ ! "$reset" =~ "false" ]]; then
    cp testnet.log ~/axelar_backup/mnemonic.txt 
fi

echo "Backup completed, check ~/axelar_backup/"
