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

cd ~/axelarate-community

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet-releases.md | grep axelar-core | cut -d \` -f 4)
echo Axelar Core version : ${CORE_VERSION}

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo Axelar TOFND version ${TOFND_VERSION}

echo "Launching/restarting validator (tofnd/vald)"
docker container stop tofnd vald 2> /dev/null
docker container rm tofnd vald 2> /dev/null
echo

read -p "Enter your KEYRING PASSWORD, without it docker won't start : " KEYRING
echo
read -p "Enter your TOFND PASSWORD, without it docker won't start : " TOFND
echo

KEYRING_PASSWORD=$KEYRING TOFND_PASSWORD=$TOFND scripts/validator-tools-docker.sh --axelar-core-version $CORE_VERSION --tofnd-version $TOFND_VERSION | tee launch-validator.log

#TBD backup broadcaster mnemonic
#TBD backup tofnd mnemonic tofnd mnemonic (~/.axelar_testnet/.tofnd/export)

echo "done"

echo

echo "Registering proxy"
echo
broadcaster=$(docker exec vald sh -c "echo $KEYRING | axelard keys show broadcaster -a")
#check broadcaster has some uaxl

docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${broadcaster} | grep amount" 2> /dev/null

if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${broadcaster}" | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
fi

while [ $(echo "${balance} <= 0" | bc -l) -eq 1 ]; do 
    echo "${broadcaster} has 0 ${denom}. Please fund it with at least 100000000uxl, that's 2x faucet request, press enter once done"
    read waitentry
    balance=$(docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${broadcaster}" | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
done

validator=$(docker exec axelar-core sh -c "echo $KEYRING | axelard keys show validator -a")
#check validator has some uaxl

docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${validator} " | grep amount 2> /dev/null

if [ $balance -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(docker exec axelar-cor sh -c "echo $KEYRING | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
fi

while [ $(echo "${balance} <= 0" | bc -l) -eq 1 ]; do 
    echo "${broadcaster} has 0 ${denom}. Please use faucet to fund it, press enter once done"
    read waitentry
    balance=$(docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)
    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    fi
done

docker exec -it axelar-core sh -c "echo $KEYRING | axelard tx snapshot register-proxy ${broadcaster} --from validator -y"
echo "done"

if [[ "$createvalidator" == "yes" ]]; then

    echo "Setting up validator config"

    read -p "Name for your validator : " validatorname

    validator=$(docker exec axelar-core sh -c "echo $KEYRING | axelard keys show validator -a")

    read -p "Amount of selfstake axltest example: 90000000 (without ${denom}) : " uaxl

    #check selfstake has been funded
    docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${validator}" | grep amount > /dev/null 2>&1

    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        balance=0
    else
        balance=$(docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)
    fi

    while [ $(echo "${balance} < ${uaxl}" | bc -l) -eq 1 ]; do 
        echo "${validator} has ${balance} ${denom}. You need at least ${uaxl} ${denom}, press enter once you funded it"
        read waitentry
        balance=$(docker exec axelar-core sh -c "echo $KEYRING | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)
        if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
            balance=0
        fi
    done
    echo "done"
    echo

    echo "Creating the validator with your selfstake of ${uaxl} ${denom} (wait 10s for confirmation)"

    axelarvalconspub=$(docker exec axelar-core sh -c "echo $KEYRING | axelard tendermint show-validator")
    #axelarvaloper=$(docker exec axelar-core sh -c "echo $KEYRING | "axelard keys show validator -a --bech val)
    docker exec -it axelar-core sh -c "echo $KEYRING | axelard tx staking create-validator --yes --amount "${uaxl}${denom}" --moniker "$validatorname" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvalconspub --from validator -b block"

    sleep 10
    echo "done"
    echo
fi

echo
echo "checking health off the validator" 
docker exec -ti vald sh -c "echo $TOFND | axelard health-check --tofnd-host tofnd --operator-addr $(cat ~/.axelar_testnet/shared/validator.bech) --node http://axelar-core:26657"

echo "Validator has been setup, ask for extra uaxl from team members"

echo "backup mnemonic broadcaster"
cp ~/axelarate-community/launch-validator.log ~/axelar_backup/broadcaster-mnemonic.txt
echo "Backup completed, check ~/axelar_backup/"
echo
echo "If you want to be a chain-maintainer run option 6"
