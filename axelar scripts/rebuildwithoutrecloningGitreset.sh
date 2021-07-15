sudo docker stop $(docker ps -a -q)
sudo docker rm $(docker ps -a -q)

# Determining Axelar versions

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/TESTNET%20RELEASE.md | grep tofnd | cut -d \` -f 4)
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/TESTNET%20RELEASE.md | grep axelar-core | cut -d \` -f 4)
echo ${TOFND_VERSION} ${CORE_VERSION}

# Clone Axerlar Community Github

# Remove old Repo Remove hash following command
# sudo rm -rf ~/axelarate-community/

# git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community axelarate-community

sudo sed -i 's/--name axelar-core/--name axelar-core -d/g' axelarate-community/join/joinTestnet.sh

sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} --reset-chain &>> testnet.log
