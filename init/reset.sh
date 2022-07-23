#!/usr/bin/bash

IP=$1
DN=$2

if [ -z "$IP" ] || [ -z "$DN" ]; then
  echo "Usage: $0 <ip> <dn>"
  exit 1
fi

bash cleanup.sh "$IP" "$DN"
bash init.sh "$IP" "$DN"

