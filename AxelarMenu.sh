#!/bin/bash
sudo apt update > /dev/null 2>&1
REQUIRED_PKG="dialog"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=15
BACKTITLE="Axelar"
TITLE="Install menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "install axelar requirements (docker, etc ..)"
         2 "Build/Rebuild with reset chain"
         3 "Rebuild only"
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
        bash $SCRIPTPATH/prereq.sh
        ;;
    2)
        bash $SCRIPTPATH/run.sh reset
        ;;
    3)
        bash $SCRIPTPATH/run.sh
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
