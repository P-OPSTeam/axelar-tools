#! /bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>testnetaxelar.log 2>&1
# Everything below will go to the file 'testnetaxelar.log':
echo "logs can be found in testnetaxelar.log"

echo "Determining script path" >&3
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`
echo "done" >&3
echo >&3

# check user logged in
echo "Checking logged in user" >&3
if [[ $EUID -eq 0 ]]; 
    then
    echo "Do not run this as the root user, create a new user via the command adduser" >&3
    exit 1;
fi

# update repository's
echo "Updating ubuntu repository's" >&3
sudo apt-get update
echo "done" >&3
echo >&3

# upgrade node
echo "Upgrading ubuntu" >&3
sudo apt-get upgrade -y
echo "done" >&3
echo >&3

###    packages required: jq, bc, iptables
REQUIRED_PKG="bc"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="iptables"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="dbus-user-session"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

# install docker dependencies
echo "Installing dependencies for docker" >&3
sudo apt install uidmap
echo "done" >&3
echo >&3

# update repository's
sudo apt-get update

echo "done" >&3
echo >&3

echo "Installing docker" >&3
# Install docker Engine

echo "--> Install" >&3
curl -fsSL https://get.docker.com/rootless | sh

echo "--> Make sure services are started" >&3
# make sure docker services are started
systemctl --user start docker
systemctl --user enable docker
sudo loginctl enable-linger $(whoami)

echo "--> Setting path values" >&3
# Setting path values for doocker
export PATH="/home/$(whoami)/bin:$PATH"
echo $PATH >&3
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
echo $DOCKER_HOST >&3
sed -i -e '$aexport DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' ~/.profile
echo "Added Docker host path to .profile"
chmod 666 $XDG_RUNTIME_DIR/docker.sock
echo "done" >&3
echo >&3

exec 2>&4 1>&3
 
echo
echo "Prereq done, please  logout of your terminal then rerun AxelarMenu.sh now with option 2"
echo
