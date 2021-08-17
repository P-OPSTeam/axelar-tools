sudo docker stop axelar-core tofnd
sudo docker rm axelar-core tofnd

# Determining Axelar versions

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md | grep tofnd | cut -d \` -f 4)
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo ${TOFND_VERSION} ${CORE_VERSION}

# Clone Axerlar Community Github

# Remove old Repo Remove hash following command
# sudo rm -rf ~/axelarate-community/

# git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community

sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} --reset-chain &>> testnet.log
