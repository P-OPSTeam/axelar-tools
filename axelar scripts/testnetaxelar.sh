# update repository's

sudo apt-get update

# upgrade node

sudo apt-get upgrade -y

# install docker dependencies

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Curl docker GPG key

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# setup docker repo

 echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# update repository's

sudo apt-get update

# Install docker Engine

sudo apt-get install docker-ce docker-ce-cli containerd.io -y

# install jq

sudo apt-get install jq -y

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

sudo sed -i 's/--name axelar-core/--name axelar-core -d/g' axelarate-community/join/joinTestnet.sh

sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --tofnd ${TOFND_VERSION} &>> testnet.log
