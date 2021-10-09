#!/bin/bash
sudo apt update
sudo apt install dialog -y -qq > /dev/null

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=15
BACKTITLE="Axelar"
TITLE="Install menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "Create Axelar Node and install requirements (docker, etc ..)"
         2 "Rebuild only"
         3 "Rebuild with reset chain"
         4 "Reboot host"
         5 "Build and use your own BTC&ETH endpoint"
	 6 "Monitor the node via cli"
	 7 "Exit menu")


CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
            1)
            bash $SCRIPTPATH/testnetaxelar.sh
            ;;
            2)
	    bash $SCRIPTPATH/run.sh
            ;;
            3)
            bash $SCRIPTPATH/run.sh reset
            ;;
 	    4)
            bash $SCRIPTPATH/rebootserver.sh
            ;;
  	    5)
            bash $SCRIPTPATH/newvalidator.sh
            ;;
	    6)
            bash $SCRIPTPATH/nodemonitor.sh
            ;;
	    7) exit

esac
