#!/usr/bin/bash

IP=$1
DN=$2

if [ -z "$IP" ] || [ -z "$DN" ]; then
  echo "Usage: $0 <ip> <dn>"
  exit 1
fi

echo "Remove ou=users .."
for i in $(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP -b "$DN" | grep "dn:" | grep "ou=users,$DN" | sed 's/dn: //g' | tac); do
	ldapdelete -x -w password -D "cn=admin,$DN" -H ldap://$IP/ "$i"
done

echo "Remove ou=groups .."
for i in $(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP -b "$DN" | grep "dn:" | grep "ou=groups,$DN" | sed 's/dn: //g' | tac); do
	ldapdelete -x -w password -D "cn=admin,$DN" -H ldap://$IP/ "$i"
done

echo "10000" > ../BASE_ID

echo "Done"
