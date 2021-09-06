# update repository's
echo updating the node repository's
sudo apt-get update -qq > /dev/null

# upgrade node
echo upgrading the node
sudo apt-get upgrade -y -qq > /dev/null

# install docker dependencies
echo installing docker
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -qq > /dev/null

# Curl docker GPG key

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# setup docker repo

 echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# update repository's

sudo apt-get update -qq > /dev/null

# Install docker Engine

sudo apt-get install docker-ce docker-ce-cli containerd.io -y -qq > /dev/null

# install jq
echo installing jq
sudo apt-get install jq -y -qq > /dev/null 

# run the validator
sudo bash run.sh reset


