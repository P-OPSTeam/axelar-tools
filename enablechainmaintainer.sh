#! /bin/bash

echo "Start enabling chainmaintainer"
echo
echo "Notice: every chain requires an own  entry"
echo "If a wrong address is send in, your node won't come up"
echo

read -p "Enter your KEYRING PASSWORD, without it you can't enable chains : " KEYRING

read -p "Do you want to add ethereum as a chain-maintainer, answer yes or no: " ethereum
while [[ "$ethereum" != @(yes|no) ]]; do
    read wishtocreate
done

if [[ "$ethereum" == "yes" ]]; then
    # setting up eth rpc
    sed -i '/^name = "Ethereum"/{n;N;d}' ~/axelarate-community/configuration/config.toml
    read -p "Type in your ETH Ropsten node address: " eth
    sed -i "/^name = \"Ethereum\"/a rpc_addr    = \"$eth\"\nstart-with-bridge = true" ~/axelarate-community/configuration/config.toml
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
    sed -i '/^name = "Avalanche"/{n;N;d}' ~/axelarate-community/configuration/config.toml
    read -p "Type in your Avalanche node address: " avax
    sed -i "/^name = \"Avalanche\"/a rpc_addr    = \"$avax\"\nstart-with-bridge = true" ~/axelarate-community/configuration/config.toml
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
    sed -i '/^name = "Fantom"/{n;N;d}' ~/axelarate-community/configuration/config.toml
    read -p "Type in your Fantom node address: " fantom
    sed -i "/^name = \"Fantom\"/a rpc_addr    = \"$fantom\"\nstart-with-bridge = true" ~/axelarate-community/configuration/config.toml
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
    sed -i '/^name = "Moonbeam"/{n;N;d}' ~/axelarate-community/configuration/config.toml
    read -p "Type in your Moonbeam node address: " moonbeam
    sed -i "/^name = \"Moonbeam\"/a rpc_addr    = \"$moonbeam\"\nstart-with-bridge = true" ~/axelarate-community/configuration/config.toml
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
    sed -i '/^name = "Polygon"/{n;N;d}' ~/axelarate-community/configuration/config.toml
    read -p "Type in your Polygon node address: " polygon
    sed -i "/^name = \"Polygon\"/a rpc_addr    = \"$polygon\"\nstart-with-bridge = true" ~/axelarate-community/configuration/config.toml
    echo
    echo "Polygon bridge enabled"
    echo

    polygon=polygon

fi

echo "restarting vald and tofnd"
docker stop vald tofnd

cd ~/axelarate-community/

./scripts/validator-tools-docker.sh

echo "done"
echo

echo "check EVM bridge enabled"
docker logs vald --since 1h 2>&1 | grep "EVM bridge for chain"
echo

# enable chain maintainer
echo "chain maintainers startup"
if [[ "$ethereum" == "ethereum" ]]; then
echo "active"
docker exec vald -c "echo $KEYRING | axelard tx nexus register-chain-maintainer ethereum --from broadcaster --node http://axelar-core:26657 --gas auto --gas-adjustment 1.2"
else 
echo "ethereum not maintained"
fi

if [[ "$avalanche" == "avalanche" ]]; then
echo "active"
docker exec vald -c "echo $KEYRING | axelard tx nexus register-chain-maintainer avalanche --from broadcaster --node http://axelar-core:26657 --gas auto --gas-adjustment 1.2"
else 
echo "avalanche not maintained"
fi

if [[ "$fantom" == "fantom" ]]; then
echo "active"
docker exec vald -c "echo $KEYRING | axelard tx nexus register-chain-maintainer fantom --from broadcaster --node http://axelar-core:26657 --gas auto --gas-adjustment 1.2"
else 
echo "fantom not maintained"
fi

if [[ "$moonbeam" == "moonbeam" ]]; then
echo "active"
docker exec vald -c "echo $KEYRING | axelard tx nexus register-chain-maintainer moonbeam --from broadcaster --node http://axelar-core:26657 --gas auto --gas-adjustment 1.2"
else 
echo "moonbeam not maintained"
fi

if [[ "$polygon" == "polygon" ]]; then
echo "active"
docker exec vald -c "echo $KEYRING | axelard tx nexus register-chain-maintainer polygon --from broadcaster --node http://axelar-core:26657 --gas auto --gas-adjustment 1.2"
else 
echo "polygon not maintained"
fi

echo "chain maintainers enabled"
echo

sleep 5

echo
echo "Containers restarted"
echo "Run docker ps, to detemine all containers are running"