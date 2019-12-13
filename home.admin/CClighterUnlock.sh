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
    /usr/local/bin/cliter --config /home/admin/.lighter/config unlocklighter
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
