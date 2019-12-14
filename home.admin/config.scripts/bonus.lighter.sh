#!/bin/bash

set +e

L_GIT_REF=develop

L_DATA=/home/admin/lighter/lighter-data
L_CONFIG=$L_DATA/config
L_SERVICE=lighter.service

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

  isInstalled=$(sudo ls /etc/systemd/system/${L_SERVICE} 2>/dev/null | grep -c ${L_SERVICE})
  if [ ${isInstalled} -eq 0 ]; then
    set -e

    # download repository
    echo "*** Get Lighter source code ***"
    rm -rf /home/admin/lighter 2>/dev/null
    git clone "https://gitlab.com/inbitcoin/lighter" /home/admin/lighter
    cd /home/admin/lighter
    git reset --hard origin/${L_GIT_REF}
    echo ""

    # install lighter for all implementations
    echo "*** Install Lighter ***"
    make all
    mkdir -p ${L_DATA}/certs
    mkdir -p ${L_DATA}/db
    mkdir -p ${L_DATA}/logs
    mkdir -p ${L_DATA}/macaroons
    # install cliter
    pip3 install --upgrade setuptools wheel
    pip3 install .
    # install cliter bash completion
    set +e
    _CLITER_COMPLETE=source cliter > /tmp/complete-cliter.sh
    set -e
    sudo cp /tmp/complete-cliter.sh /etc/bash_completion.d/
    # install make paring dependencies
    . /home/admin/.virtualenvs/lighter-env/bin/activate
    pip install Pillow
    pip install qrcode
    deactivate
    echo ""

    # prepare lighter config file
    echo "*** Prepare configuration ***"
    cp ${L_DATA}/config.sample ${L_CONFIG}
    sudo sed -i "s/# IMPLEMENTATION=.*/IMPLEMENTATION=lnd/g" ${L_CONFIG}
    sudo sed -i "s/# LND_CERT_DIR=.*/LND_CERT_DIR=\/home\/bitcoin\/.lnd/g" ${L_CONFIG}
    echo "Created ${L_CONFIG}"
    echo ""

    # generate certificate
    echo "*** Generate TLS certificate ***"
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
      openssl req -newkey rsa:2048 -nodes -keyout server.key -x509 -days 365 -out server.crt -subj "/CN=${publicIP}" -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:localhost,IP:${publicIP},IP:127.0.0.1,IP:::1"))
    else
      openssl req -newkey rsa:2048 -nodes -keyout server.key -x509 -days 365 -out server.crt -subj "/CN=${dnsName}" -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:${dnsName},DNS:localhost,IP:${publicIP},IP:127.0.0.1,IP:::1"))
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
    make lighter_password=${lighterPassword} create_macaroons=1 \
        lnd_macaroon=/home/admin/.lnd/data/chain/${network}/${chain}net/admin.macaroon lnd_password=${lndPassword} \
        secure
    echo "Lighter secrets secured"
    echo ""

    # install service
    echo "*** Install Lighter systemd ***"
    sudo cp /home/admin/assets/${L_SERVICE} /etc/systemd/system/${L_SERVICE}
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

  isInstalled=$(sudo ls /etc/systemd/system/${L_SERVICE} 2>/dev/null | grep -c ${L_SERVICE})
  if [ ${isInstalled} -eq 1 ]; then
    echo "*** REMOVING LIGHTER ***"
    sudo systemctl stop lighter
    sudo systemctl disable lighter
    sudo rm /etc/systemd/system/${L_SERVICE}
    sudo rm -r /home/admin/lighter
    echo "OK - Lighter removed"
  else
    echo "Lighter is not installed."
  fi

  # echo "needs reboot to activate new setting"
  exit 0
fi

echo "FAIL - Unknown Paramter $1"
echo "may needs reboot to run normal again"
exit 1
