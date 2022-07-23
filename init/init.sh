#!/usr/bin/bash

IP=$1
DN=$2

if [ -z "$IP" ] || [ -z "$DN" ]; then
  echo "Usage: $0 <ip> <dn>"
  exit 1
fi

TEMPLATE_PATH="$(pwd)/ldifs/templates"
RENDER_PATH="$(pwd)ldifs/render"

mkdir -p $RENDER_PATH

cp $TEMPLATE_PATH/addou.ldif $RENDER_PATH/
cp $TEMPLATE_PATH/addstaticgrp.ldif $RENDER_PATH/

sed -i "s/<##DN##>/$DN/g" $RENDER_PATH/addou.ldif
sed -i "s/<##DN##>/$DN/g" $RENDER_PATH/addstaticgrp.ldif

echo "Add ou .."
ldapadd -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -f $RENDER_PATH/addou.ldif

echo "Add groups .."
ldapadd -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -f $RENDER_PATH/addstaticgrp.ldif

#echo "Add default user .."
#ldapadd -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -f $RENDER_PATH/adddefaultuser.ldif

rm -rf $RENDER_PATH

echo "Done"
