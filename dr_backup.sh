#!/bin/bash

#Run gpg --list-keys to find the id of the key you generated
export GPG_KEY=BE25A3C4
#The super secret password you setup earlier
export PASSPHRASE='SUPER_LONG_$ECRET_PA55WORD'
#The email address you want to be alerted at
export TOEMAIL='YOUR@EMAIL.COM'
#Where you put the keys earlier
export GNUPGHOME=/usr/local/etc/gpg

#################################
# Main Code - No need to change #
#################################
function send_email {
	SUBJECT=$2
	if [ -z $SUBJECT ]; then
		SUBJECT="Backup Failed"
	fi

	echo "$1"
	echo "$1" | \
        mailx -s "$SUBJECT" -t $TOEMAIL
}

MNTPT=$1

if [ -z "$MNTPT" ]; then
	send_email "no mount point passed in $?"
	exit 1
fi

if [ ! -d "$MNTPT" ]; then
	send_email "mount point does not exist $?"
	exit 2
fi

if [ ! -d "$MNTPT/backup" ]; then
	send_email "Please make a directory called 'backup' on the drive"
	exit 3
fi

rm -rf $MNTPT/backup/gpg

cp -r $GNUPGHOME $MNTPT/backup
if [ $? -ne 0 ]; then
	send_email "backup of gpg key failed $?"
	exit 4
fi

mkdir -p $MNTPT/backup/duplicity
if [ $? -ne 0 ]; then
	send_email "unable to create directory $?"
	exit 5
fi



#Attempt to backup to the removable storage drive first, if it exists
duplicity \
	--include-globbing-filelist /usr/local/etc/backup.config \
	--full-if-older-than 7D \
	--asynchronous-upload \
	--encrypt-key=$GPG_KEY \
	--sign-key=$GPG_KEY \
	/ file://$MNTPT/backup/duplicity

if [ $? -ne 0 ]; then
	send_email "back up to external drive returned $?"
	exit 6
fi

duplicity \
	cleanup \
	--force \
	file://$MNTPT/backup/duplicity
	
if [ $? -ne 0 ]; then
	send_email "cleanup of external drive returned $?"
	exit 7
fi

duplicity \
	remove-all-but-n-full 4 \
	--force \
	file://$MNTPT/backup/duplicity
	
if [ $? -ne 0 ]; then
	send_email "trimming of external drive returned $?"
	exit 8
fi

umount $MNTPT
if [ $? -ne 0 ]; then
	send_email "unable to unmount the drive $?"
	exit 9
fi

rmdir $MNTPT
if [ $? -ne 0 ]; then
	send_email "unable to remove the mount point $?"
	exit 10
fi
