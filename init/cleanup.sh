#!/usr/bin/bash

IP=$1
DN=$2

if [ -z "$IP" ] || [ -z "$DN" ]; then
  echo "Usage: $0 <ip> <dn>"
  exit 1
fi

echo "Remove $DN content .."
for i in $(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP -b "$DN" | grep "dn:" | grep "$DN" | sed 's/dn: //g' | grep -v "^$DN$" | tac); do
	ldapdelete -x -w password -D "cn=admin,$DN" -H ldap://$IP/ "$i"
done

rm -f ../BASE_ID/*

echo "Done"
