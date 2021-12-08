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

## Let's start

Make sure you are NOT using root when running the scripts below. You must be logged in with the user created previously:

```bash
git clone https://github.com/pops-one/axelar-tools.git
cd axelar-tools && chmod u+x AxelarMenu.sh
./AxelarMenu.sh
```

In the menu you will have to use option 1) first, then exit the terminal, log in again and then use option 2.

here are the current options :

1. "install axelar requirements (docker, etc ..)" - install prereq for the axelar node

2. "Build (first time) or Rebuild (update) only" - builds or updates your node

3. "Build/Rebuild with reset chain" - build your node and reset everything

4. "Reboot host" - restart your machine

5. "Build your validator" - Build and register a validator (prereq are options 1 and 2)

6. "Enable chainmaintainers"

7. "Upgrade validator"

8. "Monitor the node via cli" - monitoring for your node and validator
