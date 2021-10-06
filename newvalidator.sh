echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done" >&3
echo >&3

sudo docker stop axelar-core

sudo rm ~/.axelar_testnet/shared/config.toml

sudo cp ~/axelarate-community/join/config.toml ~/.axelar_testnet/shared/

sudo sed -i '/^# Address of the bitcoin RPC server/{n;d}' ~/.axelar_testnet/shared/config.toml

sudo sed -i '/^# Address of the ethereum RPC proxy/{n;d}' ~/.axelar_testnet/shared/config.toml

echo "Type in your btc node address with double quotes!"

read btc

sudo sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = "$btc"" ~/.axelar_testnet/shared/config.toml

echo "Type in your ETH Ropsten node address with double quotes!"

read ETH

sudo sed -i "/^# Address of the ethereum RPC proxy/a rpc_addr    = "$ETH"" ~/.axelar_testnet/shared/config.toml

bash $SCRIPT/run.sh

echo "Name for your validator"

read validator

echo "amount of selfstake axltest example: 90000000axltest"

read axltest

axelarvaloper=$(sudo docker exec axelar-core axelard tendermint show-validator)

#from=$(sudo docker exec axelar-core axelard keys show validator -a)

sudo docker exec -it axelar-core axelard tx staking create-validator --yes --amount "$axltest" --moniker "$validator" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvaloper --from validator -b block

sleep 10

validator=$(sudo docker exec -it axelar-core axelard keys show validator --bech val -a)

sudo docker exec -it axelar-core axelard q staking validator "$validator" | grep tokens

sudo docker exec -it axelar-core axelard tx snapshot registerProxy broadcaster --from validator -y

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}


TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo ${TOFND_VERSION}

bash ~/axelarate-community/join/launchValidator.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION 


