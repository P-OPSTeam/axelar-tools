#!/bin/bash

sudo apt install dialog -y -qq > /dev/null

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=15
BACKTITLE="Axelar"
TITLE="Install menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "Create Axelar Node"
         2 "Rebuild With cloning Git"
	 3 "Rebuild Without cloning Git"
	 4 "Rebuild With cloning Git reset chain"
	 5 "Rebuild Without cloning Git reset chain"
         6 "Start Axelar Core Docker and Tofnd Docker"
	 7 "Start c2d2"
	 8 "Reboot node")


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
            chmod u+x rebuildwithrecloningGit.sh
	    sudo ./rebuildwithrecloningGit.sh
            ;;
        3)
            chmod u+x rebuildwithoutrecloningGit.sh
            sudo ./rebuildwithoutrecloningGit.sh
            ;;
        4)
            chmod u+x rebuildwithoutrecloningGitreset.sh
            sudo ./rebuildwithoutrecloningGitreset.sh
            ;;
        5)
            chmod u+x rebuildwithoutrecloningGitreset.sh
            sudo ./rebuildwithoutrecloningGitreset.sh
            ;;
 	6)
            sudo Docker start Axelar-core
	    sudo Docker start tofnd
            ;;	
 	7)
            chmod u+x RunC2D2.sh
            sudo ./RunC2D2.sh

            ;;
 	8)
            chmod u+x rebootserver.sh
            sudo ./rebootserver.sh
            ;;

esac