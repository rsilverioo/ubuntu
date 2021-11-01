#!/bin/bash

# echo -n "Is this a good question (y/n)? "
# read answer
# printf "${answer}"


# color codes
RESTORE='\033[0m'
BLACK='\033[00;30m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'
LBLACK='\033[01;30m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'
OVERWRITE='\e[1A\e[K'

# _header colorize the given argument with spacing
function _task {
    # if _task is called while a task was set, complete the previous
    if [[ $TASK != "" ]]; then
        printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
    fi
    # set new task title and print
    TASK=$1
    printf "${LBLACK} [ ]  ${TASK} \n${LRED}"
}

# _cmd performs commands with error checking
function _cmd {
    # empty server_harden.log
    > server_harden.log
    # hide stdout, on error we print and exit
    if eval "$1" 1> /dev/null 2> server_harden.log; then
        return 0 # success
    fi
    # read error from log and add spacing
    printf "${OVERWRITE}${LRED} [X]  ${TASK}${LRED}\n"
    while read line; do 
        printf "      ${line}\n"
    done < server_harden.log
    printf "\n"
    # remove log file
    rm server_harden.log
    # exit installation
    exit 1
} 

clear

# print logo + information
printf "${YELLOW}
  ▄▄·        ▐ ▄ ·▄▄▄▄  ▄• ▄▌▄▄▄        
 ▐█ ▌▪▪     •█▌▐███▪ ██ █▪██▌▀▄ █·▪     
 ██ ▄▄ ▄█▀▄ ▐█▐▐▌▐█· ▐█▌█▌▐█▌▐▀▀▄  ▄█▀▄ 
 ▐███▌▐█▌.▐▌██▐█▌██. ██ ▐█▄█▌▐█•█▌▐█▌.▐▌
 ·▀▀▀  ▀█▄▀▪▀▀ █▪▀▀▀▀▀•  ▀▀▀ .▀  ▀ ▀█▄▀▪
 ${LBLACK}Hardening ${YELLOW}Ubuntu 20.04 ${LBLACK} Based on https://condu.ro
 
"

# script must be run as root
if [[ $(id -u) -ne 0 ]] ; then printf "\n${LRED} Please run as root${RESTORE}\n\n" ; exit 1 ; fi

# dependencies
_task "update dependencies"
    _cmd 'apt-get install wget sed git -y'

# description
_task "update system"
    _cmd 'apt-get update -y && apt-get full-upgrade -y'

# finish last task
printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"

# description
printf "      ${YELLOW}Do you want to install Go? [Y/n]: ${RESTORE}"
read prompt && printf "${OVERWRITE}" && if [[ $prompt == "y" || $prompt == "Y" ]]; then
    _task "update golang"
        _cmd 'rm -rf /usr/local/go'
        _cmd 'wget --timeout=5 --tries=2 --quiet -c https://dl.google.com/go/$(curl -s https://golang.org/VERSION?m=text).linux-amd64.tar.gz -O go.tar.gz'
        _cmd 'tar -C /usr/local -xzf go.tar.gz'
        _cmd 'echo "export GOROOT=/usr/local/go" >> /etc/profile'
        _cmd 'echo "export PATH=/usr/local/go/bin:$PATH" >> /etc/profile'
        _cmd 'source /etc/profile' 
        _cmd 'rm go.tar.gz'
fi

# description
_task "update nameservers"
    _cmd 'truncate -s0 /etc/resolv.conf'
    _cmd 'echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf'
    _cmd 'echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf'

# description
_task "update ntp servers"
    _cmd 'truncate -s0 /etc/systemd/timesyncd.conf'
    _cmd 'echo "[Time]" | sudo tee -a /etc/systemd/timesyncd.conf'
    _cmd 'echo "NTP=time.cloudflare.com" | sudo tee -a /etc/systemd/timesyncd.conf'
    _cmd 'echo "FallbackNTP=ntp.ubuntu.com" | sudo tee -a /etc/systemd/timesyncd.conf'

# description
_task "update sysctl.conf"
    _cmd 'wget --timeout=5 --tries=2 --quiet -c https://raw.githubusercontent.com/rsilverioo/ubuntu/main/sysctl.conf -O /etc/sysctl.conf'

# description
_task "update sshd_config"
    _cmd 'wget --timeout=5 --tries=2 --quiet -c https://raw.githubusercontent.com/rsilverioo/ubuntu/main/sshd.conf -O /etc/ssh/sshd_config'

# description
_task "disable system logging"
    _cmd 'systemctl stop systemd-journald.service'
    _cmd 'systemctl disable systemd-journald.service'
    _cmd 'systemctl mask systemd-journald.service'

    _cmd 'systemctl stop rsyslog.service'
    _cmd 'systemctl disable rsyslog.service'
    _cmd 'systemctl mask rsyslog.service'

# description
_task "disable snapd"
    _cmd 'systemctl stop snapd.service'
    _cmd 'systemctl disable snapd.service'
    _cmd 'systemctl mask snapd.service'

# firewall
_task "configure firewall"
    _cmd 'ufw disable'
    _cmd 'echo "y" | sudo ufw reset'
    _cmd 'ufw logging off'
    _cmd 'ufw default deny incoming'
    _cmd 'ufw default allow outgoing'
    _cmd 'ufw allow 80/tcp comment "http"'
    _cmd 'ufw allow 443/tcp comment "https"'
    printf "${YELLOW} [?]  specify ssh port [leave empty for 22]: ${RESTORE}"
    read prompt && printf "${OVERWRITE}" && if [[ $prompt != "" ]]; then
        _cmd 'ufw allow ${prompt}/tcp comment "ssh"'
        _cmd 'echo "Port ${prompt}" | sudo tee -a /etc/ssh/sshd_config'
    else 
        _cmd 'ufw allow 22/tcp comment "ssh"'
    fi
    _cmd 'sed -i "/ipv6=/Id" /etc/default/ufw'
    _cmd 'echo "IPV6=no" | sudo tee -a /etc/default/ufw'
    _cmd 'sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/Id" /etc/default/grub'
    _cmd 'echo "GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1 quiet splash\"" | sudo tee -a /etc/default/grub'


# description
_task "free disk space"
    _cmd 'find /var/log -type f -delete'
    _cmd 'rm -rf /usr/share/man/*'
    _cmd 'apt-get autoremove -y'
    _cmd 'apt-get autoclean -y'
    # _cmd "purge" 'apt-get remove --purge -y'
    # _cmd "clean" 'apt-get clean && sudo apt-get --purge autoremove -y'

# description
_task "reload system"
    _cmd 'sysctl -p'
    _cmd 'update-grub2'
    _cmd 'systemctl restart systemd-timesyncd'
    _cmd 'ufw --force enable'
    _cmd 'service ssh restart'

# finish last task
printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"

# remove conduro.log
rm conduro.log

# reboot
printf "\n${YELLOW} Do you want to reboot [Y/n]? ${RESTORE}"
read prompt && printf "${OVERWRITE}" && if [[ $prompt == "y" || $prompt == "Y" ]]; then
    reboot
fi

# exit
exit 1

# # description
# _task "disable multipathd"
#     _cmd 'systemctl stop multipathd'
#     _cmd 'systemctl disable multipathd'
#     _cmd 'systemctl mask multipathd'

# # description
# _task "disable cron"
#     _cmd 'systemctl stop cron'
#     _cmd 'systemctl disable cron'
#     _cmd 'systemctl mask cron'

# # description
# _task "disable fwupd"
#     _cmd 'systemctl stop fwupd.service'
#     _cmd 'systemctl disable fwupd.service'
#     _cmd 'systemctl mask fwupd.service'


# # description
# _task "disable qemu-guest"
#     _cmd 'apt-get remove qemu-guest-agent -y'
#     _cmd 'apt-get remove --auto-remove qemu-guest-agent -y' 
#     _cmd 'apt-get purge qemu-guest-agent -y' 
#     _cmd 'apt-get purge --auto-remove qemu-guest-agent -y'

# # description
# _task "disable policykit"
#     _cmd 'apt-get remove policykit-1 -y'
#     _cmd 'apt-get autoremove policykit-1 -y' 
#     _cmd 'apt-get purge policykit-1 -y' 
#     _cmd 'apt-get autoremove --purge policykit-1 -y'

# # description
# _task "disable accountsservice"
#     _cmd 'service accounts-daemon stop'
#     _cmd 'apt remove accountsservice -y'

