# Monitoring Axelar node

To have automatic monitoring of your Axelar Node & Validator enabled one can follow this guide.

## Script nodemonitor.sh
To monitor the status of the Axelar Node & Validator it's possible to run the script **nodemonitor.sh** available in this repository.
This script is based/build on the https://github.com/stakezone/nodemonitorgaiad version already available.
When the script is started it will create a file with log entries that monitors the most important stuff of the node.

Since the script creates it's own logfile, it's adviced to run it in a separate directory, e.g. **_monitoring_**.

## What is monitored by the script
The script creates a log entry in the following format
```sh
2021-10-06 01:33:56+00:00 status=synced blockheight=1557207 tfromnow=7 npeers=12 npersistentpeersoff=1 isvalidator=yes pctprecommits=1.00 pcttotcommits=1.0
```
The log line entries are:

* **status** can be {scriptstarted | error | catchingup | synced} 'error' can have various causes, typically the gaiad process is down
* **blockheight** blockheight from lcd call 
* **tfromnow** time in seconds since blockheight
* **npeers** number of connected peers
* **npersistentpeersoff** number of disconnected persistent peers
* **isvalidator** if validator metrics are enabled, can be {yes | no}
* **pctprecommits** if validator metrics are enabled, percentage of last n precommits from blockheight as configured in nodemonitor.sh
* **pcttotcommits** if validator metrics are enabled, percentage of total commits of the validator set at blockheight

## Running the script as a service
To have the script monitor the node constantly and have active alerting available it's possible to run it as a service.
The following example shows how the service file will look like when running in Ubuntu 20.04.

When creating service files please be aware that **_sudo_** privileges will be needed when running as normal user!
The service assumes you have the script placed in your **_$HOME/monitoring_** directory.
Please be aware to run the service as the user that has sufficient right to access this directory (normally this will be the user that one used to logon to the system).
Best practice would be to create a separate user for the monitoring service, but this guide doesn't cover that!

Create a file called **axelar-nodemonitor.service** in the **_/etc/systemd/system_** directory and add the following lines into the file;
```
[Unit]
Description=Axelar NodeMonitor
Wants=network-online.target
After=network-online.target

[Service]
User=<YOUR LOGGED ON USERNAME>
Type=simple
ExecStart=/home/<YOUR LOGGED ON USERNAME>/monitoring/nodemonitor.sh

[Install]
WantedBy=multi-user.target
```

Now the service file is created it can be started by the following command:
```
sudo service axelar-nodemonitor start
```
To make sure the service will be active even when a reboot takes place, use:
```
sudo systemctl enable axelar-nodemonitor
```
Check the status of the service with:
```
sudo service axelar-nodemonitor status
```
