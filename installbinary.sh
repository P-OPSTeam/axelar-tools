#! /bin/bash

# update repository's
echo updating the node repository's
sudo apt-get update -qq > /dev/null

# upgrade node
echo upgrading the node
sudo apt-get upgrade -y -qq > /dev/null

# install jq
echo installing jq
sudo apt-get install jq -y -qq > /dev/null 

# run the validator
echo Starting the validator
sudo bash runbin.sh reset
