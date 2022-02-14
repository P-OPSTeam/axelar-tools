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

OPTIONS=(1 "Install Binary by using wrapper"
         2 "Install Binary by systemd"
         3 "Upgrade Binary by using warpper"
         4 "Upgrade Binary by systemd"
         5 "reboot node"
         6 "Monitor the node via cli wrapper"
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
        echo "building in progress"
        ;;
    2)
        bash $SCRIPTPATH/runbinaryinstall.sh
        ;;
    3)
        bash $SCRIPTPATH/Upgradevalidator.sh
        ;;
    4)
        bash $SCRIPTPATH/Upgradebinarysystemd.sh
        ;;
    5)
        bash $SCRIPTPATH/rebootserver.sh
        ;;
    6)
        bash $SCRIPTPATH/monitoring/nodemonitor.sh
        ;;
    7)  exit
esac
