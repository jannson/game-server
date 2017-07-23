#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS Debian or Ubuntu (32bit/64bit)
#   Description:  Install Game-Server(XiaoBao) for CentOS Debian or Ubuntu
#   Author: Clang <admin@clangcn.com>
#   Intro:  http://clang.cn
#===============================================================================================
version="4.0"
str_game_dir="/usr/local/game-server"
DLPATH=http://http://firmware.koolshare.cn/koolgame/latest/game-server
DLPATH_386=http://http://firmware.koolshare.cn/koolgame/latest/game-server-386

function fun_clang_cn(){
    echo ""
    echo "#####################################################################"
    echo "# Install Game-Server(XiaoBao) for CentOS Debian or Ubuntu(32/64bit)"
    echo "# Intro: http://clang.cn"
    echo "# Author: Clang <admin@clangcn.com>"
    echo "# Version ${version}"
    echo "#####################################################################"
    echo ""
}

# Check if user is root
function rootness(){
    if [[ $EUID -ne 0 ]]; then
        fun_clang_cn
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}

function get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Check OS
function checkos(){
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}

# Check OS bit
function check_os_bit(){
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
    else
        Is_64bit='n'
    fi
}

function check_centosversion(){
if centosversion 5; then
    echo "Not support CentOS 5.x, please change to CentOS 6,7 or Debian or Ubuntu and try again."
    exit 1
fi
}

# Disable selinux
function disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Check port
function fun_check_port(){
    strServerPort="$1"
    if [ ${strServerPort} -ge 1 ] && [ ${strServerPort} -le 65535 ]; then
        checkServerPort=`netstat -ntul | grep "\b:${strServerPort}\b"`
        if [ -n "${checkServerPort}" ]; then
            echo ""
            echo -e "\033[31m\033[01mError:\033[0m Port \033[32m${strServerPort}\033[0m is \033[35m\033[01mused\033[0m,view relevant port:"
            #netstat -apn | grep "\b:${strServerPort}\b"
            netstat -ntulp | grep "\b:${strServerPort}\b"
            fun_input_port
        else
            serverport="${strServerPort}"
        fi
    else
        echo "Input error! Please input correct numbers."
        fun_input_port
    fi
}

# input port
function fun_input_port(){
    server_port="8838"
    echo ""
    echo -e "Please input Server Port [1-65535](Don't the same SSH Port \033[31m\033[01m${sshport}\033[0m)"
    read -p "(Default Server Port: ${server_port}):" serverport
    [ -z "${serverport}" ] && serverport="${server_port}"
    fun_check_port "${serverport}"
}

# Random password
function fun_randstr(){
  index=0
  strRandomPass=""
  for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
  echo $strRandomPass
}

function pre_install_clang(){
    #config setting
    echo " Please input your Game-Server(XiaoBao) server_port and password"
    echo ""
    sshport=`netstat -anp |grep ssh | grep '0.0.0.0:'|cut -d: -f2| awk 'NR==1 { print $1}'`
    defIP=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.' | cut -d: -f2 | awk 'NR==1 { print $1}'`
    if [ "${defIP}" = "" ]; then
        defIP=$(curl -s -4 icanhazip.com)
    fi
    IP="0.0.0.0"
    echo "Please input VPS IP"
    read -p "(You VPS IP:$defIP, Default IP: $IP):" IP
    if [ "$IP" = "" ]; then
        IP="0.0.0.0"
    fi
    fun_input_port
    echo ""
    shadowsocks_pwd=`fun_randstr`
    read -p "Please input Password (Default Password: ${shadowsocks_pwd}):" shadowsockspwd
    if [ "${shadowsockspwd}" = "" ]; then
        shadowsockspwd="${shadowsocks_pwd}"
    fi
    echo ""
    ssmethod="chacha20"
    echo "Please input Encryption method(chacha20, chacha20-ietf, aes-256-cfb, bf-cfb, des-cfb, rc4)"
    read -p "(Default method: ${ssmethod}):" ssmethod
    if [ "${ssmethod}" = "" ]; then
        ssmethod="chacha20"
    fi
    echo ""
    set_iptables="n"
        echo  -e "\033[33mDo you want to set iptables?\033[0m"
        read -p "(if you want please input: y,Default [no]):" set_iptables

        case "${set_iptables}" in
        y|Y|Yes|YES|yes|yES|yEs|YeS|yeS)
        echo "You will set iptables!"
        set_iptables="y"
        ;;
        n|N|No|NO|no|nO)
        echo "You will NOT set iptables!"
        set_iptables="n"
        ;;
        *)
        echo "The iptables is not set!"
        set_iptables="n"
        esac

    echo ""
    echo "============== Check your input =============="
    echo -e "Your Server IP:\033[32m\033[01m${defIP}\033[0m"
    echo -e "Your Set IP:\033[32m\033[01m${IP}\033[0m"
    echo -e "Your Server Port:\033[32m\033[01m${serverport}\033[0m"
    echo -e "Your Password:\033[32m\033[01m${shadowsockspwd}\033[0m"
    echo -e "Your Encryption Method:\033[32m\033[01m${ssmethod}\033[0m"
    echo -e "Your SSH Port:\033[32m \033[01m${sshport}\033[0m"
    echo "=============================================="
    echo ""
    echo "Press any key to start...or Press Ctrl+c to cancel"

    char=`get_char`

    echo "============== Install packs =============="
    if [ "${OS}" == 'CentOS' ]; then
        #yum -y update
        #yum -y install nano net-tools openssl-devel wget iptables policycoreutils curl curl-devel psmisc
        echo "ignore dependency"
    else
        #apt-get update -y
        #apt-get install -y wget nano screen openssl libcurl4-openssl-dev iptables curl psmisc
        echo "ignore dependency"
    fi

    [ ! -d ${str_game_dir} ] && mkdir -p ${str_game_dir}
    cd ${str_game_dir}
    echo $PWD

# Config shadowsocks
cat > ${str_game_dir}/config.json<<-EOF
{
    "server":"${IP}",
    "local_port":1080,
    "timeout": 600,
    "method":"${ssmethod}",
    "fast_open": true,
    "port_password":
    {
        "${serverport}": "${shadowsockspwd}"
    },
    "_comment":
    {
        "${serverport}": "The server port comment"
    }
}
EOF
    chmod 400 ${str_game_dir}/config.json
    rm -f ${str_game_dir}/game-server
    if [ "${Is_64bit}" == 'y' ] ; then
        if [ ! -s ${str_game_dir}/game-server ]; then
            if ! wget --no-check-certificate $DLPATH -O ${str_game_dir}/game-server; then
                echo "Failed to download game-server file!"
                exit 1
            fi
        fi
    else
         if [ ! -s ${str_game_dir}/game-server ]; then
            if ! wget --no-check-certificate $DLPATH_386 -O ${str_game_dir}/game-server; then
                echo "Failed to download game-server file!"
                exit 1
            fi
        fi
    fi
    [ ! -x ${str_game_dir}/game-server ] && chmod 755 ${str_game_dir}/game-server
    if [ "${OS}" == 'CentOS' ]; then
        if [ ! -s /etc/init.d/game-server ]; then
            if ! wget --no-check-certificate https://github.com/clangcn/game-server/raw/master/init/centos-game-server.init -O /etc/init.d/game-server; then
                echo "Failed to download game-server.init file!"
                exit 1
            fi
        fi
        chmod +x /etc/init.d/game-server
        chkconfig --add game-server
    else
        if [ ! -s /etc/init.d/game-server ]; then
            if ! wget --no-check-certificate https://github.com/clangcn/game-server/raw/master/init/debian-game-server.init -O /etc/init.d/game-server; then
                echo "Failed to download game-server.init file!"
                exit 1
            fi
        fi
        chmod +x /etc/init.d/game-server
        update-rc.d -f game-server defaults
    fi

    if [ "$set_iptables" == 'y' ]; then
        # iptables config
        iptables -I INPUT -p udp --dport ${serverport} -j ACCEPT
        iptables -I INPUT -p tcp --dport ${serverport} -j ACCEPT
        iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        if [ "${OS}" == 'CentOS' ]; then
            service iptables save
        else
            echo '#!/bin/bash' > /etc/network/if-post-down.d/iptables
            echo 'iptables-save > /etc/iptables.rules' >> /etc/network/if-post-down.d/iptables
            echo 'exit 0;' >> /etc/network/if-post-down.d/iptables
            chmod +x /etc/network/if-post-down.d/iptables

            echo '#!/bin/bash' > /etc/network/if-pre-up.d/iptables
            echo 'iptables-restore < /etc/iptables.rules' >> /etc/network/if-pre-up.d/iptables
            echo 'exit 0;' >> /etc/network/if-pre-up.d/iptables
            chmod +x /etc/network/if-pre-up.d/iptables
        fi
    fi
    ln -s ${str_game_dir}/game-server /usr/bin/
    /etc/init.d/game-server start
    echo ""
    fun_clang_cn
    #install successfully
    echo ""
    echo "Congratulations, Game-Server(XiaoBao) install completed!"
    echo -e "Your Server IP:\033[32m\033[01m${defIP}\033[0m"
    echo -e "Your Set IP:\033[32m\033[01m${IP}\033[0m"
    echo -e "Your Server Port:\033[32m\033[01m${serverport}\033[0m"
    echo -e "Your Password:\033[32m\033[01m${shadowsockspwd}\033[0m"
    echo -e "Your Local Port:\033[32m\033[01m1080\033[0m"
    echo -e "Your Encryption Method:\033[32m\033[01m${ssmethod}\033[0m"
    echo ""
    echo -e "Game-Server(XiaoBao) status manage: \033[45;37m/etc/init.d/game-server\033[0m {\033[40;35mstart\033[0m|\033[40;32mstop\033[0m|\033[40;33mrestart\033[0m|\033[40;36mstatus\033[0m}"
    #iptables -L -n
}
############################### install function ##################################
function install_game_server_clang(){
    fun_clang_cn
    checkos
    check_centosversion
    check_os_bit
    disable_selinux
    if [ -s ${str_game_dir}/game-server ] && [ -s /etc/init.d/game-server ]; then
        echo "Game-Server(XiaoBao) is installed!"
    else
        pre_install_clang
    fi
}
############################### configure function ##################################
function configure_game_server_clang(){
    if [ -s ${str_game_dir}/config.json ]; then
        nano ${str_game_dir}/config.json
    else
        echo "Game-Server(XiaoBao) configuration file not found!"
    fi
}
############################### uninstall function ##################################
function uninstall_game_server_clang(){
    fun_clang_cn
    if [ -s /etc/init.d/game-server ] || [ -s ${str_game_dir}/game-server ] ; then
        echo "============== Uninstall Game-Server(XiaoBao) =============="
        save_config="n"
        echo  -e "\033[33mDo you want to keep the configuration file?\033[0m"
        read -p "(if you want please input: y,Default [no]):" save_config

        case "${save_config}" in
        y|Y|Yes|YES|yes|yES|yEs|YeS|yeS)
        echo ""
        echo "You will keep the configuration file!"
        save_config="y"
        ;;
        n|N|No|NO|no|nO)
        echo ""
        echo "You will NOT to keep the configuration file!"
        save_config="n"
        ;;
        *)
        echo ""
        echo "will NOT to keep the configuration file!"
        save_config="n"
        esac
        checkos
        /etc/init.d/game-server stop
        if [ "${OS}" == 'CentOS' ]; then
            chkconfig --del game-server
        else
            update-rc.d -f game-server remove
        fi
        rm -f /usr/bin/game-server /etc/init.d/game-server /var/run/game-server.pid /root/game-server-install.log /root/game-server-update.log
        if [ "${save_config}" == 'n' ]; then
            rm -fr ${str_game_dir}
        else
            rm -f ${str_game_dir}/game-server ${str_game_dir}/game-server.log
        fi
        echo "Game-Server(XiaoBao) uninstall success!"
    else
        echo "Game-Server(XiaoBao) Not install!"
    fi
    echo ""
}
############################### update function ##################################
function update_game_server_clang(){
    fun_clang_cn
    if [ -s /etc/init.d/game-server ] || [ -s ${str_game_dir}/game-server ] ; then
        echo "============== Update Game-Server(XiaoBao) =============="
        checkos
        check_centosversion
        check_os_bit
        killall game-server
        [ ! -d ${str_game_dir} ] && mkdir -p ${str_game_dir}
        rm -f /usr/bin/game-server ${str_game_dir}/game-server /root/game-server /root/game-server.log /etc/init.d/game-server
        if [ "${Is_64bit}" == 'y' ] ; then
            if [ ! -s /root/game-server ]; then
                if ! wget --no-check-certificate $DLPATH -O ${str_game_dir}/game-server; then
                    echo "Failed to download game-server file!"
                    exit 1
                fi
            fi
        else
             if [ ! -s /root/game-server ]; then
                if ! wget --no-check-certificate $DLPATH_386 -O ${str_game_dir}/game-server; then
                    echo "Failed to download game-server file!"
                    exit 1
                fi
            fi
        fi
        [ ! -x ${str_game_dir}/game-server ] && chmod 755 ${str_game_dir}/game-server
        if [ "${OS}" == 'CentOS' ]; then
            if [ ! -s /etc/init.d/game-server ]; then
                if ! wget --no-check-certificate https://github.com/clangcn/game-server/raw/master/init/centos-game-server.init -O /etc/init.d/game-server; then
                    echo "Failed to download game-server.init file!"
                    exit 1
                fi
            fi
            chmod +x /etc/init.d/game-server
            chkconfig --add game-server
        else
            if [ ! -s /etc/init.d/game-server ]; then
                if ! wget --no-check-certificate https://github.com/clangcn/game-server/raw/master/init/debian-game-server.init -O /etc/init.d/game-server; then
                    echo "Failed to download game-server.init file!"
                    exit 1
                fi
            fi
            chmod +x /etc/init.d/game-server
            update-rc.d -f game-server defaults
        fi
        ln -s ${str_game_dir}/game-server /usr/bin/
        if [ -s /root/config.json ] && [ ! -a ${str_game_dir}/config.json ]; then
            mv /root/config.json ${str_game_dir}/config.json
        fi
        /etc/init.d/game-server start
        echo "Game-Server(XiaoBao) update success!"
        ${str_game_dir}/game-server -version
    else
        echo "Game-Server(XiaoBao) Not install!"
    fi
    echo ""
}
clear
rootness
# Initialization
action=$1
[  -z $1 ]
case "$action" in
install)
    install_game_server_clang 2>&1 | tee /root/game-server-install.log
    ;;
config)
    configure_game_server_clang
    ;;
uninstall)
    uninstall_game_server_clang 2>&1 | tee /root/game-server-uninstall.log
    ;;
update)
    update_game_server_clang 2>&1 | tee /root/game-server-update.log
    ;;
*)
    fun_clang_cn
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update|config}"
    ;;
esac
