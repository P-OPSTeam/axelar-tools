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
### optional:            #
NPRECOMMITS="20"         # check last n precommits, can be 0 for no checking
VALIDATORADDRESS=""      # if left empty default is from status call (validator)
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
#TELEGRAM
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"

#variable below avoid spams for the same notification state along with their notification message
#catchup
synced_n="catchingup"  # notification state either synced of catchingup (value possible catchingup/synced)
nmsg_synced="Your Axelar node is now in synced"
nmsg_unsynced="Your Axelar node is no longer in synced"


#node stuck
lastblockheight=0
node_stuck_n="false" # true or false indicating the notification state of a node stuck
nmsg_nodestuck="Your Axelar node is now stuck"
nmsg_node_no_longer_stuck="Your Axelar node is no longer stuck, Yeah !"

#axelar-core version
axelar_version_n="false" # true or false indicating whether the current version is correct
nmsg_axelar_version_ok="Your Axelar node version is ok now"
nmsg_axelar_version_nok="Your Axelar node version is different from axelar repo"

#axelar-core run (axelard)
axelar_run_n="false" # true or false indicating whether axelard(axelar-core) is running or not
nmsg_axelar_run_ok="Your Axelar node is running ok now"
nmsg_axelar_run_nok="Your Axelar node has just stop running, fix it !"

#vald run
vald_run_n="false" # true or false indicating whether tofnd is running or not
nmsg_vald_run_ok="vald is running ok now"
nmsg_vald_run_nok="vald has just stop running. We'll try to start the process and you'll see an ok message if that happens, if not please fix it"

#tofnd run
tofnd_run_n="false" # true or false indicating whether tofnd is running or not
nmsg_tofnd_run_ok="tofnd is running ok now"
nmsg_tofnd_run_nok="tofnd has just stop running. We'll try to start the process and you'll see an ok message if that happens, if not please fix it"

#vald tofnd connectivity test
vald_tofnd_ping_n="false"
nmsg_vald_tofnd_ping_ok="vald/tofnd connectivity is now ok"
nmsg_vald_tofnd_ping_nok="vald/tofnd is currently failing, please check"

################### END NOTIFICATION CONFIG ###################

send_telegram_notification() {
    if [ "$enable_notification" == "true" ]; then
        message=$1
        
        curl -s -X POST https://api.telegram.org/${BOT_ID}/sendMessage -d parse_mode=html -d chat_id=${CHAT_ID=} -d text="<b>$(hostname)</b> - $(date) : ${message}" > /dev/null 2>&1
    fi
}

if [ -z $CONFIG ]; then
    if [[ -f ~/.axelar_testnet/bin/axelard ]]; then
        CONFIG=~/.axelar_testnet/.core/config/config.toml;
    else
        if [[ -f ~/.axelar_testnet/shared/config.toml ]]; then
            CONFIG=~/.axelar_testnet/shared/config.toml;
        else
            CONFIG=~/config.toml
        fi
    fi
fi

if [ -z $CONFIG ]; then
    echo "please configure config.toml in script"
    exit 1
fi
url=$(sed '/^\[rpc\]/,/^\[/!d;//d' $CONFIG | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
chainid=$(jq -r '.result.node_info.network' <<<$(curl -s "$url"/status))
if [ -z $url ]; then
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
    if [[ -f ~/.axelar_testnet/bin/axelard ]]; then 
        AXELARVALIDATORADDRESS=$(~/.axelar_testnet/bin/axelard keys show validator --bech val -a --home ~/.axelar_testnet/.core);
    else 
        AXELARVALIDATORADDRESS=$(docker exec -it axelar-core axelard keys show validator --bech val -a);
    fi
fi
if [ -z $AXELARVALIDATORADDRESS ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

echo "validator address: $AXELARVALIDATORADDRESS"

if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
    persistentpeers=$(sed '/^\[p2p\]/,/^\[/!d;//d' $CONFIG | grep "^persistent_peers\b" | awk -v FS='("|")' '{print $2}')
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
    if [[ -f ~/.axelar_testnet/bin/axelard ]]; then
        # Checking axelard process running
        if pgrep axelard >/dev/null; then
            echo "Is axelard binary running: Yes";
        else
            echo "Is axelard binary running: No, please rerun join-testnet-with-binaries.sh";
            exit
        fi

        # Checking validator status
        consdump=$(curl -s "$url"/dump_consensus_state)
        validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
        isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

        if [ "$isvalidator" != "0" ]; then
            # Checking tofnd process
            if pgrep tofnd >/dev/null; then
                echo "Is tofnd proces running: Yes";
            else
                echo "Is tofnd process running: no, make sure it runs";
            fi

            # Checking vald-start process
            if ps aux | grep vald-start >/dev/null; then
                echo "Is vald-start running: Yes";
            else
                echo "Is vald-start process running: no, make sure it runs";
            fi

            #TBD ping pong test for binary
        fi
    else
        # Checking axelar-core version (docker)
        echo -n "Determining latest Axelar version: "
        CORE_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/documentation/docs/testnet-releases.md  | grep axelar-core | cut -d \` -f 4)

        # testing Axelar version
        if [ $(docker inspect -f '{{.Config.Image}}' axelar-core) = "axelarnet/axelar-core:$CORE_VERSION" ]; then
            echo "$CORE_VERSION is latest";
            if [ $axelar_version_n == "false" ]; then #version was not ok
                send_telegram_notification "$nmsg_axelar_version_ok"
                axelar_version_n="true"
            fi
        else
            echo "Not latest, consider upgrading to the new axelar-core version $CORE_VERSION";
            if [ $axelar_version_n == "true" ]; then #version was ok
                send_telegram_notification "$nmsg_axelar_version_nok"
                axelar_version_n="false"
            fi            
        fi

        # Testing axelar-core container is running
        echo -n "Is axelar-core running: "
        if [ $(docker inspect -f '{{.State.Running}}' axelar-core) = "true" ]; then
            echo "Yes";
            if [ $axelar_run_n == "false" ]; then #axelar core was stopped
                send_telegram_notification "$nmsg_axelar_run_ok"
                axelar_run_n="true"
            fi
        else 
            echo "No, please make sure it runs";
            axelar_run_n="true"
            send_telegram_notification "$nmsg_axelar_run_nok"
            # exit; Let's not exit and spam the notification channel so validator is aware :)
        fi

        # Checking validator status
        consdump=$(curl -s "$url"/dump_consensus_state)
        validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
        isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

        if [ "$isvalidator" != "0" ]; then
            # Checking Vald Container is running
            echo -n "Is Vald running: "
            if [ $(docker inspect -f '{{.State.Running}}' vald) = "true" ]; then 
                echo "Yes";
                if [ $vald_run_n == "false" ]; then #vald was stopped
                    send_telegram_notification "$nmsg_vald_run_ok"
                    vald_run_n="true"
                fi   
            else
                echo "No"
                if [ $vald_run_n == "true" ]; then #tofnd was running
                    vald_run_n="false"
                    send_telegram_notification "$nmsg_vald_run_nok"
                    # let's try to fix the problem once
                    sudo docker container restart vald
                fi
            fi

            # Checking Tofnd container is running
            echo -n "Is tofnd running: "
            if [ $(docker inspect -f '{{.State.Running}}' tofnd) = "true" ]; then
                echo "Yes"
                if [ $tofnd_run_n == "false" ]; then #tofnd was stopped
                    send_telegram_notification "$nmsg_tofnd_run_ok"
                    tofnd_run_n="true"
                fi                
            else
                echo "No"
                if [ $tofnd_run_n == "true" ]; then #tofnd was running
                    tofnd_run_n="false"
                    send_telegram_notification "$nmsg_tofnd_run_nok"
                    # let's try to fix the problem once
                    sudo docker container restart tofnd
                fi
            fi

            echo -n "Is there connectivity between vald/tofnd : "
            if [ $(sudo docker exec -ti vald axelard tofnd-ping --tofnd-host tofnd | tr -d '\r') == "Pong!" ]; then
                echo "Yes"
                if [ $vald_tofnd_ping_n == "false" ]; then #vald_tofnd_ping_n was failing
                    send_telegram_notification "$nmsg_vald_tofnd_ping_ok"
                    vald_tofnd_ping_n="true"
                fi  
            else
                echo "No"
                if [ $vald_tofnd_ping_n == "true" ]; then #vald_tofnd_ping_n was working
                    send_telegram_notification "$nmsg_vald_tofnd_ping_nok"
                    vald_tofnd_ping_n="false"
                fi
            fi
        fi
    fi

    echo

    # testing machine/host resource
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
    df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}'
    top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}'
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
                send_telegram_notification "$nmsg_synced"
                synced_n="synced" #change notification state
            fi
        elif [ $catchingup == "true" ]; then 
            catchingup="catchingup";
            if [ $synced_n == "synced" ]; then #it was previously synced
                send_telegram_notification $nmsg_unsynced 
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
                validatorinfo="isvalidator=$isvalidator pctprecommits=$pctprecommits pcttotcommits=$pcttotcommits"
            else
                isvalidator="no"
                validatorinfo="isvalidator=$isvalidator"
            fi
        fi
        status="$catchingup"
        now=$(date --rfc-3339=seconds)
        blockheightfromnow=$(expr $(date +%s -d "$now") - $(date +%s -d $blocktime))
        variables="status=$status blockheight=$blockheight tfromnow=$blockheightfromnow npeers=$npeers npersistentpeersoff=$npersistentpeersoff $validatorinfo"

        # test if last block saved and new block height are the same
        if [ $lastblockheight -eq $blockheight ]; then #block are the same
            if [ $node_stuck_n == "false" ]; then # node_stuck notification state was false
                node_stuck_n="true"
                send_telegram_notification "$nmsg_nodestuck"
            fi
        else #new node block is different
            if [ $node_stuck_n == "true" ]; then # mean it was previously stuck
                node_stuck_n="false"
                send_telegram_notification "$nmsg_node_no_longer_stuck"
            fi
            lastblockheight=$blockheight
        fi
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
