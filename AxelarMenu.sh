#!/bin/bash

sudo apt install dialog -y -qq > /dev/null

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=15
BACKTITLE="Axelar"
TITLE="Install menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "Create Axelar Node and install requirements (docker, etc ..)"
         2 "Rebuild only"
         3 "Rebuild with reset chain"
         4 "Start Axelar Core Docker and Tofnd Docker"
         5 "Reboot node"
         6 "Build and use your own BTC&ETH endpont")


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
            chmod u+x testnetaxelar.sh
            sudo ./testnetaxelar.sh
            ;;
        2)
	        sudo bash ./run.sh
            ;;
        3)
            sudo bash ./run.sh reset
            ;;
 	    4)
            sudo Docker start Axelar-core
	        sudo Docker start tofnd
            ;;	
 	    5)
            chmod u+x rebootserver.sh
            sudo ./rebootserver.sh
            ;;
  	    6)
            chmod u+x newvalidator.sh
            sudo ./newvalidator.sh
            ;;

esac