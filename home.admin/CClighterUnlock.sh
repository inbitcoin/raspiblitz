#!/bin/bash

clear
echo ""
echo "****************************************************************************"
echo "Unlock Lighter --> cliter unlocklighter"
echo "****************************************************************************"
echo "HELP: Enter your Lighter PASSWORD"
echo "You may wait some seconds until you get asked for password."
echo "****************************************************************************"
while :
  do
    sudo -u bitcoin /usr/local/bin/cliter \
      --tlscert /home/admin/lighter/lighter-data/certs/server.crt \
      --macaroon /home/admin/lighter/lighter-data/macaroons/admin.macaroon \
      unlocklighter > /dev/null
    ecode="$?"
    echo ""

    if [ ${ecode} -eq 0 ]; then
      echo "Successfully unlocked"
      break
    fi

    if [ ${ecode} -eq 1 ]; then
      echo "Cliter failed - try to reinstall Lighter"
      break
    fi

    if [ ${ecode} -eq 80 ]; then
      echo "Lighter was already unlocked"
      break
    fi

    echo "Lighter is still locked - please try again or"
    echo "Cancel with CTRL+C - back to setup with command: raspiblitz"
    sleep 4
  done
