sudo docker stop axelar-core

sudo rm ~/.axelar_testnet/shared/config.toml

sudo cp ~/axelarate-community/join/config.toml ~/.axelar_testnet/shared/

sudo sed -i '/^# Address of the bitcoin RPC server/{n;d}' ~/.axelar_testnet/shared/config.toml

sudo sed -i '/^# Address of the ethereum RPC proxy/{n;d}' ~/.axelar_testnet/shared/config.toml

echo Type in your btc node address with double quotes!

read btc

sudo sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = "$btc"" ~/.axelar_testnet/shared/config.toml

echo Type in your ETH Ropsten node address with double quotes!

read ETH

sudo sed -i "/^# Address of the ethereum RPC proxy/a rpc_addr    = "$ETH"" ~/.axelar_testnet/shared/config.toml

sudo docker start tofnd

sudo docker start axelar-core

echo Name for your validator

read validator

echo amount of selfstake axltest example: 90000000axltest

read axltest

axelarvaloper=$(sudo docker exec axelar-core axelard tendermint show-validator)

#from=$(sudo docker exec axelar-core axelard keys show validator -a)

sudo docker exec -it axelar-core axelard tx staking create-validator --yes --amount "$axltest" --moniker "$validator" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvaloper --from validator -b block

sleep 10

validator=$(sudo docker exec -it axelar-core axelard keys show validator --bech val -a)

sudo docker exec -it axelar-core axelard q staking validator "$validator" | grep tokens

sudo docker exec -it axelar-core axelard tx snapshot registerProxy broadcaster --from validator -y

sudo docker exec axelar-core ps

echo If there is no vald-start, please run following command sudo docker exec axelar-core axelard vald-start --tofnd-host 172.17.0.2 --validator-addr $validator
 
