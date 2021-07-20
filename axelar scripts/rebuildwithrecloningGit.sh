sudo docker stop $(sudo docker ps -a -q)
sudo docker rm $(sudo docker ps -a -q)

# Determining Axelar versions

TOFND_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/TESTNET%20RELEASE.md | grep tofnd | cut -d \` -f 4)
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/TESTNET%20RELEASE.md | grep axelar-core | cut -d \` -f 4)
echo ${TOFND_VERSION} ${CORE_VERSION}

# Clone Axerlar Community Github

# Remove old Repo Remove hash following command
sudo rm -rf ~/axelarate-community/

cd ~

git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community

sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} &>> testnet.log
