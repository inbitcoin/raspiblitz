#!/bin/bash

echo "Starting Lighter menu ..."

# CONFIGFILE - configuration of RaspiBlitz
configFile="/mnt/hdd/raspiblitz.conf"

# INFOFILE - state data from bootstrap
infoFile="/home/admin/raspiblitz.info"

# MAIN MENU AFTER SETUP
source ${infoFile}
source ${configFile}

# BASIC MENU INFO
HEIGHT=13
WIDTH=64
CHOICE_HEIGHT=6
BACKTITLE="RaspiBlitz"
TITLE="Lighter options"
MENU="Choose one of the following options:"
OPTIONS=()
plus=""
if [ "${runBehindTor}" = "on" ]; then
  plus=" / TOR"
fi
if [ ${#dynDomain} -gt 0 ]; then
  plus="${plus} / ${dynDomain}"
fi
localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
BACKTITLE="${localip} / ${hostname} / ${network} / ${chain}${plus}"

# Basic Options
OPTIONS+=(UNLOCK "Unlock Lighter" \
  LOCK "Lock Lighter" \
  PAIRING "Start Lighter pairing procedure"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

#clear
case $CHOICE in
        UNLOCK)
            ./CClighterUnlock.sh
            echo "Press ENTER to return to Lighter menu."
            read key
            ./CClighter.sh
            ;;
        LOCK)
            ./CClighterLock.sh
            echo "Press ENTER to return to Lighter menu."
            read key
            ./CClighter.sh
            ;;
        PAIRING)
            ./CClighterPairing.sh
            echo "Press ENTER to return to Lighter menu."
            read key
            ./CClighter.sh
            ;;
esac
