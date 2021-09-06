#! /bin/bash
if [[ $# -eq 1 && "$1" =~ "reset" ]]; then
    reset="true" else
    reset="false" fi
# Determining Axelar versions
Echo Determining Axelar version CORE_VERSION=$(curl -s 
https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md 
| grep axelar-core | cut -d \` -f 4)
# echo ${CORE_VERSION}
echo Clone Axerlar Community Github
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/ cd ~ git clone 
https://github.com/axelarnetwork/axelarate-community.git >/dev/null 2>&1 cd 
~/axelarate-community echo "start the validator" if [[ "$reset" =~ "false" ]]; 
then
    sudo ./join/join-testnet-with-binaries.sh --axelar-core ${CORE_VERSION} &>> 
testnet.log else
    sudo ./join/join-testnet-with-binaries.sh --axelar-core ${CORE_VERSION} 
--reset-chain &>> testnet.log
fi
