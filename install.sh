#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#   System Required: CentOS7
#   Description: Transmission for CentOS7 Auto-Install Script
#   Version: 1.0.6
#   Author: Shkong
#   Blog: https://www.shkong.com/80.html
#=================================================

sh_ver="1.0.6"
Transmission_file="/usr/share/transmission"
Transmission_conf="/home/transmission/.config/transmission/settings.json"
Now_username="Shkong"
Now_password="DefaultPassword"
Now_port="9417"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#检查ROOT权限
check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查Transmission安装状态
check_installed_status(){
    [[ ! -e ${Transmission_file} ]] && echo -e "${Error} Transmission 没有安装，请检查 !" && exit 1
}
#检查Transmission运行状态
check_pid(){
    PID=`ps -ef| grep "transmission-da"| grep -v "grep" | grep -v ".sh"| grep -v "init.d" |grep -v "service" |awk '{print $2}'`
}
check_ver_comparison(){
    check_pid
    [[ ! -z $PID ]] && kill -9 ${PID}
    rm -rf ${Transmission_file}
    Download_Transmission
    Start_Transmission
}
#检查Transmission最新版本
check_new_ver(){
	echo -e "${Info} 请输入 Transmission 版本号，格式如：[ 2.94 ]，获取地址：[ https://github.com/transmission/transmission/releases ]"
	read -e -p "默认回车自动获取最新版本号:" transmission_new_ver
	if [[ -z ${transmission_new_ver} ]]; then
		transmission_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/transmission/transmission/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
		if [[ -z ${transmission_new_ver} ]]; then
			echo -e "${Error} Transmission 最新版本获取失败，请手动获取最新版本号[ https://github.com/transmission/transmission/releases ]"
			read -e -p "请输入版本号 [ 格式如 2.94 ] :" transmission_new_ver
			[[ -z "${transmission_new_ver}" ]] && echo "取消..." && exit 1
		else
			echo -e "${Info} 检测到 Transmission 最新版本为 [ ${transmission_new_ver} ]"
		fi
	else
		echo -e "${Info} 即将准备下载 Transmission 版本为 [ ${transmission_new_ver} ]"
	fi
}
#下载Transmission版本
Download_Transmission(){
    check_new_ver
    wget -c --no-check-certificate https://github.com/transmission/transmission-releases/raw/master/transmission-${transmission_new_ver}.tar.xz
    tar -Jxf transmission-${transmission_new_ver}.tar.xz
    cd transmission-${transmission_new_ver}
    ./configure --prefix=/usr
    make && make install
    cd ..
}
Set_Config(){
	if [[ -e ${Transmission_conf} ]]; then
		Now_username = $(grep -Po 'rpc-username[" :]+\K[^"]+' ${Transmission_conf})
		Now_password = $(grep -Po 'rpc-password[" :]+\K[^"]+' ${Transmission_conf})
		Now_port = $(grep -Po 'rpc-port[" :]+\K[^"]+' ${Transmission_conf})
	fi
	read -e -p "${Info} 请输入新的控制面板用户名(当前:${Now_username})：" rpc_username
	read -e -p "${Info} 请输入新的控制面板密码(当前:${Now_password})：" rpc_password
	read -e -p "${Info} 请输入新的控制面板端口(当前:${Now_port})：" Port
}
Service_Transmission(){
    useradd -m transmission
    passwd -d transmission
    if ! wget -c --no-check-certificate https://raw.githubusercontent.com/ishkong/Transmission-install-script/master/init.sh -O /etc/init.d/transmissiond; then
        echo -e "${Error} Transmission服务 管理脚本下载失败 !" && rm -rf /etc/init.d/transmissiond && exit 1
    fi
    chmod +x /etc/init.d/transmissiond
    chkconfig --add transmissiond
    chkconfig --level 2345 transmissiond on
    echo -e "${Info} Transmission服务 管理脚本下载完成 !"
    mkdir -p /home/transmission/Downloads/
    chmod g+w /home/transmission/Downloads/
    mkdir -p /home/transmission/.config/transmission/
    if ! wget -c --no-check-certificate https://raw.githubusercontent.com/ishkong/Transmission-install-script/master/settings.json -O /home/transmission/.config/transmission/settings.json; then
        echo -e "${Error} Transmission服务 配置文件下载失败 !" && rm -rf /home/transmission/.config/transmission/settings.json && exit 1
    fi
	sed -i 's/Shkong/'${rpc_username}'/g' /home/transmission/.config/transmission/settings.json
	sed -i 's/DefaultPassword/'${rpc_password}'/g' /home/transmission/.config/transmission/settings.json
	sed -i 's/9417/'${Port}'/g' /home/transmission/.config/transmission/settings.json
    chown -R transmission.transmission /home/transmission/
    cd /usr/share/transmission/web/
    wget -c --no-check-certificate https://raw.githubusercontent.com/ishkong/Transmission-install-script/master/src.zip
    rm -f index.html
    unzip -o src.zip
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -P PREROUTING ACCEPT
    iptables -t nat -P POSTROUTING ACCEPT
    iptables -t nat -P OUTPUT ACCEPT
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t mangle -P PREROUTING ACCEPT
    iptables -t mangle -P INPUT ACCEPT
    iptables -t mangle -P FORWARD ACCEPT
    iptables -t mangle -P OUTPUT ACCEPT
    iptables -t mangle -P POSTROUTING ACCEPT
    iptables -F
    iptables -X
    iptables -P FORWARD ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t raw -F
    iptables -t raw -X
    iptables -t raw -P PREROUTING ACCEPT
    iptables -t raw -P OUTPUT ACCEPT
    service iptables save
}
Installation_dependency(){
    yum clean all
    yum -y update
    yum -y install wget screen xz gcc git gcc-c++ m4 make automake libtool gettext openssl-devel pkgconfig perl-libwww-perl perl-XML-Parser curl curl-devel vsftpd libevent-devel libevent libidn-devel zlib-devel intltool unzip which
    cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    rm -rf /home/transmission
    rm -rf /usr/share/transmission
    mkdir /home/transmission
    wget -c --no-check-certificate https://github.com/libevent/libevent/releases/download/release-2.1.10-stable/libevent-2.1.10-stable.tar.gz
    tar -zxvf libevent-2.1.10-stable.tar.gz
    cd libevent-2.1.10-stable
    ./configure --prefix=/usr
    make && make install
    ln -s /usr/local/lib/libevent-2.0.so.5 /usr/lib/libevent-2.0.so.5
    echo "安装libevent完毕！当前libevent版本:2.1.10"
    cd ..
}
Install_Transmission(){
    [[ -e ${Transmission_file} ]] && echo -e "${Error} 检测到 Transmission 已安装 !" && exit 1
    echo -e "${Info} 开始安装/配置 依赖..."
    Installation_dependency
    echo -e "${Info} 开始下载/安装..."
    Download_Transmission
    echo -e "${Info} 开始下载/安装 服务脚本(init)..."
    Set_Config
    Service_Transmission
    echo -e "${Info} 开始设置 iptables防火墙..."
    Set_iptables
    echo -e "${Info} 开始添加 iptables防火墙规则..."
    Add_iptables
    echo -e "${Info} 开始保存 iptables防火墙规则..."
    Save_iptables
    echo -e "${Info} 所有步骤 安装完毕，开始启动..."
    Start_Transmission
}
Remove_Transmission(){
	[[ ! -e ${Transmission_file} ]] && echo -e "${Error} 检测到 Transmission 已安装 !" && exit 1
	Stop_Transmission
	echo -e "${Info} 开始卸载..."
	rm -rf /etc/init.d/transmissiond
	rm -rf /home/transmission/.config/transmission/settings.json
	rm -rf /home/transmission/
	rm -rf /usr/share/transmission/
	userdel transmission --force
	echo -e "${Info} 卸载完毕 !"
}
Start_Transmission(){
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && echo -e "${Error} Transmission 正在运行，请检查 !" && exit 1
    service transmissiond start
    sleep 1s
}
Stop_Transmission(){
    check_installed_status
    check_pid
    [[ -z ${PID} ]] && echo -e "${Error} Transmission 没有运行，请检查 !" && exit 1
    service transmissiond stop
}
Restart_Transmission(){
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && service transmissiond stop
    service transmissiond start
    sleep 1s
    check_pid
    [[ ! -z ${PID} ]] && View_Transmission
}
Add_iptables(){
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${Port} -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${Port} -j ACCEPT
}
Save_iptables(){
    service iptables save
}
Set_iptables(){
    service iptables save
    chkconfig --level 2345 iptables on
}
Change_Config(){
	Stop_Transmission
	Set_Config
	sed -i 's/'${Now_username}'/'${rpc_username}'/g' /home/transmission/.config/transmission/settings.json
	sed -i 's/'${Now_password}'/'${rpc_password}'/g' /home/transmission/.config/transmission/settings.json
	sed -i 's/'${Now_port}'/'${Port}'/g' /home/transmission/.config/transmission/settings.json
	Start_Transmission
	echo "${Info} 配置更换完成！"
}

echo && echo -e "  Transmission 一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- Shkong | shkong.com/80.html ----

————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Transmission
 ${Green_font_prefix} 2.${Font_color_suffix} 卸载 Transmission
————————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启动 Transmission
 ${Green_font_prefix} 4.${Font_color_suffix} 停止 Transmission
 ${Green_font_prefix} 5.${Font_color_suffix} 重启 Transmission
————————————
 ${Green_font_prefix} 6.${Font_color_suffix} 更改 Transmission 配置
————————————" && echo
    if [[ -e ${Transmission_file} ]]; then
        check_pid
        if [[ ! -z "${PID}" ]]; then
            echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
        else
            echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
        fi
    else
        echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
    fi
    echo
    stty erase '^H' && read -p " 请输入数字 [1-6]:" num
    case "$num" in
        1)
        Install_Transmission
        ;;
	2)
	Remove_Transmission
	;;
        3)
        Start_Transmission
        ;;
        4)
        Stop_Transmission
        ;;
        5)
        Restart_Transmission
        ;;
	6)
	Change_Config
	;;
        *)
        echo "请输入正确数字 [1-6]"
        ;;
    esac
