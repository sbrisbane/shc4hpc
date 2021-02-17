#!/bin/bash -x
SLURMMASTER=""
test -f /etc/sysconfig/shc4hpc && . /etc/sysconfig/shc4hpc
[ -n $SHC4HPCBASE ] && [ -f  $SHC4HPCBASE/etc/shc4hpc/environment ] && . $SHC4HPCBASE/etc/shc4hpc/environment
[ -n $SHC4HPCBASE ] &&  [ -f  $SHC4HPCBASE/lib/core/functions ] && . $SHC4HPCBASE/lib/core/functions


#Attemp to Add Name Resolution for Azure Peering # HACK
#sed -i '/search/ s/$/ trad.shc4hpc cloud.shc4hpc/' /etc/resolv.conf
dnsdomainname > /etc/resolv.conf.dnsname

function getnodename(){
   NAME=$(get_cloudconfig_string nodename)
   if [ -z $NAME ]; then 
      NAME=$(hostname -s)
   fi
   echo $NAME
}
function getmaster()
{
   testn=`get_cloudconfig_string slurmmaster`
   if [ -z $testn ];then
      test=`get_cloudconfig_string master`
      if [ yes = "$test" ] ;then
          testname=$(getnodename)
           if [ -z $testname ]; then
               hostname -s
           else
               echo $testname
           fi
      fi
   else 
      echo $testn
   fi
}
function dump_sl_vars() {
	ifs=$IFS
	sl_vars=$(get_cloudconfig_string sl_vars)
        IFS=":"
	for var in $sl_vars; do 
		echo "$var: $(get_cloudconfig_or_changeme $var)"
	done
}
function getos_auth_url() {
get_cloudconfig_string os_auth_url
#"http://osmgmt01.hpc.securelinx.com:5000/v3/"
}
function getos_project_name () {
get_cloudconfig_string os_project_name
}
function getos_os_net_id () {
get_cloudconfig_string os_net_id
}
function getos_ironic_net_id () {
get_cloudconfig_string ironic_net_id
}
function getos_user_domain_name () {
get_cloudconfig_string os_user_domain_name
}
function getos_username () {
get_cloudconfig_string os_username
}
function getos_password () {
get_cloudconfig_string os_password
}
function getos_region_name () {
get_cloudconfig_string os_region_name
}
function getos_project_id () {
get_cloudconfig_string os_project_id
}
function getaz_vpn_server () {
    get_cloudconfig_string az_vpn_server
}
function getaz_vpn_server_internal () {
    get_cloudconfig_string az_vpn_server_internal
}
getos_subnet () {
    get_cloudconfig_string os_subnet
}
getaz_subnet () {
    get_cloudconfig_string az_subnet
}
getvpn_subnet () {
    get_cloudconfig_string vpn_subnet
}
function getnfsmaster() {
   get_cloudconfig_string nfsmaster
}
function getheadnode_ip() {
   getent hosts headnode | awk '{print $1}'
}
function getntpserver() {

	tmp=$(get_cloudconfig_string ntpserver)
	if [ -z "$tmp" ]; then
		echo "0.fedora.pool.ntp.org"
	fi
}
function getaz_goldenimage() {
  get_cloudconfig_string az_goldenimage
}
function getaz_os_router () {
    get_cloudconfig_string az_os_router
}
function getos_az_router () { 
    get_cloudconfig_string os_az_router
}
function master_is_vpn_client ()
{
	#default to not using a hacky vpn dfor demos
	tmp=$(get_cloudconfig_string master_is_vpn_client)
	if [ -n "$tmp" ]; then
		echo "$tmp"
	else
		echo 0
	fi
}
function getldap_realm () {
   get_cloudconfig_or_changeme ldap_realm     
}
function getldap_join_account () {
   get_cloudconfig_or_changeme ldap_join_account     
}

function getip(){
    ip -4 addr show scope global dev eth0  | grep "scope global" | awk '{print $2}' | awk -F / '{print $1}' | head -1
}
function AmMaster () 
{
   NAME=$(getnodename)

   if [ "$SLURMMASTER" == "$NAME" ] ;then
        return 0
   fi
   return 1
}
function getos_goldenimage()
{
    get_cloudconfig_string os_goldenimage
}

function getactive_queues()
{
	arrstr=$(get_cloudconfig_string active_queues)
	if [ -n "$arrstr" ]; then
            echo ${arrstr/\,/ }	
	else 
		 echo all
	fi
}
##################################
if [ -f /var/lib/waagent/CustomData ]; then 
    base64 --decode /var/lib/waagent/CustomData > /tmp/usr_data.txt
    #waagent doesnt support a lot out of the box,
    #timezone we need to work around
    TZ=$(get_cloudconfig_string timezone)
    timedatectl set-timezone "${TZ}"
else
    /bin/cp -f /var/lib/cloud/instance/user-data.txt /tmp/usr_data.txt
    #curl -o /tmp/usr_data.txt "http://169.254.169.254/1.0/user-data"    
fi
if ! [ /tmp/usr_data.txt ]; then
       echo get user data failed
fi
cat /tmp/usr_data.txt
#TODO get slurmmaster from user data
SLURMMASTER=$(getmaster)
NODENAME=$(getnodename)
#TODO remove this hack + test
setenforce 0
/bin/sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
NTPSERVER=$(getntpserver)
echo "NTPSERVER is $NTPSERVER"
if [ -n "$NTPSERVER" ]; then
   ntpdate "$NTPSERVER" &
   sleep 15
fi
IP=`getip`



if ! [[ $SLURMMASTER ]]; then
   echo FAILED TO GET slurmmaster from user data 
fi
if ! [[ $NODENAME ]]; then
   echo FAILED TO GET nodename from user data 
fi




NFSMASTER=`getnfsmaster`
#if i am master
res=0

LDAPREALM=changeme
LDAPREALMTMP=`getldap_realm`
if ! [ -z "$LDAPREALMTMP" ]; then
      LDAPREALM="$LDAPREALMTMP"
fi
LDAPJOINACCOUNT=ldapbind
LDAPJOINACCOUNT_TMP=`getldap_join_account`
if ! [ -z "$LDAPJOINACCOUNT_TMP" ]; then
      LDAPJOINACCOUNT="$LDAPJOINACCOUNT_TMP"
fi
  
ACTASVPN=$(master_is_vpn_client)

    AZ_SUBNET="10.0.3.0/24"
    AZ_SUBNET_TMP=`getaz_subnet`
    if ! [ -z "$AZ_SUBNET_TMP" ]; then
       AZ_SUBNET="$AZ_SUBNET_TMP"
    fi

    OS_SUBNET="10.10.10.0/24"
    OS_SUBNET_TMP=`getos_subnet`
    if ! [ -z "$OS_SUBNET_TMP" ]; then
       OS_SUBNET="$OS_SUBNET_TMP"
    fi
    
    VPN_SUBNET="10.8.0.0/24"
    VPN_SUBNET_TMP=`getvpn_subnet`
    if ! [ -z "$VPN_SUBNET_TMP" ]; then
       VPN_SUBNET="$VPN_SUBNET_TMP"
    fi
  
    OS_AZ_ROUTER=`getheadnode_ip`
    OS_AZ_ROUTER_TMP=`getos_az_router`
    if ! [ -z "$OS_AZ_ROUTER_TMP" ]; then
       OS_AZ_ROUTER="$OS_AZ_ROUTER_TMP"
    fi

    AZ_OS_ROUTER="$AZ_VPN_SERVER_INTERNAL"
    AZ_OS_ROUTER_TMP=`getaz_os_router`
    if ! [ -z "$AZ_OS_ROUTER_TMP" ]; then
       AZ_OS_ROUTER="$AZ_OS_ROUTER_TMP"
    fi

#########Now, Im done ############
if AmMaster; then

mkdir -p /home/configs/scripts/tweaks
echo /bin/cp /home/configs/slurm.conf.template /etc/slurm/slurm.conf >> /home/configs/scripts/tweaks

systemctl enable --now mariadb
cat << EOF > /root/initdb.sql
CREATE USER slurm@localhost IDENTIFIED BY 'slurm';
create database slurm_acct_db;
grant all on slurm_acct_db.* TO 'slurm'@'localhost' identified by 'slurm' with grant option;
FLUSH PRIVILEGES;
EOF

cat << EOF > /root/.my.cnf
[mysql]
user=root
password=

EOF

chmod 600 /root/initdb.sql
chmod 600 /root/.my.cnf
db_root_password=testing

mysql  < /root/initdb.sql

myql --user=root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF 

cat << EOF > /root/.my.cnf
[mysql]
user=root
password=${db_root_password}

EOF


        mkdir -p /home/software/slurm/configs/etc/
        chmod 600 /etc/slurm/slurmdbd.conf
        #chown slurm: /etc/slurm/slurmdbd.conf
        #/bin/cp -p /etc/slurm/slurmdbd.conf /home/software/slurm/configs/etc/
    	if [ -f /usr/lib/systemd/system/slurmdbd.service ]; then

	     systemctl daemon-reload
	     systemctl enable --now slurmdbd
             sleep 2
        fi

    #make templates for nodes
    mkdir -p /home/configs/scripts
    mkdir -p /var/log/slurm
    mkdir -p /var/spool/slurm/ctld
    chown slurm: /var/log/slurm /var/spool/slurm/ctld
 
    if [ -f /home/configs/slurm.conf.template ]; then mv /home/configs/slurm.conf.template /home/configs/slurm.conf.template.old; fi 

    echo ControlMachine=$SLURMMASTER   | sudo tee -a /home/configs/slurm.conf.template
    echo SuspendExcNodes=$SLURMMASTER  | sudo tee -a /home/configs/slurm.conf.template
    if [ -f /etc/slurm/slurm.conf.template ] ; then cat  /etc/slurm/slurm.conf.template | sudo tee -a /home/configs/slurm.conf.template; fi
    #generate my nodes

    


    if [ "$(hostname -s)" == "${NODENAME}" ]; then
        update_hosts  "${IP}" "$(hostname -s)" "$(hostname -f)"
    else
        update_hosts  "${IP}" "${NODENAME}" "$(hostname -s)" "$(hostname -f)"
    fi
    echo '/home *(sec=sys,no_root_squash,rw)' >> /etc/exports
    mkdir /home/configs
    chmod 755 /home/configs
    cp -p /etc/hosts /home/configs/hosts_base
    cp -p /etc/hosts /home/configs/hosts_hnbase
    cp -p /etc/hosts /home/configs/hosts_headnode
    cp -p /etc/hosts /home/configs/hosts_node
    /bin/rm -f /etc/hosts && ln -s /home/configs/hosts_headnode /etc/hosts
    if [[ -x /usr/bin/zypper ]]; then
	NFS_UNIT=nfsserver
    else
	NFS_UNIT=nfs
    fi
    systemctl start $NFS_UNIT
    systemctl enable $NFS_UNIT

    #TODO, work this out
    chmod a+x /home/*
    chmod a+x /home/*/.ssh
    chmod a+r /home/*/.ssh/authorized_keys


    #Variables that MUST be set ideally on launch
    OS_GIM=`getos_goldenimage`
    AZ_GIM=`getaz_goldenimage`
    OS_PROJECT_ID=`getos_project_id`
    OS_USERNAME=`getos_username`
    OS_PASSWORD=`getos_password`
    OS_AUTH_URL=`getos_auth_url`
    AZ_VPN_SERVER=`getaz_vpn_server`
    AZ_VPN_SERVER_INTERNAL=`getaz_vpn_server_internal`
    #Is this even useful
    OS_USER_DOMAIN_NAME=Default  

   
    #Some with overridable values
    OS_REGION_NAME="RegionOne"
    OS_REGION_NAME_TMP=`getos_region_name`
    if ! [ -z "$OS_REGION_NAME_TMP" ]; then
         OS_REGION_NAME="$OS_REGION_NAME_TMP"
    fi

    OS_PROJECT_NAME=packer_cloud
    OS_PROJECT_NAME_TMP=`getos_project_name`
    if ! [ -z "$OS_PROJECT_NAME_TMP" ]; then
         OS_PROJECT_NAME="$OS_PROJECT_NAME_TMP"
    fi

mkdir -p /etc/shc4hpc
ln -s $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf /etc/shc4hpc/shc4hpc.conf
cat << EOF >> $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf
os_auth_url: $OS_AUTH_URL 
os_project_id: $OS_PROJECT_ID
os_user_domain_name: $OS_USER_DOMAIN_NAME
os_project_name: $OS_PROJECT_NAME
os_net_id: $(get_cloudconfig_or_changeme os_net_id )
ironic_net_id: $(get_cloudconfig_or_changeme ironic_net_id )
os_username: $OS_USERNAME
os_password: $OS_PASSWORD
os_region_name: $OS_REGION_NAME
os_goldenimage: $OS_GIM
az_goldenimage: $AZ_GIM
az_vpn_server: $AZ_VPN_SERVER
az_subnet: $AZ_SUBNET
os_subnet: $OS_SUBNET
vpn_subnet: $VPN_SUBNET
os_az_router: $OS_AZ_ROUTER
az_os_router: $AZ_OS_ROUTER
az_resource_group: $(get_cloudconfig_or_changeme az_resource_group)
az_image_rg: $(get_cloudconfig_or_changeme az_image_rg)
az_net_rg: $(get_cloudconfig_or_changeme az_net_rg)
az_vnet_name: $(get_cloudconfig_or_changeme az_vnet_name)
az_subnet_name: $(get_cloudconfig_or_changeme az_subnet_name)
az_app_id: $(get_cloudconfig_or_changeme az_app_id)
az_app_secret: $(get_cloudconfig_or_changeme az_app_secret)
az_subscription_id: $(get_cloudconfig_or_changeme az_subscription_id)
az_tenant_id: $(get_cloudconfig_or_changeme az_tenant_id)
az_region: $(get_cloudconfig_or_changeme az_region)
nfsmaster: ${NFSMASTER}
ldaprealm: ${LDAPREALM}
ldapjoinaccount: ${LDAPJOINACCOUNT}
ntpserver: ${NTPSERVER}
az_vm_template: $(get_cloudconfig_or_changeme az_vm_template)
EOF
dump_sl_vars >> $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf
if [ -n "${NFSMASTER}" ]; then
      echo  	nfsmaster: ${NFSMASTER} >> $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf
else
      echo nfsmaster: $(getip) >> $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf 
fi
ACTASVPN=$(master_is_vpn_client)
if [ "1" = "$ACTASVPN" ]; then
    mkdir -m 700 -p /var/tmp/openvpn/client
    tar xf /openvpn-cs.tar -C /var/tmp/openvpn
    cat << EOF > /etc/openvpn/client.conf
client
dev tun
proto tcp
remote $AZ_VPN_SERVER 443
resolv-retry infinite
nobind
persist-key
persist-tun
comp-lzo yes
cipher AES-256-CBC
verb 7
remote-cert-tls server
ca /etc/openvpn/client/ca.crt
cert /etc/openvpn/client/osmaster.crt
key /etc/openvpn/client/osmaster.key
EOF
    cp /var/tmp/openvpn/testvpn/*.crt /etc/openvpn/client/
    cp /var/tmp/openvpn/testvpn/*.key /etc/openvpn/client/
    #firewall-cmd --add-masquerade
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/routing.conf
    sysctl -p
    systemctl enable openvpn@client
    systemctl start  openvpn@client
fi
    queues=$(getactive_queues)
    notazure=1
    notazures=1
    notosk=1
    notbm=1
    notkvm=1
    for i in $queues; do 
       if [ $i = all ]; then
           notazure=0
           notazures=0
           notosk=0
           notbm=0
	   notkvm=0
	   #disabled by default
	   #sed -i  's/#PartitionName=kvm/PartitionName=kvm/' /home/configs/slurm.conf.template
       elif [ $i = azure ];then
	   notazure=0
       elif [ $i = bm ] || [ $i = bare ] || [ $i = metal ];then
	   notbm=0
       elif [ $i = osk ];then
	   notosk=0
       elif [ $i = azures ];then
	   notazures=0
       elif [ $i = kvm ];then
	   notkvm=0
	   #disabled by default
	   #sed -i  's/#PartitionName=kvm/PartitionName=kvm/' /home/configs/slurm.conf.template
       fi
    done

    if [ "$notosk" -eq 0 ];then
    #TODO, update this error checking
        if  [ -z $OS_GIM ] || [ -z $OS_USERNAME ] || [ -z "$OS_PASSWORD" ] || [ -z $OS_AUTH_URL ] || [ -z $OS_PROJECT_NAME ]; then
           echo "You will need to set some variables manuallly in $SHC4HPCBASE/etc/shc4hpc/shc4hpc.conf"
        fi
    fi
    if [ $notazure -eq 1 ]; then
         sed -i  's/PartitionName=azure/#PartitionName=azure/' /home/configs/slurm.conf.template
    fi
    if [ $notbm -eq 1 ]; then
         sed -i  's/PartitionName=metal/#PartitionName=metal/' /home/configs/slurm.conf.template
    fi
    if [ $notkvm -eq 1 ]; then
         sed -i  's/PartitionName=kvm/#PartitionName=kvm/' /home/configs/slurm.conf.template
    fi
    #make the azure queue that boots small vms the default
    if [ $notosk -eq 1 ]; then
         sed -i  's/PartitionName=openstack/#PartitionName=openstack/' /home/configs/slurm.conf.template
	 if [ $notazures -eq 1 ]; then
	    sed -i  's/PartitionName=kvm Default=NO/PartitionName=kvm Default=YES/' /home/configs/slurm.conf.template
         else
	    sed -i  's/PartitionName=azures Default=NO/PartitionName=azures Default=YES/' /home/configs/slurm.conf.template
         fi
    fi

    rsync -a /usr/lib/shc4hpc/roottemplate/ /root/
    echo NodeName=$NODENAME       | sudo tee /etc/slurm/slurm.conf
    cat /home/configs/slurm.conf.template | sudo tee -a /etc/slurm/slurm.conf
    mkdir -p /home/software/slurm/configs/etc/
    rsync -a /etc/slurm/ /home/software/slurm/configs/etc/
    #/sbin/service slurmctld restart


#any pre-loaded keys, from the image, stored in authorized_keys2 
#authorized_keys gets wiped in several places before now.
cat /root/.ssh/authorized_keys2 >> /root/.ssh/authorized_keys
/bin/rm -f /root/.ssh/authorized_keys2
ln /root/.ssh/authorized_keys /root/.ssh/authorized_keys2

else
/bin/rm -f /etc/slurm/slurmdbd.conf
#NOT THE MASTER...

#    AZ_SUBNET="10.0.3.0/24"
#    OS_SUBNET="10.10.10.0/24"
#    VPN_SUBNET="10.8.0.0/24"
#    OS_AZ_ROUTER=`getheadnode_ip`
#    AZ_OS_ROUTER="$AZ_VPN_SERVER_INTERNAL"
# This is completely unnecessary on the azure side as the vpn server can act as a virtual appliance for the azure lan .. Ill leave this here as a history
#if [ "1" = "$ACTASVPN" ]; then
#
#    ip route add "$OS_SUBNET" via "$AZ_OS_ROUTER" dev eth0 
#fi

    sudo sed -i 's|.* /home.*||' /etc/fstab 
    echo $NFSMASTER:/home /home nfs vers=3 0 0  >> /etc/fstab
    
    mount -a
    /bin/rm -f /etc/hosts
    if ! imOpenStack; then 
        ln -s /home/configs/hosts_node /etc/hosts
    else
        ln -s /home/configs/hosts_headnode /etc/hosts 
    fi
    if ! imMetal; then
        if [ "$(hostname -s)" == "${NODENAME}" ]; then
            update_hosts  "${IP}" "$(hostname -s)" "$(hostname -f)"
        else
            update_hosts  "${IP}" "${NODENAME}" "$(hostname -s)" "$(hostname -f)"
        fi
    fi
    /bin/rm  -f /openvpn-cs.tar
    /bin/rm -fr /var/tmp/openvpn

    #any pre-loaded keys, from the image, stored in authorized_keys2 
    #authorized_keys gets wiped in several places before now.
    rsync -a /usr/lib/shc4hpc/roottemplate/ /root/
    #-N in slurmd options now
    #echo NodeName=$NODENAME       | sudo tee /etc/slurm/slurm.conf
    cat /home/configs/slurm.conf.template | sudo tee -a /etc/slurm/slurm.conf
   
    if  [ -f /home/configs/scripts/tweaks ];then
       /home/configs/scripts/tweaks
    fi



    #more reusable on SUSE for example to use service
    id slurm || useradd -u 1001 slurm
    /sbin/service slurmd stop
    echo  "SLURMD_OPTIONS='-b -N ${NODENAME} --conf-server ${SLURMMASTER}:6817 '" >> /etc/sysconfig/slurmd
    #/sbin/service slurmd start
    
    if  [ -f /home/configs/scripts/tweaks ];then
       #slurmd should start at end of this
       /home/configs/scripts/tweaks
       res=$(( $res + $? ))
    fi

  
    


    # Bare metal nodes use external and fixed IP
    if ! imMetal $NODENAME ; then
       $SLURMBASE/bin/scontrol update NodeName=$NODENAME NodeAddr=$IP
    fi
    res=$(( $res + $? ))
    sudo systemctl enable  slurmd
    pgrep slurmd || sudo systemctl start slurmd
    res=$(( $res + $? ))
    if [ $res -eq 0 ]; then
        touch /home/configs/nodehealth/$nodename
    fi
################################
fi
    #join the realm

if [ -z "$LDAPJOINACCOUNT" ] || [ changeme = $LDAPJOINACCOUNT ];then
	    echo "Not joining ldap realm, check ldap_join account, keytab and ldap_realm"
else

       realm discover -v "$LDAPREALM"
       export KRB5CCNAME=/tmp/test
       kinit "$LDAPJOINACCOUNT@$LDAPREALM" -kt /etc/"${LDAPJOINACCOUNT}.keytab"
       realm join --verbose $LDAPREALM
       res=$(( $res + $? ))
       /bin/rm -f $KRB5CCNAME
       rm -f /etc/${LDAPJOINACCOUNT}.keytab
       unset KRB5CCNAME
fi

##################################
