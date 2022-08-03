#!/bin/bash

#set -x # for debugging

###    packages required: jq, bc
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

###    if suppressing error messages is preferred, run as './nodemonitor.sh 2> /dev/null'

###    CONFIG    ##################################################################################################
CONFIG=""                # config.toml file for node, eg. $HOME/.gaia/config/config.toml
NETWORK=""               # Network for choosing testnet or mainnet, no caps!
### optional:            #
NPRECOMMITS="20"         # check last n precommits, can be 0 for no checking
VALIDATORADDRESS=""      # if left empty default is from status call (validator)
KEYRING_PASSWORD=""      # if left empty monitoring won't work
AXELARVALIDATORADDRESS="" #if left empty default is from status call (axelar validator)
CHECKPERSISTENTPEERS="1" # if 1 the number of disconnected persistent peers is checked (when persistent peers are configured in config.toml)
VALIDATORMETRICS="on"    # metrics for validator node
LOGNAME=""               # a custom log file name can be chosen, if left empty default is nodecheck-<username>.log
LOGPATH="$(pwd)"         # the directory where the log file is stored, for customization insert path like: /my/path
LOGSIZE=200              # the max number of lines after that the log will be trimmed to reduce its size
LOGROTATION="1"          # options for log rotation: (1) rotate to $LOGNAME.1 every $LOGSIZE lines;  (2) append to $LOGNAME.1 every $LOGSIZE lines; (3) truncate $logfile to $LOGSIZE every iteration
SLEEP1="15s"             # polls every SLEEP1 sec
###  internal:           #
colorI='\033[0;32m'      # black 30, red 31, green 32, yellow 33, blue 34, magenta 35, cyan 36, white 37
colorD='\033[0;90m'      # for light color 9 instead of 3
colorE='\033[0;31m'      #
colorW='\033[0;33m'      #
noColor='\033[0m'        # no color
###  END CONFIG  ##################################################################################################

################### NOTIFICATION CONFIG ###################
enable_notification="true" #true of false
# TELEGRAM
enable_telegram="false"
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
# DISCORD
enable_discord="false"
DISCORD_URL="<ENTER YOUR DISCORD WEBHOOK>"

#variable below avoid spams for the same notification state along with their notification message
#catchup
synced_n="catchingup"  # notification state either synced of catchingup (value possible catchingup/synced)
nmsg_synced="$HOSTNAME: Your Axelar node is now in synced"
nmsg_unsynced="$HOSTNAME: Your Axelar node is no longer in synced"

#node stuck
lastblockheight=0
node_stuck_n="false" # true or false indicating the notification state of a node stuck
nmsg_nodestuck="$HOSTNAME: Your Axelar node is now stuck"
nmsg_node_no_longer_stuck="$HOSTNAME: Your Axelar node is no longer stuck, Yeah !"
node_stuck_status="NA" #node stucktest status to print out to log file

#axelar-core version
axelar_version_n="true" # true or false indicating whether the current version is correct
nmsg_axelar_version_ok="$HOSTNAME: Your Axelar node version is ok now"
nmsg_axelar_version_nok="$HOSTNAME: Your Axelar node version is different from axelar repo"
axelar_version_status="NA" #Axelar core version test status to print out to log file

#axelar-core run (axelard)
axelar_run_n="true" # true or false indicating whether axelard(axelar-core) is running or not
nmsg_axelar_run_ok="$HOSTNAME: Your Axelar node is running ok now"
nmsg_axelar_run_nok="@here $HOSTNAME: Your Axelar node has just stop running, fix it !"
axelard_run_status="NA" #axelard test status to print out to log file 

#vald run
vald_run_n="true" # true or false indicating whether tofnd is running or not
nmsg_vald_run_ok="$HOSTNAME: vald is running ok now"
nmsg_vald_run_nok="@here $HOSTNAME: vald has just stop running. We'll try to start the process and you'll see an ok message if that happens, if not please fix it"
vald_run_status="NA" #vald test status to print out to log file 

#tofnd run
tofnd_run_n="true" # true or false indicating whether tofnd is running or not
nmsg_tofnd_run_ok="$HOSTNAME: tofnd is running ok now"
nmsg_tofnd_run_nok="@here $HOSTNAME: tofnd has just stop running. We'll try to start the process and you'll see an ok message if that happens, if not please fix it"
tofnd_run_status="NA" #vald test status to print out to log file 

#Health check test
Health_check_n="true" # true or false indicating connectivity test state
msg_Health_check_ok="$HOSTNAME: Health check is ok"
msg_Health_check_nok="$HOSTNAME: Health check is not ok, please check"
Health_check_status="NA" #Health check status to print out to log file

#Jailed status
jailed_status_n="true" # true or false indicating jailed status
msg_jailed_status_ok="$HOSTNAME: Validator is not jailed"
msg_jailed_status_nok="@here $HOSTNAME: Validator is jailed, please check"
jailed_status="NA" #jailed status to print out to log file

#missed blocks status
missed_status_n="true" # true or false indicating missed blocks status
msg_missed_status_ok="$HOSTNAME: Validator is not missing blocks"
msg_missed_status_nok="@here $HOSTNAME: Validator is missing to many blocks, please check"
missed_status="NA" #missed status to print out to log file

#stale heartbeat status
stale_status_n="true" # true or false indicating stale tss heartbeat status
msg_stale_status_ok="$HOSTNAME: Validator has no stale tss heartbeat"
msg_stale_status_nok="@here $HOSTNAME: Validator has stale tss heartbeats, please check"
stale_status="NA" #stale status to print out to log file

#Tombstoned status
tombstoned_status_n="true" # true or false indicating tombstoned status
msg_tombstoned_status_ok="$HOSTNAME: Validator is not tombstoned"
msg_tombstoned_status_nok="@here $HOSTNAME: Validator is tombstoned, please double check"
tombstoned_status="NA" #stale status to print out to log file

#broadcaster balance test
broadcaster_min_balance=0.1
broadcaster_balance_n="false" # true or false indicating status of the broadcaster balance test
nmsg_broadcaster_balance_ok="$HOSTNAME: Broadcaster balance is now ok"
nmsg_broadcaster_balance_nok="$HOSTNAME: Broadcaster balance is below the min defined of ${broadcaster_min_balance}"
bc_balance_status="NA" #balance test status to print out to log file 

#eth endpoint test
eth_endpoint_test_n="true" # true or false indicating status of the eth_endpoint_test
nmsg_eth_endpoint_test_err="$HOSTNAME: Eth endpoint test ended with error"
nmsg_eth_endpoint_test_ok="$HOSTNAME: Eth endpoint test is now ok !"
nmsg_eth_endpoint_test_nok="$HOSTNAME: Eth endpoint test just failed !"
eth_endpoint_status="NA" #eth endpoint status to print out to log file 

#avax endpoint test
avax_endpoint_test_n="true" # true or false indicating status of the avax_endpoint_test
nmsg_avax_endpoint_test_err="$HOSTNAME: Avalanche endpoint test ended with error"
nmsg_avax_endpoint_test_ok="$HOSTNAME: Avalanche endpoint test is now ok !"
nmsg_avax_endpoint_test_nok="$HOSTNAME: Avalanche endpoint test just failed !"
avax_endpoint_status="NA" #Avax endpoint status to print out to log file 

#fantom endpoint test
fantom_endpoint_test_n="true" # true or false indicating status of the fantom_endpoint_test
nmsg_fantom_endpoint_test_err="$HOSTNAME: Fantom endpoint test ended with error"
nmsg_fantom_endpoint_test_ok="$HOSTNAME: Fantom endpoint test is now ok !"
nmsg_fantom_endpoint_test_nok="$HOSTNAME: Fantom endpoint test just failed !"
fantom_endpoint_status="NA" #fantom endpoint status to print out to log file 

#moonbeam endpoint test
moonbeam_endpoint_test_n="true" # true or false indicating status of the moonbeam_endpoint_test
nmsg_moonbeam_endpoint_test_err="$HOSTNAME: moonbeam endpoint test ended with error"
nmsg_moonbeam_endpoint_test_ok="$HOSTNAME: moonbeam endpoint test is now ok !"
nmsg_moonbeam_endpoint_test_nok="$HOSTNAME: moonbeam endpoint test just failed !"
moonbeam_endpoint_status="NA" #moonbeam endpoint status to print out to log file 

#polygon endpoint test
polygon_endpoint_test_n="true" # true or false indicating status of the polygon_endpoint_test
nmsg_polygon_endpoint_test_err="$HOSTNAME: polygon endpoint test ended with error"
nmsg_polygon_endpoint_test_ok="$HOSTNAME: polygon endpoint test is now ok !"
nmsg_polygon_endpoint_test_nok="$HOSTNAME: polygon endpoint test just failed !"
polygon_endpoint_status="NA" #polygon endpoint status to print out to log file 

#binance endpoint test
binance_endpoint_test_n="true" # true or false indicating status of the binance_endpoint_test
nmsg_binance_endpoint_test_err="$HOSTNAME: binance endpoint test ended with error"
nmsg_binance_endpoint_test_ok="$HOSTNAME: binance endpoint test is now ok !"
nmsg_binance_endpoint_test_nok="$HOSTNAME: binance endpoint test just failed !"
binance_endpoint_status="NA" #binance endpoint status to print out to log file

# Check deregister chainmaintainer Ethereum
ETH_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_ETH_chain_maintainer_ok="$HOSTNAME: ETH chainmaintainer is ok"
nmsg_ETH_chain_maintainer_nok="@here $HOSTNAME: ETH chainmaintainer deregistered"
ETH_chain_maintainer_status="NA"  

# Check deregister chainmaintainer Avalanche
AVAX_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_AVAX_chain_maintainer_ok="$HOSTNAME: AVAX chainmaintainer is ok"
nmsg_AVAX_chain_maintainer_nok="@here $HOSTNAME: AVAX chainmaintainer deregistered"
AVAX_chain_maintainer_status="NA"  

# Check deregister chainmaintainer Polygon
POLY_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_POLY_chain_maintainer_ok="$HOSTNAME: Polygon chainmaintainer is ok"
nmsg_POLY_chain_maintainer_nok="@here $HOSTNAME: Polygon chainmaintainer deregistered"
POLY_chain_maintainer_status="NA" 

# Check deregister chainmaintainer Moonbeam
MOON_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_MOON_chain_maintainer_ok="$HOSTNAME: Moonbeam chainmaintainer is ok"
nmsg_MOON_chain_maintainer_nok="@here $HOSTNAME: Moonbeam chainmaintainer deregistered"
MOON_chain_maintainer_status="NA" 

# Check deregister chainmaintainer Fantom
FTM_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_FTM_chain_maintainer_ok="$HOSTNAME: Fantom chainmaintainer is ok"
nmsg_FTM_chain_maintainer_nok="@here $HOSTNAME: Fantom chainmaintainer deregistered"
FTM_chain_maintainer_status="NA" 

# Check deregister chainmaintainer Binance
BSC_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_BSC_chain_maintainer_ok="$HOSTNAME: Binance chainmaintainer is ok"
nmsg_BSC_chain_maintainer_nok="@here $HOSTNAME: Binance chainmaintainer deregistered"
BSC_chain_maintainer_status="NA" 

# Check deregister chainmaintainer aurora
aurora_chain_maintainer_n="true" # true or false indicicating deregister chainmaintainer
nmsg_aurora_chain_maintainer_ok="$HOSTNAME: aurora chainmaintainer is ok"
nmsg_aurora_chain_maintainer_nok="@here $HOSTNAME: aurora chainmaintainer deregistered"
aurora_chain_maintainer_status="NA" 

#MPC eligibility test
min_eligible_threshold=0.02 #2% total state are required to be eligible
mpc_eligibility_test_n="true"
nmsg_mpc_eligibility_test_err="$HOSTNAME: MPC eligible test command failed with error"
nmsg_mpc_eligibility_test_ok="$HOSTNAME: MPC eligibility test now ok"
nmsg_mpc_eligibility_test_nok="$HOSTNAME: MPC eligibility test just failed !"
mpc_eligibility_status="NA" #mpc eligibility status to print out to log file 
################### END NOTIFICATION CONFIG ###################

echo "Notification enabled on telegram : ${enable_telegram} / on discord : ${enable_discord}"

send_notification() {
    if [ "$enable_notification" == "true" ]; then
        message=$1
        
        if [ "$enable_telegram" == "true" ]; then
            curl -s -X POST https://api.telegram.org/${BOT_ID}/sendMessage -d parse_mode=html -d chat_id=${CHAT_ID=} -d text="<b>$(hostname)</b> - $(date) : ${message}" > /dev/null 2>&1
        fi
        if [ "$enable_discord" == "true" ]; then
            curl -s -X POST $DISCORD_URL -H "Content-Type: application/json" -d "{\"content\": \"${message}\"}" > /dev/null 2>&1
        fi
    fi
}

# checking on broadcaster
check_broadcaster_balance() {
    broadcaster=$(echo $KEYRING_PASSWORD | axelard keys show broadcaster -a --home $HOME/$NETWORKPATH/.vald)

    echo $KEYRING_PASSWORD | axelard q bank balances ${broadcaster} | grep amount > /dev/null 2>&1

    if [ $? -ne 0 ]; then #if grep fail there is no balance and $? will return 1
        #echo "Failed to capture balance, please manually run : axelard q bank balances ${broadcaster} | grep amount"
        send_notification "$HOSTNAME: Failed to capture balance, please manually run : axelard q bank balances ${broadcaster} | grep amount"
        bc_balance_status="ERR"
    else
        balance=$(echo $KEYRING_PASSWORD | axelard q bank balances ${broadcaster} | grep amount | cut -d '"' -f 2)  

        if [ $(echo "${balance} <= ${broadcaster_min_balance}" | bc -l) -eq 1 ]; then #balance is <= broadcaster_min_balance
            msg="${broadcaster} current balance is $balance."
            bc_balance_status="NOK($balance)"
            if [ $broadcaster_balance_n == "true" ]; then #broadcaster was ok 
                send_notification "$nmsg_broadcaster_balance_nok. $msg"
                broadcaster_balance_n="false"
            fi
        else
            if [ $broadcaster_balance_n == "false" ]; then #broadcaster was not ok 
                send_notification "$nmsg_broadcaster_balance_ok with $balance"
                broadcaster_balance_n="true"
            fi
            bc_balance_status="OK($balance)"
        fi
    fi
}

check_eth_endpoint() {
    url_res=$(curl -sX POST ${ETHNODE} -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        eth_endpoint_status="ERR"  
        if [ $eth_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_eth_endpoint_test_err"
            eth_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            eth_endpoint_status="NOK" 
            if [ $eth_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_eth_endpoint_test_nok"
                eth_endpoint_test_n="false"
            fi
        else  
            eth_endpoint_status="OK"
            if [ $eth_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_eth_endpoint_test_ok"
                eth_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_avax_endpoint() {
    url_res=$(curl -X POST --data '{"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0xf3ce1887178d73aa90c98bc6be36bdc195ccb48d", "latest" ], "id": 1}' -H 'content-type:application/json;' $AVAXNODE 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        avax_endpoint_status="ERR"  
        if [ $avax_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_avax_endpoint_test_err"
            avax_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            avax_endpoint_status="NOK" 
            if [ $avax_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_avax_endpoint_test_nok"
                avax_endpoint_test_n="false"
            fi
        else  
            avax_endpoint_status="OK"
            if [ $avax_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_avax_endpoint_test_ok"
                avax_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_fantom_endpoint() {
    url_res=$(curl -X POST --data '{"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0xf3ce1887178d73aa90c98bc6be36bdc195ccb48d", "latest" ], "id": 1}' -H 'content-type:application/json;' $FANTOMNODE 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        fantom_endpoint_status="ERR"  
        if [ $fantom_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_fantom_endpoint_test_err"
            fantom_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            fantom_endpoint_status="NOK" 
            if [ $fantom_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_fantom_endpoint_test_nok"
                fantom_endpoint_test_n="false"
            fi
        else  
            fantom_endpoint_status="OK"
            if [ $fantom_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_fantom_endpoint_test_ok"
                fantom_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_moonbeam_endpoint() {
    url_res=$(curl -X POST --data '{"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0xf3ce1887178d73aa90c98bc6be36bdc195ccb48d", "latest" ], "id": 1}' -H 'content-type:application/json;' $MOONBEAMNODE 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        moonbeam_endpoint_status="ERR"  
        if [ $moonbeam_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_moonbeam_endpoint_test_err"
            moonbeam_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            moonbeam_endpoint_status="NOK" 
            if [ $moonbeam_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_moonbeam_endpoint_test_nok"
                moonbeam_endpoint_test_n="false"
            fi
        else  
            moonbeam_endpoint_status="OK"
            if [ $moonbeam_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_moonbeam_endpoint_test_ok"
                moonbeam_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_polygon_endpoint() {
    url_res=$(curl -X POST --data '{"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0xf3ce1887178d73aa90c98bc6be36bdc195ccb48d", "latest" ], "id": 1}' -H 'content-type:application/json;' $POLYGONNODE 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        polygon_endpoint_status="ERR"  
        if [ $polygon_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_polygon_endpoint_test_err"
            polygon_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            polygon_endpoint_status="NOK" 
            if [ $polygon_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_polygon_endpoint_test_nok"
                polygon_endpoint_test_n="false"
            fi
        else  
            polygon_endpoint_status="OK"
            if [ $polygon_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_polygon_endpoint_test_ok"
                polygon_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_binance_endpoint() {
    url_res=$(curl -X POST --data '{"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0xf3ce1887178d73aa90c98bc6be36bdc195ccb48d", "latest" ], "id": 1}' -H 'content-type:application/json;' $BSCNODE 2> /dev/null)
    #echo $url_res
    if [ $? -ne 0 ]; then #curl somehow failed
        binance_endpoint_status="ERR"  
        if [ $binance_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_binance_endpoint_test_err"
            binance_endpoint_test_n="false"
        fi
    else
        if [[ $url_res =~ "error" ]]; then
            binance_endpoint_status="NOK" 
            if [ $binance_endpoint_test_n == "true" ]; then #test was ok
                send_notification "$nmsg_binance_endpoint_test_nok"
                binance_endpoint_test_n="false"
            fi
        else  
            binance_endpoint_status="OK"
            if [ $binance_endpoint_test_n == "false" ]; then #test was not ok
                send_notification "$nmsg_binance_endpoint_test_ok"
                binance_endpoint_test_n="true"
            fi
        fi
    fi    
}

check_eligibility_MPC() {
    total_voting_power=$(curl -s $url/dump_consensus_state | jq -r "[.result.round_state.validators.validators[].voting_power | tonumber] | add")
    local res1=$?
    self_voting_power=$(curl -s $url/dump_consensus_state | jq -r --arg VALIDATORADDRESS "$VALIDATORADDRESS" '.result.round_state.validators.validators[] | select(.address==$VALIDATORADDRESS) | {voting_power}' | jq -r ".voting_power")
    local res2=$?

    if [[ res1 -ne 0 || res2 -ne 0 ]]; then         
        mpc_eligibility_status="ERR"
        if [ $eth_endpoint_test_n == "true" ]; then #test was ok
            send_notification "$nmsg_mpc_eligibility_test_err"
            mpc_eligibility_test_n="false"
        fi
    fi

    if [ $(echo "${min_eligible_threshold} <= (${self_voting_power} / ${total_voting_power})" | bc -l) -eq 1 ]; then
        #self_voting_power is above min eligible threshold
        mpc_eligibility_status="OK"
        if [ $mpc_eligibility_test_n == "false" ]; then #test was ok
            send_notification "$nmsg_mpc_eligibility_test_ok"
            mpc_eligibility_test_n="true"
        fi
    else
        mpc_eligibility_status="NOK"
        if [ $mpc_eligibility_test_n == "true" ]; then #test was not ok
            send_notification "$nmsg_mpc_eligibility_test_nok"
            mpc_eligibility_test_n="false"
        fi
    fi
}

if  [ -z $NETWORK ];then
    echo "please configure Network variable in script"
    exit 1
fi


if [ $NETWORK == testnet ]; then
    echo "Network switched to Testnet"
    NETWORKPATH=".axelar_testnet"
    if [ -z $CONFIG ]; then
    CONFIG=$HOME/$NETWORKPATH/.vald/config/config.toml
    fi
    CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelar-docs/main/pages/resources/$NETWORK.md  | grep axelar-core | cut -d \` -f 4 | cut -d \v -f2)
else
    echo "Network switched to Mainnet"
    NETWORKPATH=".axelar"
    if [ -z $CONFIG ]; then
    CONFIG=$HOME/$NETWORKPATH/.vald/config/config.toml
    fi
    CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelar-docs/main/pages/resources/$NETWORK.md  | grep axelar-core | cut -d \` -f 4 | cut -d \v -f2)
fi

if [ -z $CONFIG ]; then
    echo "please configure config.toml in script"
    exit 1
fi

if [ -z $KEYRING_PASSWORD ]; then
    echo "Please enter the password one time below, if setting up as a service fill the field in the script"
    read -p "Enter your password for polling the keys :" KEYRING_PASSWORD
fi

url=$(sudo sed '/^\[rpc\]/,/^\[/!d;//d' $CONFIG | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
chainid=$(jq -r '.result.node_info.network' <<<$(curl -s "$url"/status))
if [ -z $url ]; then
    send_notification "nodemonitor exited : please configure config.toml in script correctly"
    echo "please configure config.toml in script correctly"
    exit 1
fi
url="http://${url}"

if [ -z $LOGNAME ]; then LOGNAME="nodemonitor-${USER}.log"; fi

logfile="${LOGPATH}/${LOGNAME}"
touch $logfile

echo "log file: ${logfile}"
echo "rpc url: ${url}"
echo "chain id: ${chainid}"

if [ -z $VALIDATORADDRESS ]; then VALIDATORADDRESS=$(jq -r ''.result.validator_info.address'' <<<$(curl -s "$url"/status)); fi
if [ -z $VALIDATORADDRESS ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

if [ -z $AXELARVALIDATORADDRESS ];
then
    AXELARVALIDATORADDRESS=$(echo $KEYRING_PASSWORD | axelard keys show validator --bech val -a --home $HOME/$NETWORKPATH/.core);
fi

if [ -z $AXELARVALIDATORADDRESS ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

# Checking validator RPC endpoints status
consdump=$(curl -s "$url"/dump_consensus_state)
validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

if [ "$isvalidator" != "0" ]; then

        ETHNODE="$(sudo grep -A 1 'name = "\Ethereum\"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No eth node specified"
        send_notification "nodemonitor exited : No eth node specified"
        else
        echo "Eth node read from config file is : $ETHNODE"
        fi

        #BTCNODE="$(sudo grep -A 1 '# Address of the bitcoin RPC server' ${CONFIG} | grep -oP '(?<=").*?(?=")')"
        #if [ $? -ne 0 ]; then #something failed with the above command
        #echo "Failed to capture the btc node"
        #send_notification "nodemonitor exited : Failed to capture the btc node"
        #fi

        #echo "btc node read from config file is : $BTCNODE"

        AVAXNODE="$(sudo grep -A 1 'name = "Avalanche"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No avax node specified"
        send_notification "nodemonitor exited : No avax node specified"
        else
        echo "avax node read from config file is : $AVAXNODE"
        fi

        FANTOMNODE="$(sudo grep -A 1 'name = "Fantom"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No fantom node specified"
        send_notification "nodemonitor exited : No fantom node specified"
        else
        echo "fantom node read from config file is : $FANTOMNODE"
        fi

        MOONBEAMNODE="$(sudo grep -A 1 'name = "Moonbeam"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No moonbeam node specified"
        send_notification "nodemonitor exited : No moonbeam node specified"
        else 
        echo "moonbeam node read from config file is : $MOONBEAMNODE"
        fi

        POLYGONNODE="$(sudo grep -A 1 'name = "Polygon"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No polygon node specified"
        send_notification "nodemonitor exited : No polygon node specified"
        else 
        echo "polygon node read from config file is : $POLYGONNODE"
        fi

        BSCNODE="$(sudo grep -A 1 'name = "binance"' ${CONFIG} | tail -n 1  | grep -oP '(?<=").*?(?=")')"
        if [ $? -ne 0 ]; then #something failed with the above command
        echo "No binance node specified"
        send_notification "nodemonitor exited : No polygon node specified"
        else 
        echo "binance node read from config file is : $BSCNODE"
        fi
        
fi

echo "validator address: $AXELARVALIDATORADDRESS"

if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
    persistentpeers=$(sudo sed '/^\[p2p\]/,/^\[/!d;//d' $CONFIG | grep "^persistent_peers\b" | awk -v FS='("|")' '{print $2}')
    persistentpeerids=$(sed 's/,//g' <<<$(sed 's/@[^ ^,]\+/ /g' <<<$persistentpeers))
    totpersistentpeerids=$(wc -w <<<$persistentpeerids)
    npersistentpeersmatchcount=0
    netinfo=$(curl -s "$url"/net_info)
    if [ -z "$netinfo" ]; then
        echo "lcd appears to be down, start script again when data can be obtained"
        exit 1
    fi
    for id in $persistentpeerids; do
        npersistentpeersmatch=$(grep -c "$id" <<<$netinfo)
        if [ $npersistentpeersmatch -eq 0 ]; then
            persistentpeersmatch="$id $persistentpeersmatch"
            npersistentpeersmatchcount=$(expr $npersistentpeersmatchcount + 1)
        fi
    done
    npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatchcount)
    echo "$totpersistentpeerids persistent peer(s): $persistentpeerids"
    echo "$npersistentpeersmatchcount persistent peer(s) off: $persistentpeersmatch"
fi

if [ $NPRECOMMITS -eq 0 ]; then echo "precommit checks: off"; else echo "precommit checks: on"; fi
if [ $CHECKPERSISTENTPEERS -eq 0 ]; then echo "persistent peer checks: off"; else echo "persistent peer checks: on"; fi
echo ""

status=$(curl -s "$url"/status)
blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
blockinfo=$(curl -s "$url"/block?height="$blockheight")
if [ $blockheight -gt $NPRECOMMITS ]; then
    if [ "$(grep -c 'precommits' <<<$blockinfo)" != "0" ]; then versionstring="precommits"; elif [ "$(grep -c 'signatures' <<<$blockinfo)" != "0" ]; then versionstring="signatures"; else
        echo "json parameters of this version not recognised"
        exit 1
    fi
else
    echo "wait for $NPRECOMMITS blocks and start again..."
    exit 1
fi

nloglines=$(wc -l <$logfile)
if [ $nloglines -gt $LOGSIZE ]; then sed -i "1,$(expr $nloglines - $LOGSIZE)d" $logfile; fi # the log file is trimmed for logsize

date=$(date --rfc-3339=seconds)
echo "$date status=scriptstarted chainid=$chainid" >>$logfile

while true ; do
    # Determining binary or docker installation
        # Checking axelar-core version
        echo -n "Determining latest Axelar version: "
        #Determining running version
        axelard version  &> version.txt
        RUNNING_VERSION=$(tail version.txt)
        # testing Axelar version
        if [ $RUNNING_VERSION == $CORE_VERSION ]; then
            echo "$CORE_VERSION is latest";
            axelar_version_status="latest"
            if [ $axelar_version_n == "false" ]; then #version was not ok
                send_notification "$nmsg_axelar_version_ok"
                axelar_version_n="true"
            fi
        else
            echo "Not latest, consider upgrading to the new axelar-core version $CORE_VERSION"
            axelar_version_status="need_update"
            if [ $axelar_version_n == "true" ]; then #version was ok
            send_notification "$nmsg_axelar_version_nok"
            axelar_version_n="false"
            fi
        fi       
        
        # Checking axelard process running
        if pgrep axelard >/dev/null; then
            echo "Is axelard binary running: Yes";
            axelard_run_status="OK"
            if [ $axelar_run_n == "false" ]; then #axelard process was not ok
            send_notification "$nmsg_axelar_run_ok"
            axelar_run_n="true"
            fi
        else
            echo "Is axelard binary running: No, please restart it;"
            axelard_run_status="NOK"
            if [ $axelar_run_n == "true" ]; then #axelard process was ok
            send_notification "$nmsg_axelar_run_nok"
            axelar_run_n="false"
            fi
        fi

        # Checking validator status
        consdump=$(curl -s "$url"/dump_consensus_state)
        validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
        isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

        if [ "$isvalidator" != "0" ]; then
            # Checking tofnd process
            if pgrep tofnd >/dev/null; then
                echo "Is tofnd proces running: Yes";
                tofnd_run_status="OK"
                if [ $tofnd_run_n == "false" ]; then #tofnd was not ok
                send_notification "$nmsg_tofnd_run_ok"
                tofnd_run_n="true"
                fi
            else
                echo "Is tofnd process running: no, make sure it runs";
                tofnd_run_status="NOK"
                if [ $tofnd_run_n == "true" ]; then #tofnd was ok
                tofnd_run_n="false"
                send_notification "$nmsg_tofnd_run_nok"
                # let's try to fix the problem once
                fi
            fi

            # Checking vald-start process
            if pgrep -f "axelard vald-start" >/dev/null; then
                echo "Is vald-start running: Yes";
                vald_run_status="OK"
                if [ $vald_run_n == "false" ]; then #vald was not ok
                send_notification "$nmsg_vald_run_ok"
                vald_run_n="true"
                fi
            else
                echo "Is vald-start process running: no, make sure it runs";
                vald_run_status="NOK"
                if [ $vald_run_n == "true" ]; then #vald was ok
                vald_run_n="false"
                send_notification "$nmsg_vald_run_nok"
                # let's try to fix the problem once
                fi
            fi

        
            echo -n "health-check is : "
            axelard health-check --operator-addr $(cat $HOME/$NETWORKPATH/validator.bech) > /home/$USER/axelar-tools/monitoring/healthcheck.log
            if grep -q -F "failed" "/home/$USER/axelar-tools/monitoring/healthcheck.log"; then
                echo 'not ok'
                Health_check_status="NOK"
                if [ $Health_check_n == "true" ]; then
                    send_notification "$msg_Health_check_nok"
                    Health_check_n="false"
                fi
             else
                echo 'ok'
                Health_check_status="OK"
                if [ $Health_check_n == "false" ]; then
                    send_notification "$msg_Health_check_ok"
                    Health_check_n="true"
                fi
            fi

            echo -n "Validator is Jailed : "
            jailed=$(axelard q snapshot validators | grep "$AXELARVALIDATORADDRESS" -A 9 | grep jailed | cut -d ':' -f 2)
            if [ $jailed == "true" ]; then
                echo "true"
                jailed_status="NOK"
                if [ $jailed_status_n == "false" ]; then
                    send_notification "$msg_jailed_status_nok"
                    jailed_status_n="true"
                fi
            else
                echo "false"
                if [ $jailed_status_n == "true" ]; then
                    send_notification "$msg_jailed_status_ok"
                    jailed_status_n="false"
                fi
            fi
            
            echo -n "Validator missed blocks : "
            missed=$(axelard q snapshot validators | grep "$AXELARVALIDATORADDRESS" -A 9 | grep missed_too_many_blocks | cut -d ':' -f 2)
            if [ $missed == "true" ]; then
                echo "true"
                missed_status="NOK"
                if [ $missed_status_n == "false" ]; then
                    send_notification "$msg_missed_status_nok"
                    missed_status_n="true"
                fi
            else
                echo "false"
                if [ $missed_status_n == "true" ]; then
                    send_notification "$msg_missed_status_ok"
                    missed_status_n="false"
                fi
            fi

            echo -n "Validator has stale tss heartbeat : "
            stale=$(axelard q snapshot validators | grep "$AXELARVALIDATORADDRESS" -A 9 | grep stale_tss_heartbeat | cut -d ':' -f 2)
            if [ $stale == "true" ]; then
                echo "true"
                stale_status="NOK"
                if [ $stale_status_n == "false" ]; then
                    send_notification "$msg_stale_status_nok"
                    stale_status_n="true"
                fi
            else
                echo "false"
                if [ $stale_status_n == "true" ]; then
                    send_notification "$msg_stale_status_ok"
                    stale_status_n="false"
                fi
            fi

            echo -n "Validator is Tombstoned : "
            tombstoned=$(axelard q snapshot validators | grep "$AXELARVALIDATORADDRESS" -A 9 | grep tombstoned | cut -d ':' -f 2)
            if [ $tombstoned == "true" ]; then
                echo "true"
                tombstoned_status="NOK"
                if [ $tombstoned_status_n == "false" ]; then
                    send_notification "$msg_tombstoned_status_nok"
                    tombstoned_status_n="true"
                fi
            else
                echo "false"
                if [ $tombstoned_status_n == "true" ]; then
                    send_notification "$msg_tombstoned_status_ok"
                    tombstoned_status_n="false"
                fi
            fi

            # Check deregister ETH chainmaintainer
            ETHCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Ethereum")
            if [ -z "$ETHCHAIN" ]
            then
            echo "Ethereum chainmaintainers not deregistered"
            ETH_chain_maintainer_status="OK"
                if [ $ETH_chain_maintainer_n == "false" ]; then 
                ETH_chain_maintainer_n="true"
                send_notification "$nmsg_ETH_chain_maintainer_ok"
                fi
            else
            echo "Ethereum chainmaintainer deregistered"
	        ETH_chain_maintainer_status="NOK"
                if [ $ETH_chain_maintainer_n == "true" ]; then
                ETH_chain_maintainer_n="false"
                send_notification "$nmsg_ETH_chain_maintainer_nok"
                fi
            fi
	
            # Check deregister Avalanche chainmaintainer
            AVAXCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Avalanche")
            if [ -z "$AVAXCHAIN" ]
            then
            echo "Avalanche chainmaintainers not deregistered"
            AVAX_chain_maintainer_status="OK"
                if [ $AVAX_chain_maintainer_n == "false" ]; then 
                AVAX_chain_maintainer_n="true"
                send_notification "$nmsg_AVAX_chain_maintainer_ok"
                fi
            else
            echo "Avalanche chainmaintainer deregistered"
	        AVAX_chain_maintainer_status="NOK"
                if [ $AVAX_chain_maintainer_n == "true" ]; then
                AVAX_chain_maintainer_n="false"
                send_notification "$nmsg_AVAX_chain_maintainer_nok"
                fi
            fi

            # Check deregister Polygon chainmaintainer
            POLYCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Polygon")
            if [ -z "$POLYCHAIN" ]
            then
            echo "Polygon chainmaintainers not deregistered"
            POLY_chain_maintainer_status="OK"
                if [ $POLY_chain_maintainer_n == "false" ]; then 
                POLY_chain_maintainer_n="true"
                send_notification "$nmsg_POLY_chain_maintainer_ok"
                fi
            else
            echo "Polygon chainmaintainer deregistered"
	        POLY_chain_maintainer_status="NOK"
                if [ $POLY_chain_maintainer_n == "true" ]; then
                POLY_chain_maintainer_n="false"
                send_notification "$nmsg_POLY_chain_maintainer_nok"
                fi
            fi
	
            # Check deregister Moonbeam chainmaintainer
            MOONCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Moonbeam")
            if [ -z "$MOONCHAIN" ]
            then
            echo "Moonbeam chainmaintainers not deregistered"
            MOON_chain_maintainer_status="OK"
                if [ $MOON_chain_maintainer_n == "false" ]; then 
                MOON_chain_maintainer_n="true"
                send_notification "$nmsg_MOON_chain_maintainer_ok"
                fi
            else
            echo "Moonbeam chainmaintainer deregistered"
	        MOON_chain_maintainer_status="NOK"
                if [ $MOON_chain_maintainer_n == "true" ]; then
                MOON_chain_maintainer_n="false"
                send_notification "$nmsg_MOON_chain_maintainer_nok"
                fi
            fi

            # Check deregister Fantom chainmaintainer
            FTMCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Fantom")
            if [ -z "$FTMCHAIN" ]
            then
            echo "Fantom chainmaintainers not deregistered"
            FTM_chain_maintainer_status="OK"
                if [ $FTM_chain_maintainer_n == "false" ]; then 
                FTM_chain_maintainer_n="true"
                send_notification "$nmsg_FTM_chain_maintainer_ok"
                fi
            else
            echo "Fantom chainmaintainer deregistered"
	        FTM_chain_maintainer_status="NOK"
                if [ $FTM_chain_maintainer_n == "true" ]; then
                FTM_chain_maintainer_n="false"
                send_notification "$nmsg_FTM_chain_maintainer_nok"
                fi
            fi  

            # Check deregister Binance chainmaintainer
            BSCCHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain Binance")
            if [ -z "$BSCCHAIN" ]
            then
            echo "Binance chainmaintainers not deregistered"
            BSC_chain_maintainer_status="OK"
                if [ $BSC_chain_maintainer_n == "false" ]; then 
                BSC_chain_maintainer_n="true"
                send_notification "$nmsg_BSC_chain_maintainer_ok"
                fi
            else
            echo "Binance chainmaintainer deregistered"
	        BSC_chain_maintainer_status="NOK"
                if [ $BSC_chain_maintainer_n == "true" ]; then
                BSC_chain_maintainer_n="false"
                send_notification "$nmsg_BSC_chain_maintainer_nok"
                fi
            fi

            # Check deregister Aurora chainmaintainer
            AURORACHAIN=$(tail -300 $HOME/$NETWORKPATH/logs/axelard.log | grep "deregistered validator $AXELARVALIDATORADDRESS as maintainer for chain aurora")
            if [ -z "$AURORACHAIN" ]
            then
            echo "aurora chainmaintainers not deregistered"
            aurora_chain_maintainer_status="OK"
                if [ $aurora_chain_maintainer_n == "false" ]; then 
                aurora_chain_maintainer_n="true"
                send_notification "$nmsg_aurora_chain_maintainer_ok"
                fi
            else
            echo "aurora chainmaintainer deregistered"
	        aurora_chain_maintainer_status="NOK"
                if [ $aurora_chain_maintainer_n == "true" ]; then
                aurora_chain_maintainer_n="false"
                send_notification "$nmsg_aurora_chain_maintainer_nok"
                fi
            fi

            #TBD ping pong test for binary
        fi
    
    echo

    # testing machine/host resource
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
    df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}'
    top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}'

    echo
    # TBD Alert on resource monitoring 

    status=$(curl -s "$url"/status)
    result=$(grep -c "result" <<<$status)
    if [ "$result" != "0" ]; then
        npeers=$(curl -s "$url"/net_info | jq -r '.result.n_peers')
        if [ -z $npeers ]; then npeers="na"; fi
        blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
        blocktime=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
        catchingup=$(jq -r '.result.sync_info.catching_up' <<<$status)
        if [ $catchingup == "false" ]; then 
            catchingup="synced";
            if [ $synced_n == "catchingup" ]; then #it was previously synching
                send_notification "$nmsg_synced"
                synced_n="synced" #change notification state
            fi
        elif [ $catchingup == "true" ]; then 
            catchingup="catchingup";
            if [ $synced_n == "synced" ]; then #it was previously synced
                send_notification $nmsg_unsynced 
                synced_n="catchingup" #change notification state
            fi
        fi

        if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
            npersistentpeersmatch=0
            netinfo=$(curl -s "$url"/net_info)
            for id in $persistentpeerids; do
                npersistentpeersmatch=$(expr $npersistentpeersmatch + $(grep -c "$id" <<<$netinfo))
            done
            npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatch)
        else
            npersistentpeersoff=0
        fi
        if [ "$VALIDATORMETRICS" == "on" ]; then
            #isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$(curl -s "$url"/block?height="$blockheight"))
            consdump=$(curl -s "$url"/dump_consensus_state)
            validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
            isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)
            pcttotcommits=$(jq -r '.result.round_state.last_commit.votes_bit_array' <<<$consdump)
            pcttotcommits=$(grep -Po "=\s+\K[^ ^]+" <<<$pcttotcommits)
            if [ "$isvalidator" != "0" ]; then
                isvalidator="yes"
                precommitcount=0
                for ((i = $(expr $blockheight - $NPRECOMMITS + 1); i <= $blockheight; i++)); do
                    validatoraddresses=$(curl -s "$url"/block?height="$i")
                    validatoraddresses=$(jq ".result.block.last_commit.${versionstring}[].validator_address" <<<$validatoraddresses)
                    validatorprecommit=$(grep -c "$VALIDATORADDRESS" <<<$validatoraddresses)
                    precommitcount=$(expr $precommitcount + $validatorprecommit)
                done
                if [ $NPRECOMMITS -eq 0 ]; then pctprecommits="1.0"; else pctprecommits=$(echo "scale=2 ; $precommitcount / $NPRECOMMITS" | bc); fi

                check_broadcaster_balance

                check_eth_endpoint

                check_avax_endpoint

                check_fantom_endpoint

                check_moonbeam_endpoint

                check_polygon_endpoint

                check_binance_endpoint

                check_eligibility_MPC
                
                validatorinfo="isvalidator=$isvalidator pctprecommits=$pctprecommits pcttotcommits=$pcttotcommits broadcaster_balance=$bc_balance_status eth_endpoint=$eth_endpoint_status avax_endpoint=$avax_endpoint_status fantom_endpoint=$fantom_endpoint_status moonbeam_endpoint=$moonbeam_endpoint_status polygon_endpoint=$polygon_endpoint_status binance_endpoint=$binance_endpoint_status mpc_eligibility=$mpc_eligibility_status vald_run=$vald_run_status tofnd_run=$tofnd_run_status Health_check=$Health_check_status"
            else
                isvalidator="no"
                validatorinfo="isvalidator=$isvalidator"
            fi
        fi

        # test if last block saved and new block height are the same
        if [ $lastblockheight -eq $blockheight ]; then #block are the same
            node_stuck_status="YES"
            if [ $node_stuck_n == "false" ]; then # node_stuck notification state was false
                node_stuck_n="true"
                send_notification "$nmsg_nodestuck"
            fi
        else #new node block is different
            node_stuck_status="NO"
            if [ $node_stuck_n == "true" ]; then # mean it was previously stuck
                node_stuck_n="false"
                send_notification "$nmsg_node_no_longer_stuck"                
            fi
            lastblockheight=$blockheight
        fi

        #finalize the log output
        status="$catchingup"
        now=$(date --rfc-3339=seconds)
        blockheightfromnow=$(expr $(date +%s -d "$now") - $(date +%s -d $blocktime))
        variables="status=$status blockheight=$blockheight node_stuck=$node_stuck_status tfromnow=$blockheightfromnow npeers=$npeers npersistentpeersoff=$npersistentpeersoff axelard_version=$axelar_version_status $validatorinfo"
    else
        status="error"
        now=$(date --rfc-3339=seconds)
        variables="status=$status"
    fi

    logentry="[$now] $variables"
    echo "$logentry" >>$logfile

    nloglines=$(wc -l <$logfile)
    if [ $nloglines -gt $LOGSIZE ]; then
        case $LOGROTATION in
        1)
            mv $logfile "${logfile}.1"
            touch $logfile
            ;;
        2)
            echo "$(cat $logfile)" >>${logfile}.1
            >$logfile
            ;;
        3)
            sed -i '1d' $logfile
            if [ -f ${logfile}.1 ]; then rm ${logfile}.1; fi # no log rotation with option (3)
            ;;
        *) ;;

        esac
    fi

    case $status in
    synced)
        color=$colorI
        ;;
    error)
        color=$colorE
        ;;
    catchingup)
        color=$colorW
        ;;
    *)
        color=$noColor
        ;;
    esac

    pctprecommits=$(awk '{printf "%f", $0}' <<<"$pctprecommits")
    if [[ "$isvalidator" == "yes" ]] && [[ "$pctprecommits" < "1.0" ]]; then color=$colorW; fi
    if [[ "$isvalidator" == "no" ]] && [[ "$VALIDATORMETRICS" == "on" ]]; then color=$colorW; fi

    logentry="$(sed 's/[^ ]*[\=]/'\\${color}'&'\\${noColor}'/g' <<<$logentry)"
    echo -e $logentry
    echo -e "${colorD}sleep ${SLEEP1}${noColor}"
    echo

    variables_=""
    for var in $variables; do
        var_=$(grep -Po '^[0-9a-zA-Z_-]*' <<<$var)
        var_="$var_=\"\""
        variables_="$var_; $variables_"
    done
    #echo $variables_
    eval $variables_

    sleep $SLEEP1
done
