#!/bin/bash

#you need to log in to the azure encrypted blob storage to download files
#one way is do this in this script (bad)
#az_login --user ldapbind@pocrcsi.onmicrosoft.com --password=your password 

#alternatively, mkdir $HOME/private; chmod 600 $HOME/private
# store a little file in /home/you/private with these credentials in
# this is OK

#Best: use an application key to delegate only access to the storage in this account
# If the password is somehow taken, access only to the data (or other things the application can 
# access) is stolen.  Still need to keep that password private.

#  method 3 I use here

## log in
$HOME/private/accesshg38
## get the files to the large scratch area
DATADIR=/mnt/resource

cd $DATADIR
$HOME/bin/az_download.sh  SIMPLEDATA.txt


