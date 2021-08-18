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

# run the validator
sudo bash run.sh reset


