#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>upgradevalidator.log.log 2>&1
# Everything below will go to the file 'upgradevalidator.log':
echo "logs can be found in upgradevalidator.log" >&3

echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT` 
echo "done" >&3
echo >&3

# stop validator containers
echo Stopping axelar-core, vald and tofnd container >&3
docker stop axelar-core vald tofnd
echo "done" >&3
echo >&3

# Backup .axelar_testnet folder
echo "Backup the .axelar_testnet folder"
cp -r ~/.axelar_testnet ~/.axelar_testnet_backup
echo "Copy created, you can find it at ~/.axelar_testnet_backup"
echo

# Determining Axelar versions
echo "Determining latest Axelar version" >&3
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/resources/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo "Current Axelar Core version is $CORE_VERSION" >&3
echo >&3

# Determining Axelar versions
echo "Determining latest Axelar version" >&3
TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/resources/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo "Current Axelar Core version is $TOFND_VERSION" >&3
echo >&3

exec 2>&4 1>&3

# starting Axelar-core
echo "Starting axelar core container"
cd ~/axelarate-community/
./join/join-testnet.sh --axelar-core $CORE_VERSION
echo "done"
echo 

# starting validator-tools
echo "starting vald and tofnd"
cd ~/axelarate-community/
./join/launch-validator-tools.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION
echo "done"
echo

# restoring old config file
echo "restoring old config file regarding chainmaintainers"
cp -r ~/.axelar_testnet_backup/shared/config.toml ~/.axelar_testnet/shared/config.toml
echo "done"
echo

# restarting container for using the restored config file
echo "restarting containers for using the restored config.toml"
docker restart axelar-core vald tofnd
echo "done"
echo "please run docker ps to check if containers are running"
