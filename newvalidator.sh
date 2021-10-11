denom=uaxl 

echo "Determining script path" 
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done"
echo

echo "Stopping Axelar-core container tofnd and vald"
sudo docker stop axelar-core tofnd vald

echo "Modifying config.toml for using own Ropsten and tbtc node"

# removing current config
sudo sed -i '/^# Address of the bitcoin RPC server/{n;d}' /root/.axelar_testnet/shared/config.toml
sudo sed -i '/^# Address of the ethereum RPC proxy/{n;d}' /root/.axelar_testnet/shared/config.toml

# setting up btc rpc
echo "Type in your btc node address (with double quotes):"
read btc
sudo sed -i "/^# Address of the bitcoin RPC server/a rpc_addr    = "$btc"" /root/.axelar_testnet/shared/config.toml

# setting up eth rpc
echo "Type in your ETH Ropsten node address (with double quotes):"
read ETH
sudo sed -i "/^# Address of the ethereum RPC proxy/a rpc_addr    = "$ETH"" /root/.axelar_testnet/shared/config.toml

echo "done"

echo

echo "Running the node"
bash $SCRIPTPATH/run.sh
echo "done"

echo

echo "Setting up validator config"

echo "Name for your validator :"
read validatorname

validator=$(sudo docker exec axelar-core axelard keys show validator -a)

echo "amount of selfstake axltest example: 90000000 (without ${denom})"
read uaxl

#check selfstake has been funded
sudo docker exec axelar-core axelard q bank balances ${validator} | grep amount > /dev/null 2>&1

if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(sudo docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2)
fi

while [ $(echo "${balance} < ${uaxl}" | bc -l) -eq 1 ]; do 
    echo "${validator} has ${balance} ${denom}. You need at least ${uaxl} ${denom}, press enter once funded completed"
    read waitentry
    balance=$(sudo docker exec axelar-core axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2)
done
echo "done"

echo

echo "Creating the validator with your self stake of ${uaxl} ${denom} (wait 10s for confirmation)"

axelarvalconspub=$(sudo docker exec axelar-core axelard tendermint show-validator)
#axelarvaloper=$(sudo docker exec axelar-core sh -c "axelard keys show validator -a --bech val)
sudo docker exec -it axelar-core axelard tx staking create-validator --yes --amount "${uaxl}uaxl" --moniker "$validatorname" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey $axelarvalconspub --from validator -b block

sleep 10
echo "done"

echo
echo "Starting prereq docker containers"

CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo Axelar Core version : ${CORE_VERSION}

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep tofnd | cut -d \` -f 4)
echo Axelar TOFND version ${TOFND_VERSION}

cd ~/axelarate-community

echo "Launching validator (tofnd/vald)"
sudo bash join/launchValidator.sh --axelar-core $CORE_VERSION --tofnd $TOFND_VERSION 

echo "done"

echo

echo "Registering proxy"
broadcaster=$(sudo docker exec vald sh -c "axelard keys show broadcaster -a")
#check broadcaster has some uaxl

sudo docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount > /dev/null 2>&1

if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
    balance=0
else
    balance=$(sudo docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2)
fi

while [ $(echo "${balance} <= 0" | bc -l) -eq 1 ]; do 
    echo "${broadcaster} has 0 ${denom}. Please fund it, press enter once done"
    read waitentry
    balance=$(sudo docker exec axelar-core axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2)
done

sudo docker exec -it axelar-core axelard tx snapshot register-proxy ${broadcaster} --from validator -y
echo "done"

echo
echo "validator has been setup, ask for extra uaxl from team members"

