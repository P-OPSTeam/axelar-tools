#! /bin/bash

sudo apt install tmux -y -qq > /dev/null

if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true"
else
    reset="false"
fi 

#kill tmux session
tmux kill-session -t remote

# stop axelar core
sudo docker stop tofnd axelar-core 2> /dev/null
sudo docker rm tofnd axelar-core 2> /dev/null

# Determining Axelar versions
TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md | grep tofnd | cut -d \` -f 4)
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)

# echo ${TOFND_VERSION} ${CORE_VERSION}


echo "Clone Axerlar Community Github"
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git  >/dev/null 2>&1
cd ~/axelarate-community

echo "start the validator"

# test if the axelarate_default docker network is created
docker network ls | grep axelarate_default > /dev/null
if [[ $? -eq 1 ]]; then
    docker network create axelarate_default
fi

tmux new -s "remote" -d 2> /dev/null
if [[ "$reset" =~ "false" ]]; then    
    tmux send-keys -t "remote" "sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} &>> testnet.log" C-m 
else
    tmux send-keys -t "remote" "sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --reset-chain  &>> testnet.log" C-m
fi
