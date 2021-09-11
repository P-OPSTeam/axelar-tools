# update repository's
echo "updating ubuntu Repository's"
sudo apt-get update 2> /dev/null

# upgrade node
echo upgrading ubuntu
sudo apt-get upgrade -y 2> /dev/null

# install docker dependencies
echo installing dependencies for docker
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release 2> /dev/null

# Curl docker GPG key

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# setup docker repo

 echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# update repository's

sudo apt-get update
echo installing docker
# Install docker Engine

sudo apt-get install docker-ce docker-ce-cli containerd.io -y 2> /dev/null

# install jq

sudo apt-get install jq -y 2> /dev/null

# run the validator
sudo bash run.sh reset
echo setup is finished

