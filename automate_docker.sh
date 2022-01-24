#! /bin/bash

denom=uaxl 

docker exec axelar-core sh -c "echo access2all | axelard tx distribution withdraw-all-rewards --from validator"

validator=$(docker exec axelar-core sh -c "echo access2all | axelard keys show validator -a")

balance=$(docker exec axelar-core sh -c "echo access2all | axelard q bank balances ${validator}" | grep amount | cut -d '"' -f 2 2> /dev/null)

number=$(($balance-1000000))

valoper=$(docker exec axelar-core sh -c "echo access2all | axelard keys show validator --bech val -a")

docker exec axelar-core sh -c "echo access2all | axelard tx staking delegate "${valoper}" ${number}uaxl --from validator -y"


