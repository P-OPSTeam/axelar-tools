#! /bin/bash

###    CONFIG    ##################################################################################################
denom=uaxl 
KEYRING_PASSWORD=""      # if left empty monitoring won't work
###  End CONFIG    ##################################################################################################

if [ -z $KEYRING_PASSWORD ]; then
    echo "Please enter the password one time below, if setting up as a service fill the field in the script"
    read -p "Enter your password for polling the keys :" KEYRING_PASSWORD
fi

docker exec axelar-core sh -c "echo $KEYRING_PASSWORD | axelard tx distribution withdraw-all-rewards --from validator"

validator=$(docker exec axelar-core sh -c "echo $KEYRING_PASSWORD | axelard keys show validator -a")

balance=$(docker exec axelar-core sh -c "echo $KEYRING_PASSWORD | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)

number=$(($balance-1000000))

valoper=$(docker exec axelar-core sh -c "echo $KEYRING_PASSWORD | axelard keys show validator --bech val -a")

docker exec axelar-core sh -c "echo $KEYRING_PASSWORD | axelard tx staking delegate "${valoper}" ${number}uaxl --from validator -y"


