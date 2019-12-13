#!/bin/bash

set +e

L_GIT_REF=d/zoe/fixes

L_DATA=/home/admin/.lighter
L_CONFIG=${L_DATA}/config
L_REPO=/home/admin/lighter
L_SERVICE=lighter.service
L_SERVICE_PATH=/etc/systemd/system/${L_SERVICE}
PY_INST_PATH=/usr/local
L_EXAMPLES=${PY_INST_PATH}/share/doc/lighter_bitcoin/examples
COMPLETE_SCRIPT='complete-cliter-bash.sh'
COMPLETE_DEST=/etc/bash_completion.d/${COMPLETE_SCRIPT}
L_PIP_NAME="lighter-bitcoin"

BACKTITLE="RaspiBlitz - Lighter Setup"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "small config script to switch Lighter on or off"
  echo "bonus.lighter.sh [on|off]"
  exit 1
fi

# check and load raspiblitz config
# to know which network is running
source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf
if [ ${#network} -eq 0 ]; then
  echo "FAIL - missing /mnt/hdd/raspiblitz.conf"
  exit 1
fi

# add default value to raspi config if needed
if [ ${#lighter} -eq 0 ]; then
  echo "lighter=off" >> /mnt/hdd/raspiblitz.conf
fi

# stop services
echo "making sure services are not running"
sudo systemctl stop lighter 2>/dev/null

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "*** INSTALL LIGHTER ***"

  isInstalled=$(sudo ls ${L_SERVICE_PATH} 2>/dev/null | grep -c ${L_SERVICE})
  if [ ${isInstalled} -eq 0 ]; then
    set -e

    # download repository
    echo "*** Get Lighter source code ***"
    rm -rf ${L_REPO} 2>/dev/null
    git clone "https://gitlab.com/inbitcoin/lighter" ${L_REPO}
    cd ${L_REPO}
    git reset --hard origin/${L_GIT_REF}
    echo ""

    # install lighter for all implementations
    echo "*** Install Lighter ***"
    mkdir -p ${L_DATA}
    # TODO: add symlink to hdd?
    sudo -u bitcoin mkdir -p /home/bitcoin/.lighter/logs
    sudo pip3 install --upgrade setuptools wheel
    sudo pip3 install .
    # install cliter bash completion
    sudo cp ${L_EXAMPLES}/${COMPLETE_SCRIPT} ${COMPLETE_DEST}
    echo ""

    # prepare lighter config file
    echo "*** Prepare configuration ***"
    cp ${L_EXAMPLES}/config.sample ${L_CONFIG}
    sudo sed -i "s/#implementation =.*/implementation = lnd/g" ${L_CONFIG}
    sudo sed -i "s/#db_dir =.*/db_dir = \/home\/admin\/.lighter\/db/g" ${L_CONFIG}
    sudo sed -i "s/#logs_dir =.*/logs_dir = \/home\/bitcoin\/.lighter\/logs/g" ${L_CONFIG}
    sudo sed -i "s/#tlscert =.*/tlscert = \/home\/admin\/.lighter\/certs\/server.crt/g" ${L_CONFIG}
    sudo sed -i "s/#macaroon =.*/macaroon = \/home\/admin\/.lighter\/macaroons\/admin.macaroon/g" ${L_CONFIG}
    sudo sed -i "s/#lnd_cert_dir =.*/lnd_cert_dir = \/home\/bitcoin\/.lnd/g" ${L_CONFIG}
    echo "Created ${L_CONFIG}"
    echo ""

    # generate certificate
    echo "*** Generate TLS certificate ***"
    mkdir -p ${L_DATA}/certs
    cd ${L_DATA}/certs
    if [ ${#dynDomain} -gt 0 ]; then
        #check if dyndns resolves to correct IP
        ipOfDynDNS=$(getent hosts ${dynDomain} | awk '{ print $1 }')
        if [ "${ipOfDynDNS}" != "${publicIP}" ]; then
          echo "dyndns does not resolve to the correct IP"
        else
          dnsName="${dynDomain}"
        fi
    fi
    if [ -z "$dnsName" ]; then
      openssl req -newkey rsa:2048 -nodes -keyout server.key -x509 -days 365 -out server.crt \
        -subj "/CN=${publicIP}" -extensions SAN \
        -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:localhost,IP:${publicIP},IP:127.0.0.1,IP:::1"))
    else
      openssl req -newkey rsa:2048 -nodes -keyout server.key -x509 -days 365 -out server.crt \
        -subj "/CN=${dnsName}" -extensions SAN \
        -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:${dnsName},DNS:localhost,IP:${publicIP},IP:127.0.0.1,IP:::1"))
    fi
    cd - > /dev/null
    echo ""

    # open firewall
    echo "*** Updating firewall ***"
    sudo ufw allow 1708
    sudo ufw --force enable
    echo "Allowed port 1708"
    echo ""

    set +e
    _temp="/home/admin/download/dialog.$$"
    # ask for lighter password
    echo "*** Asking for Lighter password ***"
    while [ 1 ]; do
      # ask user for new Lighter password (first time)
      dialog --backtitle "${BACKTITLE}" \
        --insecure --passwordbox "Set new Lighter Password:\n(choose something secure)" 10 52 2>$_temp

      # get user input
      password1=$( cat $_temp )
      shred $_temp

      # ask user for new Lighter password (second time)
      dialog --backtitle "${BACKTITLE}" \
        --insecure --passwordbox "Re-Enter Lighter password:\n" 10 52 2>$_temp

      # get user input
      password2=$( cat $_temp )
      shred $_temp

      # check if passwords match
      if [ "${password1}" != "${password2}" ]; then
        dialog --backtitle "${BACKTITLE}" \
          --msgbox "FAIL -> Passwords do not match\nPlease try again ..." 6 52
        continue
      fi

      # password zero
      if [ ${#password1} -eq 0 ]; then
        dialog --backtitle "${BACKTITLE}" \
          --msgbox "FAIL -> Password cannot be empty\nPlease try again ..." 6 52
        continue
      fi

      # use entered password now as parameter
      lighterPassword="${password1}"
      break
    done
    echo ""

    # ask for LND password
    echo "*** Asking for LND password ***"
    while [ 1 ]; do
      # ask user for LND password (first time)
      dialog --backtitle "${BACKTITLE}" \
        --insecure --passwordbox "Insert LND password (C):" 10 52 2>$_temp

      # get user input
      password1=$( cat $_temp )
      shred $_temp

      # ask user for LND password (second time)
      dialog --backtitle "${BACKTITLE}" \
        --insecure --passwordbox "Re-Enter LND password (C):" 10 52 2>$_temp

      # get user input
      password2=$( cat $_temp )
      shred $_temp

      # check if passwords match
      if [ "${password1}" != "${password2}" ]; then
        dialog --backtitle "${BACKTITLE}" \
          --msgbox "FAIL -> Passwords do not match\nPlease try again ..." 6 52
        continue
      fi

      # password zero
      if [ ${#password1} -eq 0 ]; then
        dialog --backtitle "${BACKTITLE}" \
          --msgbox "FAIL -> Password cannot be empty\nPlease try again ..." 6 52
        continue
      fi

      # use entered password now as parameter
      lndPassword="${password1}"
      break
    done
    echo ""
    set -e

    # secure secrets
    echo "*** Secure secrets ***"
    sudo lighter_password=${lighterPassword} create_macaroons=1 \
        lnd_macaroon=/home/admin/.lnd/data/chain/${network}/${chain}net/admin.macaroon lnd_password=${lndPassword} \
        lighter-secure --lighterdir="${L_DATA}"
    echo "Lighter secrets secured"
    echo ""

    # install service
    echo "*** Install Lighter systemd ***"
    sudo cp /home/admin/assets/${L_SERVICE} ${L_SERVICE_PATH}
    sudo systemctl enable lighter
    echo "OK - Lighter is now enabled"
    echo ""

    cd - > /dev/null

  else
    echo "Lighter already installed."
  fi

  # start service
  echo "Starting service"
  sudo systemctl start lighter 2>/dev/null

  # setting value in raspi blitz config
  sudo sed -i "s/^lighter=.*/lighter=on/g" /mnt/hdd/raspiblitz.conf

  set +e
  exit 0
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  # setting value in raspi blitz config
  sudo sed -i "s/^lighter=.*/lighter=off/g" /mnt/hdd/raspiblitz.conf

  isInstalled=$(sudo ls ${L_SERVICE_PATH} 2>/dev/null | grep -c ${L_SERVICE})
  if [ ${isInstalled} -eq 1 ]; then
    echo "*** REMOVING LIGHTER ***"
    sudo systemctl stop lighter
    sudo systemctl disable lighter
    sudo pip3 uninstall -y ${L_PIP_NAME}
    sudo rm -r ${L_REPO}
    sudo rm -r ${L_DATA}
    sudo rm ${COMPLETE_DEST}
    sudo rm ${L_SERVICE_PATH}
    echo "OK - Lighter removed"
  else
    echo "Lighter is not installed."
  fi

  exit 0
fi

echo "FAIL - Unknown Paramter $1"
echo "may needs reboot to run normal again"
exit 1
