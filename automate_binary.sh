#! /bin/bash

###    CONFIG    ##################################################################################################
denom=uaxl 
KEYRING_PASSWORD=""      # if left empty monitoring won't work
NETWORK=""               # Network for choosing testnet or mainnet, no caps!
###  End CONFIG    ##################################################################################################

if  [ -z $NETWORK ];then
    echo "please configure Network variable in script"
    exit 1
fi


if [ $NETWORK == testnet ]; then
    echo "Network switched to Testnet"
    NETWORKPATH=".axelar_testnet"
    else
    echo "Network switched to Mainnet"
    NETWORKPATH=".axelar"
fi

if [ -z $KEYRING_PASSWORD ]; then
    echo "Please enter the password one time below, if setting up as a service fill the field in the script"
    read -p "Enter your password for polling the keys :" KEYRING_PASSWORD
fi

echo "Cash out all rewards"
echo $KEYRING_PASSWORD | $HOME/$NETWORKPATH/bin/axelard tx distribution withdraw-all-rewards --from validator
echo "Done"

echo "Determine validator address and determine balance to stake"
validator=$(echo $KEYRING_PASSWORD | $HOME/$NETWORKPATH/bin/axelard keys show validator -a)

balance=$(echo $KEYRING_PASSWORD | $HOME/$NETWORKPATH/bin/axelard q bank balances ${validator} | grep amount | cut -d '"' -f 2 2> /dev/null)

number=$(($balance-1000000))
echo "Done"

echo "Stake the newly received funds to our own validator"
valoper=$(echo $KEYRING_PASSWORD | $HOME/$NETWORKPATH/bin/axelard keys show validator --bech val -a)

echo $KEYRING_PASSWORD | $HOME/$NETWORKPATH/bin/axelard tx staking delegate "${valoper}" ${number}uaxl --from validator -y
echo "Staked a total of ${number}uaxl to the validator"
echo "Done"


