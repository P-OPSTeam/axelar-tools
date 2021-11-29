#! /bin/bash

denom=uaxl 

echo "Determining script path" 
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done"
echo

catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))

while [[ $catchingup == "true" ]]; do
    echo "Your node is NOT fully synced yet"
    echo "we'll wait 30s and retry"
    echo
    sleep 30
    catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))
done

read -p "Do you need to create your validator, answer yes or no: " createvalidator
while [[ "$createvalidator" != @(yes|no) ]]; do
    read wishtocreate
done

echo "Starting prereq docker containers"

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo Axelar Core version : ${CORE_VERSION}

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo Axelar TOFND version ${TOFND_VERSION}

cd ~/axelarate-community

echo "Launching/restarting validator (tofnd/vald)"
docker container stop tofnd vald 2> /dev/null
docker container rm tofnd vald 2> /dev/null
bash join/launch-validator-tools.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION | tee launch-validator.log

#TBD backup broadcaster mnemonic
#TBD backup tofnd mnemonic tofnd mnemonic (~/.axelar_testnet/.tofnd/export)

echo "done"

echo

echo "Registering proxy"
echo
broadcaster=$(docker exec vald sh -c "axelard keys show broadcaster -a")
#check broadcaster has some uaxl

docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount 2> /dev/null

if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
fi

while [ $(echo "${balance} <= 0" | bc -l) -eq 1 ]; do 
    echo "${broadcaster} has 0 ${denom}. Please fund it with at least 5000000uxl, press enter once done"
    read waitentry
    balance=$(docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
done

validator=$(docker exec axelar-core sh -c "axelard keys show validator -a")
#check validator has some uaxl

docker exec axelar-core axelard q bank balances ${validator} | grep amount 2> /dev/null

if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
fi

while [ $(echo "${balance} <= 0" | bc -l) -eq 1 ]; do 
    echo "${broadcaster} has 0 ${denom}. Please use faucet to fund it, press enter once done"
    read waitentry
    balance=$(docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
done

docker exec -it axelar-core axelard tx snapshot register-proxy ${broadcaster} --from validator -y
echo "done"

if [[ "$createvalidator" == "yes" ]]; then

     # setting up btc rpc
    sed -i '/^# Address of the bitcoin RPC server/{n;N;d}' ~/axelarate-community/join/config.toml
    read -p "Type in your btc node address with double quotes: " btc
    sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = $btc" ~/axelarate-community/join/config.toml
    echo

    # setting up eth rpc
    sed -i '/^# Address of the ethereum RPC server/{n;N;d}' ~/axelarate-community/join/config.toml
    read -p "Type in your ETH Ropsten node address with double quotes: " eth
    sed -i "/^# Address of the ethereum RPC server/a rpc_addr    = $eth" ~/axelarate-community/join/config.toml
    echo

    # enabling start with eth bridge
    sed -i 's/start-with-bridge = false/start-with-bridge = true/g' ~/axelarate-community/join/config.toml
    echo "eth bridge enabled"
    echo

    # setting up Avalanche bridge
    Avalanche=$"name = \"Avalanche\""
    sed -i "/start-with-bridge = true/a[[axelar_bridge_evm]]\n\n# Chain name Avalanche\nname = "Avalanche"\n\n# Address of the avalanche RPC server\nrpc_addr    = \n\n# chain maintainers should set start-with-bridge to true\nstart-with-bridge = true" ~/axelarate-community/join/config.toml
    sed -i '/^# Chain name Avalanche/{n;d}' ~/axelarate-community/join/config.toml
    sed -i "/^# Chain name Avalanche/a $Avalanche" ~/axelarate-community/join/config.toml
    sed -i '/^# Address of the avalanche RPC server/{n;d}' ~/axelarate-community/join/config.toml
    read -p "Type in your Avalanche testnet node address with double quotes: " avax
    sed -i "/^# Address of the avalanche RPC server/a rpc_addr    = $avax" ~/axelarate-community/join/config.toml
    echo

    cp ~/axelarate-community/join/config.toml ~/.axelar_testnet/shared/config.toml

    docker restart axelar-core tofnd vald

    # enable chain maintainer ETH
    echo "ETH chain maintainer startup"
    docker exec vald axelard tx nexus register-chain-maintainer ethereum avalanche --from broadcaster --node http://axelar-core:26657
    echo "ETH chain maintainer enabled"
    echo

    echo "Setting up validator config"

    read -p "Name for your validator : " validatorname

    validator=$(docker exec axelar-core axelard keys show validator -a)

    read -p "Amount of selfstake axltest example: 90000000 (without ${denom}) : " uaxl

    #check selfstake has been funded
    docker exec axelar-core axelard q bank balances ${validator} | grep amount > /dev/null 2>&1

    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    else
        balance=$(docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2 2> /dev/null)
    fi

    while [ $(echo "${balance} < ${uaxl}" | bc -l) -eq 1 ]; do 
        echo "${validator} has ${balance} ${denom}. You need at least ${uaxl} ${denom}, press enter once you funded it"
        read waitentry
        balance=$(docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2 2> /dev/null)
        if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
            balance=0
        fi
    done
    echo "done"
    echo

    echo "Creating the validator with your selfstake of ${uaxl} ${denom} (wait 10s for confirmation)"

    axelarvalconspub=$(docker exec axelar-core axelard tendermint show-validator)
    #axelarvaloper=$(docker exec axelar-core sh -c "axelard keys show validator -a --bech val)
    docker exec -it axelar-core axelard tx staking create-validator --yes --amount "${uaxl}${denom}" --moniker "$validatorname" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvalconspub --from validator -b block

    sleep 10
    echo "done"
    echo
fi

echo
echo "checking health off the validator" 
docker exec -ti vald axelard health-check --tofnd-host tofnd --operator-addr $(cat ~/.axelar_testnet/shared/validator.bech) --node http://axelar-core:26657

echo "Validator has been setup, ask for extra uaxl from team members"

echo "backup mnemonic broadcaster"
cp ~/axelarate-community/launch-validator.log ~/axelar_backup/broadcaster-mnemonic.txt
echo "Backup completed, check ~/axelar_backup/"
