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

if [[ "$createvalidator" == "yes" ]]; then

     # setting up btc rpc
    sed -i '/^# Address of the bitcoin RPC server/{n;N;d}' ~/.axelar_testnet/shared/config.toml
    read -p "Type in your btc node address with double quotes: " btc
    sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = "$btc"" ~/.axelar_testnet/shared/config.toml
    echo

    # setting up eth rpc
    sed -i '/^# Address of the ethereum RPC server/{n;N;d}' ~/.axelar_testnet/shared/config.toml
    read -p "Type in your ETH Ropsten node address with double quotes: " eth
    sed -i "/^# Address of the ethereum RPC server/a rpc_addr    = "$eth"" ~/.axelar_testnet/shared/config.toml
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

echo "Starting prereq docker containers"

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo Axelar Core version : ${CORE_VERSION}

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo Axelar TOFND version ${TOFND_VERSION}

cd ~/axelarate-community

echo "Launching/restarting validator (tofnd/vald)"
docker container stop tofnd vald 2> /dev/null
docker container rm tofnd vald 2> /dev/null
bash join/launch-validator.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION | tee launch-validator.log

#TBD backup broadcaster mnemonic
#TBD backup tofnd mnemonic tofnd mnemonic (~/.axelar_testnet/.tofnd/export)

echo "done"

echo

echo "Registering proxy"
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
    echo "${broadcaster} has 0 ${denom}. Please fund it, press enter once done"
    read waitentry
    balance=$(docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
done

docker exec -it axelar-core axelard tx snapshot register-proxy ${broadcaster} --from validator -y
echo "done"

echo
echo "Validator has been setup, ask for extra uaxl from team members"

