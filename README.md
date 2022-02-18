# axelar-tools

## Description

Repo for axelar.network

These are scripts for automating the installation of the axelar-core.

## Prerequisite

Logged in as root, create a new user, add it to sudo group and to the sudoers file using the commands below. 
In this example we are using "pops" as user:

```bash
USER=pops
useradd -s /bin/bash -d /home/${USER}/ -m -G sudo ${USER}
echo "${USER}     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

then set a password for the user

```bash
passwd $USER
```

Make also sure u set the ulimit -n 16384 permanent.

## Let's start

Make sure you are NOT using root when running the scripts below. You must be logged in with the user created previously:

```bash
git clone https://github.com/pops-one/axelar-tools.git
cd axelar-tools && chmod u+x AxelarMenu.sh
./AxelarMenu.sh
```

here are the current options :

1. "Install Binary by using wrapper" - Install using wrapper, no auto start at boot

2. "Install Binary by systemd" - Installing node/validator via systemd

3. "Upgrade Binary by using warpper" - Update node/validator wrapper

4. "Upgrade Binary by systemd" -- Upgrading node/validator systemd

5. "reboot node" - reboot node, node will auto start with systemd

6. "Monitor the node via cli" - monitoring for your node and validator