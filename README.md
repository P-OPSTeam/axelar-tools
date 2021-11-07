# axelar-tools

## Description

Repo for axelar.network

These are scripts for automating the installation of the axelar-core.

## Prerequisite

Make sure you are not using root when running the scripts.

## Let's start

```bash
git clone https://github.com/pops-one/axelar-tools.git
cd axelar-tools && chmod u+x AxelarMenu.sh
./AxelarMenu.sh
```

in the menu you will have to use option 1) first then exit the terminal, and after relogin use option 2.

here are the current options :

1. "install axelar requirements (docker, etc ..)" - install prereq for the axelar node

2. "Build (first time) or Rebuild (update) only" - builds or updates your node

3. "Build/Rebuild with reset chain" - build your node and reset everything

4. "Reboot host" - restart your machine

5. "Build your validator" - Build and register a validator (prereq are options 1 and 2)

6. "Monitor the node via cli" - monitoring for your node and validator
