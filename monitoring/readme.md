# Monitoring Axelar node

To have automatic monitoring of your Axelar Node & Validator enabled one can follow this guide.

## Script nodemonitor.sh

To monitor the status of the Axelar Node & Validator it's possible to run the script **nodemonitor.sh** available in this repository.
This script is based/build on the <https://github.com/stakezone/nodemonitorgaiad> version already available.
When the script is started it will create a file with log entries that monitors the most important stuff of the node.

Since the script creates it's own logfile, it's adviced to run it in a separate directory, e.g. **_monitoring_**.

## What is monitored by the script

The script creates a log entry in the following format

```bash
2021-10-06 01:33:56+00:00 status=synced blockheight=1557207 node_stuck=NO tfromnow=7 npeers=12 npersistentpeersoff=1 axelard_version=latest isvalidator=yes pctprecommits=1.00 pcttotcommits=1.0 broadcaster_balance=OK(50000) eth_endpoint=OK btc_endpoint=OK mpc_eligibility=OK vald_run=OK tofnd_run=OK vald_tofnd_ping=OK
```

The log line entries are:

* **status** can be {scriptstarted | error | catchingup | synced} 'error' can have various causes
* **blockheight** blockheight from lcd call
* **node_stuck** YES when last block read is the same as the last iteration
* **tfromnow** time in seconds since blockheight
* **npeers** number of connected peers
* **npersistentpeersoff** number of disconnected persistent peers
* **axelard_version** can be {latest | need_update}
* **isvalidator** if validator metrics are enabled, can be {yes | no}
* **pctprecommits** if validator metrics are enabled, percentage of last n precommits from blockheight as configured in nodemonitor.sh
* **pcttotcommits** if validator metrics are enabled, percentage of total commits of the validator set at blockheight
* **broadcaster_balance** OK if the broadcaster balance is enough with the current balance in (), else NOK.
* **eth_endpoint** OK if eth endpoint test succeeed if not it will be NOK. ERR will occurs if curl fails
* **btc_endpoint** OK if btc endpoint test succeeed if not it will be NOK. ERR will occurs if curl fails
* **mpc_eligibility** OK if MPC eligibility test suceed (ie stake % above min_eligible_threshold), else NOK. ERR will occurs if curl fails
* **vald_run** OK if vald container is running else NOK. NA if binary
* **tofnd_run** OK if vald container is running else NOK. NA if binary
* **vald_tofnd_ping** OK axelar ping command test between vald tofnd succeed. NA if binary

## Telegram Alerting

for telegram alerts, update :

```text
#TELEGRAM
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
```

you can create your telegram bot following this : <https://core.telegram.org/bots#6-botfather> and obtain the chat_id <https://stackoverflow.com/a/32572159>

## Running the script as a service

To have the script monitor the node constantly and have active alerting available it's possible to run it as a service.
The following example shows how the service file will look like when running in Ubuntu 20.04.

When creating service files please be aware that **_sudo_** privileges will be needed when running as normal user!
The service assumes you have the script placed in your **_$HOME/axelar-tools/monitoring_** directory.
Please be aware to run the service as the user that has sufficient right to access this directory (normally this will be the user that one used to logon to the system).
Best practice would be to create a separate user for the monitoring service, but this guide doesn't cover that!

Create a file called **axelar-nodemonitor.service** in the **_/etc/systemd/system_** directory and add the following lines into the file;

```text
[Unit]
Description=Axelar NodeMonitor
Wants=network-online.target
After=network-online.target

[Service]
User=<YOUR LOGGED ON USERNAME>
Type=simple
ExecStart=/home/<YOUR LOGGED ON USERNAME>/axelar-tools/monitoring/nodemonitor.sh

[Install]
WantedBy=multi-user.target
```

Now the service file is created it can be started by the following command:

```bash
sudo service axelar-nodemonitor start
```

To make sure the service will be active even when a reboot takes place, use:

```bash
sudo systemctl enable axelar-nodemonitor
```

Check the status of the service with:

```bash
sudo service axelar-nodemonitor status
```
