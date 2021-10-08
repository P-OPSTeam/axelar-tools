echo "Determining script path" 
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done"
echo

sudo docker stop axelar-core

echo "Modifying config.toml for using own Ropsten and tbtc node"

sudo sed -i '/^# Address of the bitcoin RPC server/{n;d}' /root/axelar_testnet/shared/config.toml

sudo sed -i '/^# Address of the ethereum RPC proxy/{n;d}' /root/.axelar_testnet/shared/config.toml

echo "Type in your btc node address with double quotes!"

read btc

sudo sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = "$btc"" /root/.axelar_testnet/shared/config.toml

echo "Type in your ETH Ropsten node address with double quotes!"

read ETH

sudo sed -i "/^# Address of the ethereum RPC proxy/a rpc_addr    = "$ETH"" /root/.axelar_testnet/shared/config.toml

echo "done"

echo

bash $SCRIPT/run.sh


echo "Setting up validator config"

echo "Name for your validator"

read validator

echo "amount of selfstake axltest example: 90000000uaxl"

read uaxl

axelarvaloper=$(sudo docker exec axelar-core axelard tendermint show-validator)

#from=$(sudo docker exec axelar-core axelard keys show validator -a)

echo "done"

echo

echo "Starting the validator"

sudo docker exec -it axelar-core axelard tx staking create-validator --yes --amount "$uaxl" --moniker "$validator" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvaloper --from validator -b block

sleep 10

validator=$(sudo docker exec -it axelar-core axelard keys show validator --bech val -a)

sudo docker exec -it axelar-core axelard q staking validator "$validator" | grep tokens

sudo docker exec -it axelar-core axelard tx snapshot registerProxy broadcaster --from validator -y

echo "done"

echo

echo "Starting prereq docker containers"

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}


TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo ${TOFND_VERSION}

cd ~/axelarate-community

bash join/launchValidator.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION 

echo "done"

echo

echo "validator is setup, ask for extra uaxl from team members"
