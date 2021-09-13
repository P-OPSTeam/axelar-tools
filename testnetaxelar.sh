#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>testnetaxelar.log 2>&1
# Everything below will go to the file 'testnetaxelar.log':
echo "logs can be found in ~/axelar-tools/testnetaxelar.log"

echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done" >&3
echo >&3

# update repository's
echo "Updating ubuntu Repository's" >&3
sudo apt-get update
echo "done" >&3
echo >&3

# upgrade node
echo "Upgrading ubuntu" >&3
sudo apt-get upgrade -y
echo "done" >&3
echo >&3

# install docker dependencies
echo "Installing dependencies for docker" >&3
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
echo "done" >&3
echo >&3

echo "Setup docker repo" >&3
# Curl docker GPG key
if [[ ! -e "/usr/share/keyrings/docker-archive-keyring.gpg" ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1
fi

# setup docker repo
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1

# update repository's
sudo apt-get update

echo "done" >&3
echo >&3

echo "Installing docker" >&3
# Install docker Engine

echo "--> Install" >&3
sudo apt-get install docker-compose docker-ce docker-ce-cli containerd.io -y

echo "--> Add current user to docker group if necessary" >&3
id | grep docker 
if [[ $? -eq 1 ]]; then
  # add user to the docker group
  sudo usermod -aG docker $USER 
  echo "Please exit the terminal, log back in and restart the installation" >&3
  #activate changes to the group docker (linux only)
  exit
fi

echo "--> Make sure services are started" >&3
# make sure docker services are started
sudo systemctl enable docker.service 
sudo systemctl enable containerd.service

echo "done" >&3
echo >&3

# install jq
sudo apt-get install jq -y

# run the validator
# Determining Axelar versions
echo "Determining latest Axelar version" >&3
CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)
echo "done" >&3
echo >&3

# echo ${CORE_VERSION}

echo "Clone Axerlar Community Github" >&3
# Remove repo for a clean git clone
sudo rm -rf ~/axelarate-community/

cd ~
git clone https://github.com/axelarnetwork/axelarate-community.git
cd ~/axelarate-community
echo "done" >&3
echo >&3

echo "start the Axelar node" >&3

# test if the axelarate_default docker network is created
echo "--> Test network creation" >&3
docker network ls | grep axelarate_default > /dev/null
if [[ $? -eq 1 ]]; then
    docker network create axelarate_default
fi

echo "--> starting the node" >&3
sudo join/joinTestnet.sh --axelar-core ${CORE_VERSION} --reset-chain  &>> testnet.log
echo "done" >&3
echo >&3

echo >&3
echo "setup is finished" >&3

echo "press any key to go back to the menu" >&3
read -n 1 -s -r -p "press any key to go back to the menu" 

sudo bash $SCRIPTPATH/AxelarMenu.sh
