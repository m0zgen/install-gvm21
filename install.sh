#!/bin/bash
# Bootstrap installer for GVM engine
# Created by Yevgeniy Goncharov, https://sys-adm.in

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

cd $SCRIPT_PATH

HOSTNAME=`hostname`
SERVER_IP=`hostname -I`

# Functions
# -------------------------------------------------------------------------------------------\

# Messages and Styles

# Colored styles
on_success="DONE"
on_fail="FAIL"
white="\e[1;37m"
green="\e[1;32m"
red="\e[1;31m"
purple="\033[1;35m"
nc="\e[0m"

## 
Info() {
    echo -en "${1}${green} - ${2}${nc}\n"
}

Warn() {
        echo -en "${1}${purple} - ${2}${nc}\n"
}

Success() {
    echo -en "${1}${green} - ${2}${nc}\n"
}

Error () {
    echo -en "${1}${red} - ${2}${nc}\n"
}

Splash() {
    echo -en "${white}${1}${nc}\n"
}

space() { 
    echo -e ""
}

error_exit() {
    Error "Your distribution is not supported (yet)"
    exit 1
}

# Yes / No confirmation
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}


# Check is current user is root
isRoot() {
    if [ $(id -u) -ne 0 ]; then
        Error "You must be root user to continue"
        exit 1
    fi
    RID=$(id -u root 2>/dev/null)
    if [ $? -ne 0 ]; then
        Error "User root no found. You should create it to continue"
        exit 1
    fi
    if [ $RID -ne 0 ]; then
        Error "User root UID not equals 0. User root must have UID 0"
        exit 1
    fi
}


# Checks supporting distros
checkDistro() {
    # Checking distro
    if [ -e /etc/centos-release ]; then
        DISTRO=`cat /etc/redhat-release | awk '{print $1,$4}'`
        RPM=1
    elif [ -e /etc/fedora-release ]; then
        DISTRO=`cat /etc/fedora-release | awk '{print ($1,$3~/^[0-9]/?$3:$4)}'`
        RPM=1
    elif [ -e /etc/os-release ]; then
        DISTRO=`lsb_release -d | awk -F"\t" '{print $2}'`
        RPM=2
    else
        error_exit
    fi
}

# SELinux status
isSELinux() {

    if [[ "$RPM" -eq "1" ]]; then
        selinuxenabled
        if [ $? -ne 0 ]
        then
            Info "SELinux:\t\t" "DISABLED"
        else
            Info "SELinux:\t\t" "ENABLED"
        fi
    fi

}

# General system information
system_info() {
    checkDistro
    echo ""
    Info "[Info]" "Information about of target distro:\n"
    Info "Hostname:\t\t" $HOSTNAME
    Info "Distro:\t\t\t" "${DISTRO}"
    Info "IP:\t\t\t" $SERVER_IP
    Info "External IP:\t\t" $(curl -s ifconfig.co)

    isRoot
    isSELinux

    Info "Kernel:\t\t\t" `uname -r`
    Info "Architecture:\t\t" `arch`
}

# Actions
# -------------------------------------------------------------------------------------------\
system_info

if [[ "$RPM" = "2" ]]; then

    echo ""
    Info "[Info]" "Debian based detected distro..."
    Info "[Info]" "Checking Ubuntu release..."

    DIST=`lsb_release -si`

    if [[ "$DIST" == "Ubuntu" ]]; then
        Info "[Info]" "Ubuntu detected\n"
        REL=`lsb_release -r | awk '{ print $2 }'`

        if [[ "$REL" > 20 ]]; then

            if confirm "Do you want install GVM (y/n)?"; then

                default=21
                read -p "Enter GVM version number 20 or 21. [Default: $default]: " VER
                VER=${VER:-$default}
                # echo "VER is $VER"

                if [[ "$VER" == 20 ]]; then
                    Info "[Info]" "GVM 20 selected. Installation is starting..."
                    ./gvm20/ubuntu.sh

                elif [[ "$VER" == 21 ]]; then
                    Info "[Info]" "GVM 21 selected. Installation is starting..."
                    ./gvm21/ubuntu.sh
                    
                else
                    Error "[Info]" "Unknown version"
                fi

            else
                Info "[Exit]" "Bye!"

            fi
        
        else
            error_exit
        fi

    else
        error_exit
    fi
else
    error_exit
fi

