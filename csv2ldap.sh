#!/usr/bin/bash

FILE=$1
IP=$2
DN=$3

AU_TEMPLATE_FILE=templates/adduser.ldif.template
AG_TEMPLATE_FILE=templates/addgroup.ldif.template
AU2G_TEMPLATE_FILE=templates/adduser2group.ldif.template
U_TEMPLATE_FILE=templates/update.ldif
AU_RENDER_FILE=render/adduser.ldif
AG_RENDER_FILE=render/addgroup.ldif
AU2G_RENDER_FILE=render/adduser2group.ldif
U_RENDER_FILE=render/update.ldif

RENDER_ADD_FILE=render_add.ldif
RENDER_MODIFY_FILE=render_modify.ldif

HEADER=

if [ -z "$FILE" ] || [ -z "$IP" ] || [ -z "$DN" ]; then
	echo "Usage: $0 <file> <ip> <dn>"
	exit 1
fi

while IFS= read -r line; do
	raw_datas=$(echo "$line" | sed 's/"//g' | tr ',' ' ')

	if [ -z "$HEADER" ]; then
		HEADER=($raw_datas)
	else
		BASE_ID=$(cat BASE_ID)
		f=0
		while [ $f -eq 0 ]; do
			l_found=$(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -LLL -b "ou=users,$DN" uidNumber=$BASE_ID | wc -l)


			if [ $l_found -ne 0 ]; then
				echo $(($BASE_ID+1)) > BASE_ID
				BASE_ID=$(cat BASE_ID)
			else
				UID_NUMBER=$BASE_ID
				f=1
			fi
		done

		# RESET VAR.

		ID=
		FIRST_NAME=
		LAST_NAME=
		MAIL_ADDRESS=
		GROUP=
		GROUP2_NAME=
                VPC=
		

		col=0
		for data in $raw_datas; do
			case "${HEADER[$col]}" in
				ID)
					ID=$data
					;;
				FirstName)
					FIRST_NAME=$data
					;;
				LastName)
					LAST_NAME=$data
					;;
				MailAddress)
					MAIL_ADDRESS=$data
					;;
				Admin)
					if [[ $data == true ]]; then
						GROUP2_NAME=ldapadmin
					else
						GROUP2_NAME=ldapstandard
					fi
					;;
                                Client)
                                        VPC=$data
                                        ;;
			esac

			col=$(($col+1))
		done

		TARGET_DN="uid=$ID,ou=users,ou=$VPC,$DN"
		found=$(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -LLL -b "$TARGET_DN" 2> /dev/null)

		if [ $? -eq 0 ]; then # EXIST
			if [[ $(echo "$found" | grep "cn: " | sed 's/cn: //g') != $FIRST_NAME ]]; then
				update=$(cat "$U_TEMPLATE_FILE")
				echo "$update" | \
					sed "s/{{DN}}/$TARGET_DN/" | \
					sed "s/{{ACTION}}/replace/" | \
					sed "s/{{ATTR}}/cn/" | \
					sed "s/{{VALUE}}/$FIRST_NAME/" >> $U_RENDER_FILE

				echo "" >> $U_RENDER_FILE
			fi
			if [[ $(echo "$found" | grep "sn: " | sed 's/sn: //g') != $LAST_NAME ]]; then
				update=$(cat "$U_TEMPLATE_FILE")
				echo "$update" | \
					sed "s/{{DN}}/$TARGET_DN/" | \
					sed "s/{{ACTION}}/replace/" | \
					sed "s/{{ATTR}}/sn/" | \
					sed "s/{{VALUE}}/$LAST_NAME/" >> $U_RENDER_FILE

				echo "" >> $U_RENDER_FILE
			fi

			if [[ $(echo "$found" | grep "mail: " | sed 's/mail: //g') != $MAIL_ADDRESS ]]; then
				update=$(cat "$U_TEMPLATE_FILE")
				echo "$update" | \
					sed "s/{{DN}}/$TARGET_DN/" | \
					sed "s/{{ACTION}}/replace/" | \
					sed "s/{{ATTR}}/mail/" | \
					sed "s/{{VALUE}}/$MAIL_ADDRESS/" >> $U_RENDER_FILE

				echo "" >> $U_RENDER_FILE
			fi

			TARGET_DN="cn=ldapstandard,ou=groups,ou=$VPC,$DN"
			found=$(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -LLL -b "$TARGET_DN" 2> /dev/null)

			if [[ $GROUP2_NAME == ldapadmin ]]; then
				if echo "$found" | grep "memberUid: $ID" &>/dev/null; then
					update=$(cat "$U_TEMPLATE_FILE")
					echo "$update" | \
                                                sed "s/{{DN}}/$TARGET_DN/" | \
						sed "s/{{ACTION}}/delete/" | \
						sed "s/{{ATTR}}/memberUid/" | \
						sed "s/{{VALUE}}/$GROUP2_NAME/" >> $U_RENDER_FILE

					echo "" >> $U_RENDER_FILE
				fi
			elif [[ $GROUP2_NAME == ldapstandard ]]; then
				if ! echo "$found" | grep "memberUid: $ID" &>/dev/null; then
					update=$(cat "$U_TEMPLATE_FILE")
					echo "$update" | \
                                                sed "s/{{DN}}/$TARGET_DN/" | \
						sed "s/{{ACTION}}/add/" | \
						sed "s/{{ATTR}}/memberUid/" | \
						sed "s/{{VALUE}}/$GROUP2_NAME/" >> $U_RENDER_FILE

					echo "" >> $U_RENDER_FILE
				fi
			fi


			TARGET_DN="cn=ldapadmin,ou=groups,ou=$VPC,$DN"
			found=$(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -LLL -b "$TARGET_DN" 2> /dev/null)

			if [[ $GROUP2_NAME == ldapstandard ]]; then
				if echo "$found" | grep "memberUid: $ID" &>/dev/null; then
					update=$(cat "$U_TEMPLATE_FILE")
					echo "$update" | \
                                                sed "s/{{DN}}/$TARGET_DN/" | \
						sed "s/{{ACTION}}/delete/" | \
						sed "s/{{ATTR}}/memberUid/" | \
						sed "s/{{VALUE}}/$GROUP2_NAME/" >> $U_RENDER_FILE

					echo "" >> $U_RENDER_FILE
				fi
			elif [[ $GROUP2_NAME == ldapadmin ]]; then
				if ! echo "$found" | grep "memberUid: $ID" &>/dev/null; then
					update=$(cat "$U_TEMPLATE_FILE")
					echo "$update" | \
                                                sed "s/{{DN}}/$TARGET_DN/" | \
						sed "s/{{ACTION}}/add/" | \
						sed "s/{{ATTR}}/memberUid/" | \
						sed "s/{{VALUE}}/$GROUP2_NAME/" >> $U_RENDER_FILE

					echo "" >> $U_RENDER_FILE
				fi
			fi

			if [ -f "$U_RENDER_FILE" ]; then
				echo -e "# $ID\n" >> $RENDER_MODIFY_FILE
				cat $U_RENDER_FILE >> $RENDER_MODIFY_FILE
				echo "" >> $RENDER_MODIFY_FILE
				>$U_RENDER_FILE
			fi

		else # DOES NOT EXIST
			# copy template then fill it
			cp "$AU_TEMPLATE_FILE" "$AU_RENDER_FILE"
			cp "$AG_TEMPLATE_FILE" "$AG_RENDER_FILE"
			cp "$AU2G_TEMPLATE_FILE" "$AU2G_RENDER_FILE"


			# PARSE adduser.ldif
                        sed -i "s/{{DN}}/ou=$VPC,$DN/" $AU_RENDER_FILE
			sed -i "s/{{ID}}/$ID/g" $AU_RENDER_FILE
			sed -i "s/{{FIRST_NAME}}/$FIRST_NAME/g" $AU_RENDER_FILE
			sed -i "s/{{LAST_NAME}}/$LAST_NAME/g" $AU_RENDER_FILE
			sed -i "s/{{MAIL_ADDRESS}}/$MAIL_ADDRESS/g" $AU_RENDER_FILE
			sed -i "s/{{UID_NUMBER}}/$UID_NUMBER/g" $AU_RENDER_FILE
			sed -i "s/{{GID_NUMBER}}/$UID_NUMBER/g" $AU_RENDER_FILE
			sed -i "s/{{PASSWORD}}/$(bash random_password 16 3)/" $AU_RENDER_FILE

			# PARSE addgrp.ldif (user group)
                        sed -i "s/{{DN}}/ou=$VPC,$DN/" $AG_RENDER_FILE
			sed -i "s/{{GROUP1_NAME}}/$ID/g" $AG_RENDER_FILE
			sed -i "s/{{GROUP1_ID}}/$UID_NUMBER/g" $AG_RENDER_FILE
			cat $AG_RENDER_FILE >> $RENDER_ADD_FILE

			# PARSE adduser2grp
                        sed -i "s/{{DN}}/ou=$VPC,$DN/" $AU2G_RENDER_FILE
			sed -i "s/{{GROUP2_NAME}}/$GROUP2_NAME/g" $AU2G_RENDER_FILE
			sed -i "s/{{ID}}/$ID/g" $AU2G_RENDER_FILE

			echo -e "# $ID\n" >> $RENDER_ADD_FILE
			echo -e "# $ID\n" >> $RENDER_MODIFY_FILE
			cat $AU_RENDER_FILE >> $RENDER_ADD_FILE
			cat $AU2G_RENDER_FILE >> $RENDER_MODIFY_FILE
		fi

		uidlist=$(ldapsearch -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -b "ou=users,ou=$VPC,$DN" | grep "uid=" | sed 's/dn: //g')

		while IFS= read -r line; do
			ID=$(echo "$line" | cut -d',' -f1 | cut -d'=' -f2)
			if ! grep "$ID" data.csv &>/dev/null; then
				ldapdelete -x -w password -D "cn=admin,$DN" -H ldap://$IP/ "$line"
				echo "User $line removed"
			fi
		done <<< "$uidlist"
	fi

done < $FILE

if [ ! -f "$RENDER_ADD_FILE" ] && [ ! -f "$RENDER_MODIFY_FILE" ]; then
	echo "Nothing to do."
else
	echo "Send ldif file to server"
	if [ -f "$RENDER_ADD_FILE" ]; then
		ldapadd -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -f $RENDER_ADD_FILE
	fi
	if [ -f "$RENDER_MODIFY_FILE" ]; then
		ldapadd -x -w password -D "cn=admin,$DN" -H ldap://$IP/ -f $RENDER_MODIFY_FILE
	fi

	echo "Users imported"
fi


bash clear.sh
