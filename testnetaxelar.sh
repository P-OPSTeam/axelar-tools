#! /bin/bash

# update repository's
echo "Updating ubuntu Repository's"
sudo apt-get update > /dev/null 2>&1
echo "done" 
echo

# upgrade node
echo "Upgrading ubuntu"
sudo apt-get upgrade -y > /dev/null 2>&1
echo "done" 
echo

# install docker dependencies
echo "Installing dependencies for docker"
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release > /dev/null 2>&1
echo "done"
echo 

echo "Setup docker repo"
# Curl docker GPG key
if [[ ! -e "/usr/share/keyrings/docker-archive-keyring.gpg" ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1
fi

# setup docker repo
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1

# update repository's
sudo apt-get update > /dev/null 2>&1

echo "done"
echo 

echo "Installing docker"
# Install docker Engine

echo "--> Install"
sudo apt-get install docker-compose docker-ce docker-ce-cli containerd.io -y > /dev/null 2>&1

echo "--> Add current user to docker group if necessary"
id | grep docker > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
  # add user to the docker group
  sudo usermod -aG docker $USER 
  echo "Please exit the terminal, log back in and restart the installation"
  #activate changes to the group docker (linux only)
  exit
fi

echo "--> Make sure services are started"
# make sure docker services are started
sudo systemctl enable docker.service > /dev/null 2>&1
sudo systemctl enable containerd.service > /dev/null 2>&1

echo "done"
echo 

# install jq
sudo apt-get install jq -y > /dev/null 2>&1

# run the validator
bash run.sh reset
echo setup is finished

