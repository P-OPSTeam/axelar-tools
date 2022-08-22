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

HEIGHT=17
WIDTH=60
CHOICE_HEIGHT=17
BACKTITLE="Axelar"
TITLE="Install menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "Install Binary by systemd"
         2 "Upgrade Binary by systemd"
         3 "Create validator systemd"
         4 "reboot node"
         5 "Monitor the node via cli wrapper"
         6 "Exit menu")


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
        bash $SCRIPTPATH/binaryinstallsystemd.sh
        ;;
    2)
        bash $SCRIPTPATH/Upgradebinarysystemd.sh
        ;;
    3)  
        bash $SCRIPTPATH/createvalidatorsystemd.sh
        ;;
    4)
        bash $SCRIPTPATH/rebootserver.sh
        ;;
    5)
        bash $SCRIPTPATH/monitoring/nodemonitor_binanry.sh
        ;;
    6)  exit
esac
