read -p "Do you need to create your validator, answer yes or no: " createvalidator
while [[ "$createvalidator" != @(yes|no) ]]; do
    read wishtocreate
done

if [[ "$createvalidator" == "yes" ]]; then

echo "Checking if node is on latest block"
catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))

while [[ $catchingup == "true" ]]; do
    echo "Your node is NOT fully synced yet"
    echo "we'll wait 30s and retry"
    echo "check blockheigt on explorer and on node, if it differs to much ctrl-c and wait patiently"
    echo "check blockheight on node with curl -s "http://localhost:26657/status""
    echo
    sleep 30
    catchingup=$(jq -r '.result.sync_info.catching_up' <<<$(curl -s "http://localhost:26657/status"))
done
echo "Node is on latest block"
echo

if [ -z $MONIKER ]; then
    echo "Please enter Moniker name below"
    read -p "Enter Moniker name :" MONIKER
fi

if  [ -z "$NETWORK" ];then
    read -p "Enter network, testnet or mainnet :" NETWORK
fi

read -p "Enter your KEYRING PASSWORD : " KEYRING

denom=uaxl

# Determining Axelar versions
echo "Determining Axelar version"
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep axelar-core | cut -d \` -f 4)
echo ${CORE_VERSION}

echo "Determining Tofnd version"
TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/webdocs/main/docs/releases/$NETWORK.md | grep tofnd | cut -d \` -f 4)
echo ${TOFND_VERSION}
echo

if [ "$NETWORK" == testnet ]; then
echo "Setup node for axelar testnet"
echo "Determining testnet chain"
CHAIN_ID=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/scripts/node.sh | grep chain_id=axelar-t | cut -f2 -d "=")
NETWORKPATH=".axelar_testnet"
else
echo "Setup node for axelar mainnet"
echo "Determining mainnet chain"
CHAIN_ID=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/scripts/node.sh | grep chain_id=axelar-d | cut -f2 -d "=")
NETWORKPATH=".axelar"
fi

echo "Setup validator tools"
echo
echo "-->setup TOFND service"
sudo bash -c "cat > /etc/systemd/system/tofnd.service << EOF
[Unit]
Description=tofnd
After=network-online.target

[Service]
User=$USER
ExecStart=/bin/sh -c 'echo $KEYRING | tofnd -m existing -d $HOME/$NETWORKPATH/.tofnd'
Restart=always
RestartSec=3
LimitNOFILE=16384
MemoryMax=4G
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF"
echo
echo "--> enable and start tofnd service"
sudo systemctl enable tofnd.service 
sudo systemctl start tofnd.service
echo "--> setup vald service"
(cat $HOME/broadcaster.txt | tail -1 ; echo $KEYRING ; echo $KEYRING) | axelard keys add broadcaster --recover --home $HOME/$NETWORKPATH/.vald
cp $HOME/$NETWORKPATH/.core/config/config.toml $HOME/$NETWORKPATH/.vald/config/config.toml
cp $HOME/$NETWORKPATH/.core/config/app.toml $HOME/$NETWORKPATH/.vald/config/app.toml
cp $HOME/$NETWORKPATH/.core/config/genesis.json $HOME/$NETWORKPATH/.vald/config/genesis.json
valoper=$(echo $KEYRING | axelard keys show validator --home $HOME/$NETWORKPATH/.core --bech val -a)

sudo bash -c "cat > /etc/systemd/system/axelard-val.service << EOF
[Unit]
Description=axelard-val
After=network-online.target

[Service]
User=$USER
ExecStart=/bin/sh -c 'echo $KEYRING | axelard vald-start --tofnd-host localhost --node http://localhost:26657 --home $HOME/$NETWORKPATH/.vald --validator-addr $valoper --log_level debug --chain-id $CHAIN_ID --from broadcaster'
Restart=always
RestartSec=3
LimitNOFILE=16384
MemoryMax=4G
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF"
echo
echo "--> enable and start vald services"

sudo systemctl enable axelard-val.service
sudo systemctl start axelard-val.service
echo "done"
echo
echo "Register proxy for validator"
echo $KEYRING | axelard tx snapshot register-proxy $broadcaster --from validator --home $HOME/$NETWORKPATH/.core -y --chain-id $CHAIN_ID

echo "creating a validator"
balance=$(echo $KEYRING | axelard q bank balances $validator | grep amount | cut -d '"' -f 2)
echo "Current validator balance is: $balance"
echo "Leave some balance to pay for fees"
read -p "Amount of selfstake axltest example: 1000000 (without ${denom}) : " uaxl
read -p "Enter validator details : " details
axelarvalconspub=$(echo $KEYRING | axelard tendermint show-validator --home $HOME/$NETWORKPATH/.core)
echo $KEYRING | axelard tx staking create-validator --yes --amount "${uaxl}${denom}" --moniker "$MONIKER" --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01" --min-self-delegation="1" --pubkey=$axelarvalconspub --home $HOME/$NETWORKPATH/.core --chain-id $CHAIN_ID --details "$details" --from validator -b block
echo "done"
echo

echo "Adding chainmaintainers"
echo
echo "Notice: every chain requires an own  entry"
echo "If a wrong address is send in, your node won't come up"
echo
read -p "Do you want to add ethereum as a chain-maintainer, answer yes or no: " ethereum
while [[ "$ethereum" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$ethereum" == "yes" ]]; then
        # setting up eth rpc
        sed -i '/^name = "Ethereum"/{n;N;d}' $HOME/$NETWORKPATH/.core/config/config.toml
        read -p "Type in your ETH Ropsten node address: " eth
        sed -i "/^name = \"Ethereum\"/a rpc_addr    = \"$eth\"\nstart-with-bridge = true" $HOME/$NETWORKPATH/.core/config/config.toml
        echo
        echo "eth bridge enabled"
        echo

        ethereum=ethereum

    fi

read -p "Do you want to add Avalanche as a chain-maintainer, answer yes or no: " avalanche
while [[ "$avalanche" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$avalanche" == "yes" ]]; then

        # setting up Avalanche rpc
        sed -i '/^name = "Avalanche"/{n;N;d}' $HOME/$NETWORKPATH/.core/config/config.toml
        read -p "Type in your Avalanche node address: " avax
        sed -i "/^name = \"Avalanche\"/a rpc_addr    = \"$avax\"\nstart-with-bridge = true" $HOME/$NETWORKPATH/.core/config/config.toml
        echo
        echo "Avalanche bridge enabled"
        echo

        avalanche=avalanche

    fi

read -p "Do you want to add Fantom as a chain-maintainer, answer yes or no: " fantom
while [[ "$fantom" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$fantom" == "yes" ]]; then

        # setting up Fantom rpc
        sed -i '/^name = "Fantom"/{n;N;d}' $HOME/$NETWORKPATH/.core/config/config.toml
        read -p "Type in your Fantom node address: " fantom
        sed -i "/^name = \"Fantom\"/a rpc_addr    = \"$fantom\"\nstart-with-bridge = true" $HOME/$NETWORKPATH/.core/config/config.toml
        echo
        echo "Fantom bridge enabled"
        echo

        fantom=fantom

    fi

read -p "Do you want to add Moonbeam as a chain-maintainer, answer yes or no: " moonbeam
while [[ "$moonbeam" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$moonbeam" == "yes" ]]; then

        # setting up Moonbeam rpc
        sed -i '/^name = "Moonbeam"/{n;N;d}' $HOME/$NETWORKPATH/.core/config/config.toml
        read -p "Type in your Moonbeam node address: " moonbeam
        sed -i "/^name = \"Moonbeam\"/a rpc_addr    = \"$moonbeam\"\nstart-with-bridge = true" $HOME/$NETWORKPATH/.core/config/config.toml
        echo
        echo "Moonbeam bridge enabled"
        echo

        moonbeam=moonbeam

    fi

read -p "Do you want to add Polygon as a chain-maintainer, answer yes or no: " polygon
while [[ "$polygon" != @(yes|no) ]]; do
    read wishtocreate
done

    if [[ "$polygon" == "yes" ]]; then

        # setting up Polygon rpc
        sed -i '/^name = "Polygon"/{n;N;d}' $HOME/$NETWORKPATH/.core/config/config.toml
        read -p "Type in your Polygon node address: " polygon
        sed -i "/^name = \"Polygon\"/a rpc_addr    = \"$polygon\"\nstart-with-bridge = true" $HOME/$NETWORKPATH/.core/config/config.toml
        echo
        echo "Polygon bridge enabled"
        echo

        polygon=polygon

    fi

echo "copy config to vald dir"
cp $HOME/$NETWORKPATH/.core/config/config.toml $HOME/$NETWORKPATH/.vald/config/config.toml

echo "restarting vald and tofnd"
sudo systemctl restart axelard-val.service
sudo systemctl restart tofnd.service

echo "chain maintainers startup"
    if [[ "$ethereum" == "ethereum" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer ethereum --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "ethereum not maintained"
    fi

    if [[ "$avalanche" == "avalanche" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer avalanche --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "avalanche not maintained"
    fi

    if [[ "$fantom" == "fantom" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer fantom --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "fantom not maintained"
    fi

    if [[ "$moonbeam" == "moonbeam" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer moonbeam --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "moonbeam not maintained"
    fi

    if [[ "$polygon" == "polygon" ]]; then
    echo "active"
    echo $KEYRING | axelard tx nexus register-chain-maintainer polygon --from broadcaster --node http://localhost:26657 --gas auto --gas-adjustment 1.2 --chain-id $CHAIN_ID --home $HOME/$NETWORKPATH/.vald
    else 
    echo "polygon not maintained"
    fi

echo "chain maintainers enabled"
echo "Validator completely enabled"
echo "please check explorer or do health check to determine host status"
echo "done"
else
echo "Default node setup completed"
echo "done"
exit 1
fi