#!/bin/bash

clear
echo ""
echo "****************************************************************************"
echo "Lock Lighter --> cliter locklighter"
echo "****************************************************************************"
echo "HELP: Enter your Lighter PASSWORD"
echo "You may wait some seconds until you get asked for password."
echo "****************************************************************************"
while :
  do
    sudo -u bitcoin /usr/local/bin/cliter \
      --tlscert /home/admin/lighter/lighter-data/certs/server.crt \
      --macaroon /home/admin/lighter/lighter-data/macaroons/admin.macaroon \
      locklighter > /dev/null
    ecode="$?"
    echo ""

    if [ ${ecode} -eq 0 ]; then
      echo "Successfully locked"
      break
    fi

    if [ ${ecode} -eq 1 ]; then
      echo "Cliter failed - try to reinstall Lighter"
      break
    fi

    if [ ${ecode} -eq 76 ]; then
      echo "Lighter was already locked"
      break
    fi

    echo "Lighter is still unlocked - please try again or"
    echo "Cancel with CTRL+C - back to setup with command: raspiblitz"
    sleep 4
  done
