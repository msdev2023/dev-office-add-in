#!/bin/bash
#Ubuntu 20.04 Hardening Script
# Mounnt Ponits apart from /tmp should be configured Manually
#Developed By Rajkumar Madnoli
#Version 1

cls()
{
 sleep 5
 clear
}
echo -e "Disable unused filesystems.. \nCIS Rule: 1.1.1 to 1.1.7"

UNUSED_FILESYSTEM=(cramfs freevxfs jffs2 hfs hfsplus squashfs udf usb-storage)
MODEPROBE="/etc/modprobe.d/CIS.conf"
> $MODEPROBE
for i in ${UNUSED_FILESYSTEM[@]}
do 
	echo "install ${i} /bin/true" >> $MODEPROBE
done

for i in ${UNUSED_FILESYSTEM[@]}
do
	rmmod $i 2>/dev/null
done 
cls


echo -e "Configuring the /tmp Mount Point \n CIS Rule: 1.1.2 to 1.1.5 "
cat > /etc/systemd/system/tmp.mount << "EOF"
[Mount]
 What=tmpfs
 Where=/tmp
 Type=tmpfs
 Options=mode=1777,strictatime,nosuid,nodev,noexec,,size=8G
EOF
systemctl daemon-reload
systemctl --now enable tmp.mount
cls




echo -e "Ensure /dev/shm is configured\n CIS Rule: 1.1.6 to 1.1.9 "
echo "tmpfs /dev/shm tmpfs defaults,noexec,nodev,nosuid,seclabel 0 0" >> /etc/fstab
mount -a
if [[ $? -ne 0 ]] 
then 
 echo "Problem in Fstab.. exiting the script"
 exit 1
 fi
cls


echo -e "CIS Ruel:1.1.10 to 1.1.18 Will be implemented manually as these rules need to added in fstab"
cls


echo "CIS Rule: 1.1.19 to 1.1.21 are related to Removable media, hence Not imepleneting"
cls

echo -e "Ensure sticky bit is set on all world-writable directories.\nCIS Rule:1.1.22"
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null | xargs -I '{}' chmod a+t '{}'
cls




echo "CIS Rule: 1.1.23 Disable Automounting (Automated"
systemctl --now disable autofs 2>/dev/null
apt purge autofs -y 2>/dev/null
cls


echo "CIS Rule: 1.1.24 Disable USB Storage"
cls

echo "CIS Rule: 1.2.1 Ensure package manager repositories are configured...  Manually Configured"
echo "CIS Rule: 1.2.2 Ensure GPG keys are configured...  Manually Configured"
cls


echo "CIS Rule: 1.3 Filesystem Integrity Checking"
echo "CIS Rule: 1.3.1 Ensure AIDE is installed"
apt install aide aide-common -y 
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "CIS Rule: 1.3.2 Ensure filesystem integrity is regularly checked"

cat > /etc/systemd/system/aidecheck.service << "EOF"
[Unit]
Description=Aide Check
[Service]
Type=simple
ExecStart=/usr/bin/aide.wrapper --config /etc/aide/aide.conf --check
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/aidecheck.timer << "EOF"
[Unit]
Description=Aide check every day at 5AM
[Timer]
OnCalendar=*-*-* 05:00:00
Unit=aidecheck.service
[Install]
WantedBy=multi-user.target
EOF

chown root:root /etc/systemd/system/aidecheck.*
chmod 0644 /etc/systemd/system/aidecheck.*
systemctl daemon-reload
systemctl enable aidecheck.service
systemctl --now enable aidecheck.timer
cls


echo "CIS Rule: 1.4 Secure Boot Settings"
echo "CIS Rule: 1.4.1 Ensure permissions on bootloader config are not overridden.. NOT IMPLEMENTING"
echo "CIS Rule: 1.4.2 Ensure bootloader password is set.. NOT IMPLEMENTING"
echo "CIS Rule: 1.4.3 Ensure permissions on bootloader config are configured"
chown root:root /boot/grub/grub.cfg
chmod u-wx,go-rwx /boot/grub/grub.cfg
echo "CIS Rule: 1.4.4 Ensure authentication required for single user mode"
echo root:L!nux@123 | chpasswd
cls



echo "CIS Rule: 1.5 Additional Process Hardening"
echo "CIS Rule: 1.5.1 Ensure XD/NX support is enabled .. Already enabled"
echo "CIS Rule: 1.5.2 Ensure address space layout randomization (ASLR) is enabled"
echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
sysctl -w kernel.randomize_va_space=2
echo "CIS Rule: 1.5.3 Ensure prelink is not installed"
prelink -ua 2>/dev/null
apt purge prelink -y 2>/dev/null
echo "CIS Rule: 1.5.4 Ensure core dumps are restricted"
echo "* hard core 0" >> /etc/security/limits.conf
echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
sysctl -w fs.suid_dumpable=0
cls

echo "CIS Rule: 1.6 Mandatory Access Control"
echo "CIS Rule: 1.6.1 Configure AppArmor"
echo "CIS Rule: 1.6.1.1 Ensure AppArmor is installed"
apt install apparmor -y
echo "CIS Rule: 1.6.1.2 Ensure AppArmor is enabled in the bootloader configuration"
echo 'GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor"' >> /etc/default/grub
update-grub
echo "CIS Rule: 1.6.1.3 Ensure all AppArmor Profiles are in enforce or complain mode"
aa-enforce /etc/apparmor.d/*
echo "CIS Rule: 1.6.1.4 Ensure all AppArmor Profiles are enforcing"
cls


echo "CIS Rule: 1.7 Command Line Warning Banners"
echo "CIS Rule: 1.7.1 Ensure message of the day is configured properly"
cat > /etc/motd << 'EOF'
YOUR COMPANY NAME
EOF
echo "CIS Rule: 1.7.2 Ensure local login warning banner is configured properly"
sed -i "s/\#Banner none/Banner \/etc\/issue\.net/" /etc/ssh/sshd_config
cp -p /etc/issue.net /etc/issue.net_bak
cat > /etc/issue.net << 'EOF'
/------------------------------------------------------------------------\
|                       *** NOTICE TO USERS ***                          |
|                                                                        |
| This computer system is the private property of YOUR COMAPNY NAME      |
| Information Technology Pvt Ltd. It is for authorized use only.         |
|                                                                        |
| Users (authorized or unauthorized) have no explicit or implicit        |
| expectation of privacy.                                                |
|                                                                        |
| Any or all uses of this system and all files on this system may be     |
| intercepted, monitored, recorded, copied, audited, inspected, and      |
| disclosed to your employer, to authorized site, government, and law    |
| enforcement personnel, as well as authorized officials of government   |
| agencies, both domestic and foreign.                                   |
|                                                                        |
| By using this system, the user consents to such interception,          |
| monitoring, recording, copying, auditing, inspection, and disclosure   |
| at the discretion of such personnel or officials.  Unauthorized or     |
| improper use of this system may result in civil and criminal penalties |
| and administrative or disciplinary action, as appropriate. By          |
| continuing to use this system you indicate your awareness of and       |
| consent to these terms and conditions of use. LOG OFF IMMEDIATELY if   |
| you do not agree to the conditions stated in this warning.             |
\------------------------------------------------------------------------/
EOF
rm -rf /etc/issue
echo "CIS Rule: 1.7.3 Ensure remote login warning banner is configured properly"
ln -s /etc/issue.net /etc/issue
echo "CIS Rule: 1.7.4 Ensure permissions on /etc/motd are configured "
chown root:root $(readlink -e /etc/motd)
chmod u-x,go-wx $(readlink -e /etc/motd)
echo "CIS Rule: 1.7.5 Ensure permissions on /etc/issue are configured"
echo "CIS Rule: 1.7.6 Ensure permissions on /etc/issue.net are configured"
chown root:root $(readlink -e /etc/issue.net)
chmod u-x,go-wx $(readlink -e /etc/issue.net)
cls


echo "CIS Rule: 1.8 GNOME Display Manager"
echo "CIS Rule: 1.8.1 Ensure GNOME Display Manager is removed"
dpkg -s gdm3 | grep -E '(Status:|not installed)'
if [[ $? -eq 0 ]]
then
	echo "Installed Manually, hence not removing.."
	echo "CIS Rule: 1.8.2 Ensure GDM login banner is configured"
	echo "CIS Rule: 1.8.3 Ensure disable-user-list is enabled"
	cat > /etc/gdm3/greeter.dconf-defaults << "EOF"
[org/gnome/login-screen]
banner-message-enable=true
banner-message-text='Authorized uses only. All activity may be monitored and reported.'
disable-user-list=true
EOF
dpkg-reconfigure gdm3
echo "CIS Rule: 1.8.4 Ensure XDCMP is not enabled .. By Default value set to false"
else
	echo "GNOME Display Manager is not installed, hence SKIPPING 1.8.2 to 1.8.4"
fi 
cls


echo "CIS Rule: 1.9 Ensure updates, patches, and additional security software are installed.. Will be done Manually"
cls




############################################################################################################################################################
echo "Section 2 ..."
echo "Services..."

echo "CIS Rule: 2.1 Special Purpose Service"
echo "CIS Rule: 2.1.1 Time Synchronization"
echo "CIS Rule: 2.1.1.1 Ensure time synchronization is in use... SKIPPING as timesyncd.service is using"
echo -e "CIS Rule: 2.1.1.2 Ensure systemd-timesyncd is configured..."
apt purge ntp -y 2>dev/null
apt purge chrony -y 2>/dev/null
cat > /etc/systemd/timesyncd.conf << "EOF"
[Time]
NTP=172.16.32.60
EOF
systemctl enable systemd-timesyncd.service
systemctl start systemd-timesyncd.service 
timedatectl set-ntp true 
systemctl restart systemd-timesyncd.service
timedatectl
echo "CIS Rule: 2.1.1.3 Ensure chrony is configured .. SKIPPING as timesyncd service is using"
echo "CIS Rule: 2.1.1.4 Ensure ntp is configured .. SKIPPING as timesyncd service is using"
cls

echo "CIS Rule: 2.1.2 Ensure X Window System is not installed"
apt purge xserver-xorg* -y 2>/dev/null
echo "CIS Rule: 2.1.3 Ensure Avahi Server is not installed"
echo "CIS Rule: 2.1.4 Ensure CUPS is not installed"
echo "CIS Rule: 2.1.5 Ensure DHCP Server is not installed "
echo "CIS Ruel: 2.1.6 Ensure LDAP server is not installed"
echo "CIS Rule: 2.1.7 Ensure NFS is not installed"
echo "CIS Rule: 2.1.8 Ensure DNS Server is not installed"
echo "CIS Rule: 2.1.9 Ensure FTP Server is not installed"
echo "CIS Rule: 2.1.10 Ensure HTTP server is not installed"
echo "CIS Rule: 2.1.11 Ensure IMAP and POP3 server are not installed "
echo "CIS Rule: 2.1.12 Ensure Samba is not installed"
echo "CIS Rule: 2.1.13 Ensure HTTP Proxy Server is not installed"
echo "CIS Rule: 2.1.14 Ensure SNMP Server is not installed"
echo "CIS Rule: 2.1.16 Ensure rsync service is not installed "
echo "CIS Rule: 2.1.17 Ensure NIS Server is not installed"
SERVICES=(avahi-daaemon cups isc-dhcp-server slapd nfs-kernel-server bind9 vsftpd apache2 dovecot-imapd dovecot-pop3d samba squid snmpd rsync nis)
for i in ${SERVICES[@]}
do
systemctl stop $i.service 2>/dev/null
systemctl stop $i.socket 2>/dev/null
apt purge $i 2>dev/null
done
echo "CIS Rule: 2.1.15 Ensure mail transfer agent is configured for local-only mode.. SKIPPING as MTA is by default not installed"
cls

echo "CIS Rule: 2.2 Service Clients"
echo "CIS Rule: 2.2.1 Ensure NIS Client is not installed"
echo "CIS Rule: 2.2.2 Ensure rsh client is not installed"
echo "CIS Rule: 2.2.3 Ensure talk client is not installed"
echo "CIS Rule: 2.2.4 Ensure telnet client is not installed"
echo "CIS Rule: 2.2.5 Ensure LDAP client is not installed"
echo "CIS Rule: 2.2.6 Ensure RPC is not installed"
SERVICES=(nis rsh-client talk telne ldap-utils rpcbind )

for i in ${SERVICES[@]}
do
apt purge $i 2>dev/null
done
cls

echo "CIS Rule: 2.3 Ensure nonessential services are removed or masked.. Already Removed all services.. Hnece SKIPPING"
cls

#######################################################################################################################################
echo "Section 3"
echo "CIS Rule: 3 Network Configuration"
echo "CIS Rule: 3.1 Disable unused network protocols and devices"
echo "CIS Rule: 3.1.1 Disable IPv6"

{
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

} > /etc/sysctl.d/CISRules.conf

echo "CIS Rule: 3.1.2 Ensure wireless interfaces are disabled"
apt install network-manager -y
	if command -v nmcli >/dev/null 2>&1 ; then
		nmcli radio all off
	else
		if [ -n "$(find /sys/class/net/*/ -type d -name wireless)" ]; then
		mname=$(for driverdir in $(find /sys/class/net/*/ -type d -name wireless | xargs -0 dirname); do basename "$(readlink -f "$driverdir"/device/driver/module)";done | sort -u)
			for dm in $mname; do
			echo "install $dm /bin/true" >> /etc/modprobe.d/disable_wireless.conf
			done
		fi
	fi 
cls

echo "CIS Rule: 3.2 Network Parameters (Host Only)"
echo "CIS Rule: 3.2.1 Ensure packet redirect sending is disabled"
echo "CIS Rule: 3.2.2 Ensure IP forwarding is disabled"
echo "CIS Rule: 3.3 Network Parameters (Host and Router)"
echo "CIS Rule: 3.3.1 Ensure source routed packets are not accepted "
echo "CIS Rule: 3.3.2 Ensure ICMP redirects are not accepted"
echo "CIS Rule: 3.3.3 Ensure secure ICMP redirects are not accepted"
echo "CIS Rule: 3.3.4 Ensure suspicious packets are logged "
echo "CIS Rule: 3.3.5 Ensure broadcast ICMP requests are ignored"
echo "CIS Rule: 3.3.6 Ensure bogus ICMP responses are ignored"
echo "CIS Rule: 3.3.7 Ensure Reverse Path Filtering is enabled"
echo "CIS Rule: 3.3.8 Ensure TCP SYN Cookies is enabled"
echo "CIS Rule: 3.3.9 Ensure IPv6 router advertisements are not accepted"

{
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
net.ipv4.route.flush=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.icmp_echo_bold_ignore_broadcasts=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.disable_ipv6=1
fs.suid_dumpable=0
} >> /etc/sysctl.d/CISRules.conf

cls

echo "CIS Rule: 3.4 Uncommon Network Protocols"
echo "CIS Rule: 3.4.1 Ensure DCCP is disabled"
echo "CIS Rule: 3.4.2 Ensure SCTP is disabled"
echo "CIS Rule: 3.4.3 Ensure RDS is disabled"
echo "CIS Rule: 3.4.4 Ensure TIPC is disabled"
{
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
} /etc/modprobe.d/uncommon_network_protocal.conf
cls

echo "CIS Rule: 3.5 Firewall Configuration"
echo "CIS Rule: 3.5.1 Configure UncomplicatedFirewall"
echo "CIS Rule: 3.5.1.1 Ensure ufw is installed"
apt install ufw -y 2>/dev/null

echo "CIS Rule: 3.5.1.2 Ensure iptables-persistent is not installed with ufw .. SKIPPING"
echo "CIS Rule: 3.5.1.3 Ensure ufw service is enabled"
systemctl is-enabled ufw
ufw enable
ufw allow proto tcp from any to any port 22 2>/dev/null

echo "CIS Rule: 3.5.1.4 Ensure ufw loopback traffic is configured "
ufw allow in on lo
ufw allow out on lo
ufw deny in from 127.0.0.0/8
ufw deny in from ::1

echo "CIS Rule: 3.5.1.5 Ensure ufw outbound connections are configured "
ufw allow out on all
echo "CIS Rule: 3.5.1.6 Ensure ufw firewall rules exist for all open ports..  SKIPPING "
echo "CIS Rule: 3.5.1.7 Ensure ufw default deny firewall policy"
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
cls

echo "CIS Rule: 3.5.2 Configure nftables.. SKIPPING"
echo "CIS Rule: 3.5.3 Configure iptables.. SKIPPING"

########################################################################################################################

echo "Section 4"
echo "CIS Rule: 4 Logging and Auditing"
echo "CIS Rule: 4.1 Configure System Accounting"
echo "CIS Rule: 4.1.1 Ensure auditing is enabled"
echo "CIS Rule: 4.1.1.1 Ensure auditd is installed"
apt install auditd audispd-plugins -y 2>/dev/null
echo "CIS Rule: 4.1.1.2 Ensure auditd service is enabled"
systemctl --now enable auditd 
echo "CIS Rule: 4.1.1.3 Ensure auditing for processes that start prior to auditd is enabled"
echo 'GRUB_CMDLINE_LINUX="audit=1"' >> /etc/default/grub
update-grub
echo "CIS Rule: 4.1.1.4 Ensure audit_backlog_limit is sufficient"
echo 'GRUB_CMDLINE_LINUX="audit_backlog_limit=8192"' >> /etc/default/grub
update-grub
cls

echo "CIS Rule: 4.1.2 Configure Data Retention"
echo "CIS Rule: 4.1.2.1 Ensure audit log storage size is configured"
echo "CIS Rule: 4.1.2.2 Ensure audit logs are not automatically deleted"
echo "CIS Rule: 4.1.2.3 Ensure system is disabled when audit logs are full "
cp -a /etc/audit/auditd.conf /etc/audit/auditd.conf.bak
sed -i 's/^space_left_action.*$/space_left_action = email/' /etc/audit/auditd.conf
sed -i 's/^action_mail_acct.*$/action_mail_acct = root/' /etc/audit/auditd.conf
sed -i 's/^admin_space_left_action.*$/admin_space_left_action = halt/' /etc/audit/auditd.conf
sed -i 's/^max_log_file_action.*$/max_log_file_action = keep_logs/' /etc/audit/auditd.conf
cls

echo "CIS Rule: 4.1.3 Ensure events that modify date and time information are collected"
echo "CIS Rule: 4.1.4 Ensure events that modify user/group information are collected"
echo "CIS Rule: 4.1.5 Ensure events that modify the system's network environment are collected "
echo "CIS Rule: 4.1.6 Ensure events that modify the system's Mandatory Access Controls are collected"
echo "CIS Rule: 4.1.7 Ensure login and logout events are collected"
echo "CIS Rule: 4.1.8 Ensure session initiation information is collected"
echo "CIS Rule: 4.1.9 Ensure discretionary access control permission modification events are collected"
echo "CIS Rule: 4.1.10 Ensure unsuccessful unauthorized file access attempts are collected"
echo "CIS Rule: 4.1.11 Ensure use of privileged commands is collected"
echo "CIS Rule: 4.1.12 Ensure successful file system mounts are collected"
echo "CIS Rule: 4.1.13 Ensure file deletion events by users are collected"
echo "CIS Rule: 4.1.14 Ensure changes to system administration scope (sudoers) is collected"
echo "CIS Rule: 4.1.15 Ensure system administrator command executions (sudo) are collected"
echo "CIS Rule: 4.1.16 Ensure kernel module loading and unloading is collected"
echo "CIS Rule: 4.1.17 Ensure the audit configuration is immutable"

cat > /etc/audit/rules.d/CIS.rules << "EOF"
-D
-b 320
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-w /etc/sudoers -p wa -k scope
-w /var/log/sudo.log -p wa -k actions
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-w /etc/selinux/ -p wa -k MAC-policy
-e 2
EOF
cls

echo "CIS Rule: 4.2 Configure Logging"
echo "CIS Rule: 4.2.1 Configure rsyslog"
echo "CIS Rule: 4.2.1.1 Ensure rsyslog is installed"
apt install rsyslog -y 2>/dev/null
echo "CIS Rule: 4.2.1.2 Ensure rsyslog Service is enabled"
systemctl --now enable rsyslog
echo "CIS Rule: 4.2.1.3 Ensure logging is configured"

cat > /etc/rsyslog.d/CIS.conf << "EOF"
*.emerg								 :omusrmsg:*
auth,authpriv.* 					/var/log/auth.log
mail.* 								-/var/log/mail
mail.info 							-/var/log/mail.info
mail.warning 						-/var/log/mail.warn
mail.err 							/var/log/mail.err
news.crit 							-/var/log/news/news.crit
news.err 							-/var/log/news/news.err
news.notice 						-/var/log/news/news.notice
*.=warning;*.=err 					-/var/log/warn
*.crit 								/var/log/warn
*.*;mail.none;news.none 			-/var/log/messages
local0,local1.* 					-/var/log/localmessages
local2,local3.* 					-/var/log/localmessages
local4,local5.* 					-/var/log/localmessages
local6,local7.* 					-/var/log/localmessages
EOF
systemctl reload rsyslog

echo "CIS Rule: 4.2.1.4 Ensure rsyslog default file permissions configured.. SKIPPING as default value is 0640"
echo "CIS Rule: 4.2.1.5 Ensure rsyslog is configured to send logs to a remote log host.. SKIPPING as not forwarding logs "
echo "CIS Rule: 4.2.1.6 Ensure remote rsyslog messages are only accepted on designated log hosts .. SKIPPING as this is not accepting the logs from other server"
cls


echo "CIS Rule: 4.2.2 Configure journald"
echo "CIS Rule: 4.2.2.1 Ensure journald is configured to send logs to rsyslog "
sed -i 's/#ForwardToSyslog=yes/ForwardToSyslog=yes/g' /etc/systemd/journald.conf
echo "CIS Rule: 4.2.2.2 Ensure journald is configured to compress large log files"
sed -i 's/#Compress=yes/Compress=yes/g' /etc/systemd/journald.conf
echo "CIS Rule: 4.2.2.3 Ensure journald is configured to write logfiles to persistent disk"
sed -i 's/#Storage=auto/Storage=persistent/g'
echo "CIS Rule: 4.2.3 Ensure permissions on all logfiles are configured"
find /var/log -type f -exec chmod g-wx,o-rwx "{}" + -o -type d -exec chmod g-w,o-rwx "{}" +
cls

echo "CIS Rule: 4.3 Ensure logrotate is configured"
sed -i 's/create/create 0640 root utmp/g' /etc/logrotate.conf

#######################################################################################################################################################################################

###########################Section 4#############################################
echo "Section 5 : Access, Authentication and Authorization"

echo "CIS Rule: 5.1.1 Ensure cron daemon is enabled and running "
systemctl --now enable cron

echo "CIS Rule: 5.1.2 Ensure permissions on /etc/crontab are configured"
chown root:root /etc/crontab
chmod og-rwx /etc/crontab

echo "CIS Rule: 5.1.3 Ensure permissions on /etc/cron.hourly are configured "
chown root:root /etc/cron.hourly/
chmod og-rwx /etc/cron.hourly/

echo "CIS Rule: 5.1.4 Ensure permissions on /etc/cron.daily are configured"
chown root:root /etc/cron.daily/
chmod og-rwx /etc/cron.daily/

echo "CIS Rule: 5.1.5 Ensure permissions on /etc/cron.weekly are configured"
chown root:root /etc/cron.weekly/
chmod og-rwx /etc/cron.weekly/

echo "CIS Rule: 5.1.6 Ensure permissions on /etc/cron.monthly are configured"
chown root:root /etc/cron.monthly/
chmod og-rwx /etc/cron.monthly/

echo "CIS Rule: 5.1.7 Ensure permissions on /etc/cron.d are configured"
chown root:root /etc/cron.d/
chmod og-rwx /etc/cron.d/

echo "CIS Rule: 5.1.8 Ensure cron is restricted to authorized users"
rm /etc/cron.deny 2>/dev/null
touch /etc/cron.allow 
chmod g-wx,o-rwx /etc/cron.allow
chown root:root /etc/cron.allow

echo "CIS Rule: 5.1.9 Ensure at is restricted to authorized users"
rm /etc/at.deny 2>/dev/null
touch /etc/at.allow
chmod g-wx,o-rwx /etc/at.allow
chown root:root /etc/at.allow
cls


echo "CIS Rule: 5.2 Configure sudo"
echo "CIS Rule: 5.2.1 Ensure sudo is installed"
apt install sudo -y 2>/dev/null
echo "CIS Rule: 5.2.2 Ensure sudo commands use pty"
echo "Defaults use_pty" >> /etc/sudoers.d/CIS_Rules.conf
echo "CIS Rule: 5.2.3 Ensure sudo log file exists"
echo 'Defaults logfile="/var/log/sudo.log"' >>/etc/sudoers.d/CIS_Rules.conf
cls


echo "CIS Rule: 5.3 Configure SSH Server"
echo "CIS Rule: 5.3.1 Ensure permissions on /etc/ssh/sshd_config are configured"
chown root:root /etc/ssh/sshd_config
chmod og-rwx /etc/ssh/sshd_config

echo "CIS Rule: 5.3.2 Ensure permissions on SSH private host key files are configured"
find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chown root:root {} \;
find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chmod u-x,go-rwx {} \;

echo "CIS Rule: 5.3.3 Ensure permissions on SSH public host key files are configured"
find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chmod u-x,go-wx {} \;
find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chown root:root {} \;

echo "CIS Rule: 5.3.4 Ensure SSH access is limited"
echo "AllowUsers root rebit" > /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.5 Ensure SSH LogLevel is appropriate"
echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.6 Ensure SSH X11 forwarding is disabled"
echo "X11Forwarding no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.7 Ensure SSH MaxAuthTries is set to 4 or less"
echo "MaxAuthTries 4" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.8 Ensure SSH IgnoreRhosts is enabled"
echo "IgnoreRhosts yes" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.9 Ensure SSH HostbasedAuthentication is disabled"
echo "HostbasedAuthentication no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.10 Ensure SSH root login is disabled"
echo "PermitRootLogin no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.11 Ensure SSH PermitEmptyPasswords is disabled "
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.12 Ensure SSH PermitUserEnvironment is disabled"
echo "PermitUserEnvironment no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.13 Ensure only strong Ciphers are used"
echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.14 Ensure only strong MAC algorithms are used " 
echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >>  /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS RUle: 5.3.15 Ensure only strong Key Exchange algorithms are used" 
echo  "KexAlgorithmscurve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.16 Ensure SSH Idle Timeout Interval is configured"
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/g' /etc/ssh/sshd_config
echo "CIS Rule:5.3.17 Ensure SSH LoginGraceTime is set to one minute or less"
echo "LoginGraceTime 60" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "5.3.18 Ensure SSH warning banner is configured"
sed -i 's/#Banner none/Banner issue.net/g' /etc/ssh/sshd_config
echo "CIS Rule: 5.3.19 Ensure SSH PAM is enabled"
echo "UsePAM yes" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule:5.3.20 Ensure SSH AllowTcpForwarding is disabled"
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.21 Ensure SSH MaxStartups is configured"
echo "MaxStartups 10:30:60" >> /etc/ssh/sshd_config.d/CISRules.conf
echo "CIS Rule: 5.3.22 Ensure SSH MaxSessions is limited"
echo "MaxSessions 10" >> /etc/ssh/sshd_config.d/CISRules.conf
cls

echo "CIS Rule: 5.4 Started"
echo "CIS Rule: 5.4.1 Ensure password creation requirements are configured"
apt install libpam-pwquality -y 2>/dev/null
echo "minlen = 8" >> /etc/security/pwquality.conf
echo "minclass = 4" >>  /etc/security/pwquality.conf
echo "password requisite pam_pwquality.so retry=3" >> /etc/pam.d/common-password
echo "CIS Rule: 5.4.2 Ensure lockout for failed password attempts is configured" 

cat >> /etc/pam.d/common-auth << "EOF"
auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900
account requisite pam_deny.so
account required pam_tally2.so
EOF

echo "CIS Rule: 5.4.3 Ensure password reuse is limited "
echo "password required pam_pwhistory.so remember=5" >> /etc/pam.d/common-password
echo "CIS Rule: 5.4.4 Ensure password hashing algorithm is SHA-512.. SKIPPING as already be default implemented"
cls

echo "CIS Rule: 5.5 User Accounts and Environment"
echo "CIS Rule: 5.5.1.1 Ensure minimum days between password changes is configured"
sed -i 's/PASS_MIN_DAYS   0/PASS_MIN_DAYS   1/g' /etc/login.defs
echo "CIS Rule: 5.5.1.2 Ensure password expiration is 365 days or less"
sed -i 's/PASS_MAX_DAYS   99999/PASS_MAX_DAYS   45/g' /etc/login.defs
chage --maxdays -1 rebit
chage --maxdays -1 root 2>/dev/null
echo "CIS Rule: 5.5.1.3 Ensure password expiration warning days is 7 or more.. SKIPPING as by default it is 7 days"
echo "CIS Rule: 5.5.1.4 Ensure inactive password lock is 30 days or less"
useradd -D -f 30
echo "CIS Rule: 5.5.1.5 Ensure all users last password change date is in the past.. SKIPPING"
echo "CIS Rule: 5.5.2 Ensure system accounts are secured.. SKIPPING as these accounts by default have no login shells"
echo "CIS Rule: 5.5.3 Ensure default group for the root account is GID 0.. SKIPPING as bydefault group id of root is 0"
echo "CIS Rule: 5.5.4 Ensure default user umask is 027 or more restrictive"
echo "UMASK 027" > /etc/profile.d/UMASK.sh
chmod a+x /etc/profile.d/UMASK.sh
echo "CIS Rule: 5.5.5 Ensure default user shell timeout is 900 seconds or less"
cat >> /etc/profile.d/UMASK.sh << "EOF"
TMOUT=900
readonly TMOUT
export TMOUT
EOF
cls


echo "CIS Rule: 5.6 Ensure root login is restricted to system console.. SKIPPING"
echo "CIS Rule: 5.7 Ensure access to the su command is restricted.. SKIPPING"
groupadd sugroup
echo "auth required pam_wheel.so use_uid group=sugroup" >>  /etc/pam.d/su


###############################################################################################################################################################################################################
echo "Section 6"
echo "6 System Maintenance"
echo "CIS Rule: 6.1 System File Permissions"
echo "CIS Rule: 6.1.1 Audit system file permissions.. SKIPPING"
echo "CIS Rule: 6.1.2 Ensure permissions on /etc/passwd are configured"
chown root:root /etc/passwd
chmod u-x,go-wx /etc/passwd
echo "CIS Rule: 6.1.3 Ensure permissions on /etc/passwd- are configured"
chown root:root /etc/passwd-
chmod u-x,go-wx /etc/passwd-
echo "CIS Rule:6.1.4 Ensure permissions on /etc/group are configured"
chown root:root /etc/group
chmod u-x,go-wx /etc/group
echo "CIS Rule: 6.1.5 Ensure permissions on /etc/group- are configured"
chown root:root /etc/group-
chmod u-x,go-wx /etc/group-
echo "CIS Rule: 6.1.6 Ensure permissions on /etc/shadow are configured"
chown root:root /etc/shadow
chmod u-x,g-wx,o-rwx /etc/shadow
echo "CIS Rule: 6.1.7 Ensure permissions on /etc/shadow- are configured"
chown root:root /etc/shadow-
chmod u-x,g-wx,o-rwx /etc/shadow
echo "CIS Rule: 6.1.8 Ensure permissions on /etc/gshadow are configured "
chown root:root /etc/gshadow
chmod u-x,g-wx,o-rwx /etc/gshadow
echo "CIS Rule: 6.1.9 Ensure permissions on /etc/gshadow- are configured"
chown root:root /etc/gshadow-
chmod u-x,g-wx,o-rwx /etc/gshadow-
cls

echo "CIS Rule: 6.1.10 Ensure no world writable files exist"
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f -perm -0002 | xarg -I {} chmod o-w {}
echo "CIS Rule: 6.1.11 Ensure no unowned files or directories exist"
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser >>/home/nouserfile.txt
echo "CIS Rule: 6.1.12 Ensure no ungrouped files or directories exist" 
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -nogroup >> /home/ungrouped.txt
echo "CIS Rule: 6.1.13 Audit SUID executables"
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f -perm -4000 >> /home/SUID.txt
echo "CIS RUle: 6.1.14 Audit SGID executables" 
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f -perm -2000 >> /home/SGID.txt
cls


echo "CIS Rule: 6.2 User and Group Settings"
echo "CIS Rule: 6.2.1 Ensure accounts in /etc/passwd use shadowed passwords"
awk -F: '($2 != "x" ) { print $1 " is not set to shadowed passwords "}' /etc/passwd >> /home/shadowed.txt
echo "CIS Rule: 6.2.2 Ensure password fields are not empty" 
awk -F: '($2 == "" ) { print $1 " does not have a password "}' /etc/shadow >> /home/rule_6_2_2.txt
echo "CIS Rule: 6.2.3 Ensure all groups in /etc/passwd exist in /etc/group"
for i in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
 grep -q -P "^.*?:[^:]*:$i:" /etc/group >> /home/rule_6_2_3.txt
 if [ $? -ne 0 ]; then
 echo "Group $i is referenced by /etc/passwd but does not exist in /etc/group" >> /home/rule_6_2_3.txt
 fi
done

echo "CIS Rule: 6.2.4 Ensure all users' home directories exist"
cat /etc/passwd | awk -F: '{ print $1 " " $3 " " $6 }' | while read user uid dir; do
 if [ $uid -ge 1000 -a -d "$dir" -a $user != "nfsnobody" ]; then
 owner=$(stat -L -c "%U" "$dir")
 if [ "$owner" != "$user" ]; then
 echo "The home directory $dir of user $user is owned by $owner." >> /home/rule_6_2_4.txt
 fi
 fi
done

echo "CIS Rule: 6.2.5 Ensure users own their home directories"
cat /etc/passwd | awk -F: '{ print $1 " " $3 " " $6 }' | while read user uid dir; do
  if [ $uid -ge 1000 -a ! -d "$dir" -a $user != "nfsnobody" ]; then
 echo "The home directory $dir of user $user does not exist." >> /home/rule_6_2_5.txt
 fi
done 

echo "CIS Rule: 6.2.6 Ensure users' home directories permissions are 750 or more  restrictive"
cd /home
ls -1 | while read line
do 
	grep $line /etc/passwd 1>/dev/null
	if [[ $? -eq 0 ]]
		chmod 750 $line 
	fi
done

echo "CIS Rule: 6.2.7 Ensure users' dot files are not group or world writable "
for dir in `/bin/cat /etc/passwd | /bin/egrep -v '(root|sync|halt|shutdown)' |
/bin/awk -F: '($7 != "/sbin/nologin") { print $6 }'`; do
    for file in $dir/.[A-Za-z0-9]*; do

        if [ ! -h "$file" -a -f "$file" ]; then
            fileperm=`/bin/ls -ld $file | /bin/cut -f1 -d" "`

            if [ `echo $fileperm | /bin/cut -c6 ` != "-" ]; then
                echo "Group Write permission set on file $file" >>/home/rule_6_2_7_Group_Permis.txt
            fi
            if [ `echo $fileperm | /bin/cut -c9 ` != "-" ]; then
                echo "Other Write permission set on file $file" >>/home/rule_6_2_7_other_Permis.txt
            fi
        fi

    done
done

echo "CIS Rule: 6.2.8 Ensure no users have .netrc files"
for dir in `/bin/cat /etc/passwd | /bin/egrep -v '(root|sync|halt|shutdown)' |\
    /bin/awk -F: '($7 != "/sbin/nologin") { print $6 }'`; do
    for file in $dir/.netrc; do
        if [ ! -h "$file" -a -f "$file" ]; then
            fileperm=`/bin/ls -ld $file | /bin/cut -f1 -d" "`
            if [ `echo $fileperm | /bin/cut -c5 ` != "-" ]
            then
                echo "Group Read set on $file" >> /home/rule_6_2_8.txt
            fi
            if [ `echo $fileperm | /bin/cut -c6 ` != "-" ]
            then
                echo "Group Write set on $file" /home/rule_6_2_8.txt
            fi
            if [ `echo $fileperm | /bin/cut -c7 ` != "-" ]
            then
                echo "Group Execute set on $file" /home/rule_6_2_8.txt
            fi
            if [ `echo $fileperm | /bin/cut -c8 ` != "-" ]
            then
                echo "Other Read  set on $file" /home/rule_6_2_8.txt
            fi
            if [ `echo $fileperm | /bin/cut -c9 ` != "-" ]
            then
                echo "Other Write set on $file" /home/rule_6_2_8.txt
            fi
            if [ `echo $fileperm | /bin/cut -c10 ` != "-" ]
            then
                echo "Other Execute set on $file" /home/rule_6_2_8.txt
            fi
        fi
    done
done
cls
echo "CIS Rule: 6.2.9 Ensure no users have .forward files"
for dir in `/bin/cat /etc/passwd |\
    /bin/awk -F: '{ print $6 }'`; do
    if [ ! -h "$dir/.forward" -a -f "$dir/.forward" ]; then
        echo ".forward file $dir/.forward exists"  >> /home/rule_6_2_9.txt
    fi
done
cls
echo "CIS Rule: 6.2.10 Ensure no users have .rhosts files"
for dir in `/bin/cat /etc/passwd | /bin/egrep -v '(root|halt|sync|shutdown)' |\
    /bin/awk -F: '($7 != "/sbin/nologin") { print $6 }'`; do
    for file in $dir/.rhosts; do
        if [ ! -h "$file" -a -f "$file" ]; then
            echo ".rhosts file in $dir" >> /home/rule_6_2_10.txt
        fi    done
done
cls

echo "CIS Rule: 6.2.11 Ensure root is the only UID 0 account"
awk -F: '($3 == 0) { print $1 }' /etc/passwd >> /home/rule_6_2_11.txt

cls

echo "CIS Rule:	6.2.12 Ensure root PATH Integrity"
RPCV="$(sudo -Hiu root env | grep '^PATH' | cut -d= -f2)"
echo "$RPCV" | grep -q "::" && echo "root's path contains a empty directory (::)"
echo "$RPCV" | grep -q ":$" && echo "root's path contains a trailing (:)"
for x in $(echo "$RPCV" | tr ":" " "); do
 if [ -d "$x" ]; then
 ls -ldH "$x" | awk '$9 == "." {print "PATH contains current working directory (.)"}  $3 != "root" {print $9, "is not owned by root"}  substr($1,6,1) != "-" {print $9, "is group writable"}  substr($1,9,1) != "-" {print $9, "is world writable"}' >> /home/rule_6_2_12.txt
 else
 echo "$x is not a directory"
 fi
done

echo "CIS Rule: 6.2.13 Ensure no duplicate UIDs exist"
cut -f3 -d":" /etc/passwd | sort -n | uniq -c | while read x ; do
 [ -z "$x" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
 users=$(awk -F: '($3 == n) { print $1 }' n=$2 /etc/passwd | xargs)
 echo "Duplicate UID ($2): $users" >> /home/rule_6_2_13.txt
 fi
done

cls

echo "CIS Rule: 6.2.14 Ensure no duplicate GIDs exist"
cut -d: -f3 /etc/group | sort | uniq -d | while read x ; do
 echo "Duplicate GID ($x) in /etc/group" >> /home/rule_6_2_14.txt
done

cls

echo "CIS Rule: 6.2.15 Ensure no duplicate user names exist"
cut -d: -f1 /etc/passwd | sort | uniq -d | while read -r x; do
 echo "Duplicate login name $x in /etc/passwd" >> /home/rule_6_2_15.txt
done

cls

echo "CIS Rule: 6.2.16 Ensure no duplicate group names exist "
cut -d: -f1 /etc/group | sort | uniq -d | while read -r x; do
 echo "Duplicate group name $x in /etc/group" >> /home/rule_6_2_16.txt
done

echo "CIS Rule: 6.2.17 Ensure shadow group is empty"
awk -F: '($1=="shadow") {print $NF}' /etc/group >> /home/rule_6_2_17.txt
awk -F: -v GID="$(awk -F: '($1=="shadow") {print $3}' /etc/group)" '($4==GID) {print $1}' /etc/passwd >>  /home/rule_6_2_17.txt



 











 






















#1.4.3 Ensure permissions on bootloader config are configured 
echo -e "Ensure permissions on bootloader config are configured"
chown root:root /boot/grub/grub.cfg
chmod u-wx,go-rwx /boot/grub/grub.cfg

echo "Ensure authentication required for single user mode
