# update repository's
echo updating ubuntu Repository's
sudo apt-get update 2> /dev/null

# upgrade node
echo upgrading ubuntu
sudo apt-get upgrade -y 2> /dev/null

# install docker dependencies
echo installing dependencies for docker
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release 2> /dev/null

sudo apt-get install -y \
	newuidmap \
	newgidmap \
	dbus-user-session 2> /dev/null 


# Curl docker GPG key

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

id -u
whoami
grep ^$(whoami): /etc/subuid
grep ^$(whoami): /etc/subgid

echo Installing rootless docker
curl -fsSL https://get.docker.com/rootless | sh

echo enabling docker to start at boot
systemctl --user enable docker
sudo loginctl enable-linger $(whoami)

# install jq

sudo apt-get install jq -y 2> /dev/null

# run the validator
sudo bash run.sh reset
echo setup is finished

