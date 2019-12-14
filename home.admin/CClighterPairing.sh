#!/bin/bash

clear
echo ""
echo "****************************************************************************"
echo "Pair Lighter --> make pairing"
echo "You may wait some seconds until procedure starts."
echo "****************************************************************************"
cd /home/admin/lighter/
make pairing
cd - > /dev/null
