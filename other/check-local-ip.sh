#!/bin/bash
# 全局颜色
if ! which tput >/dev/null 2>&1;then
    _norm="\033[39m"
    _red="\033[31m"
    _green="\033[32m"
    _tan="\033[33m"     
    _cyan="\033[36m"
else
    _norm=$(tput sgr0)
    _red=$(tput setaf 1)
    _green=$(tput setaf 2)
    _tan=$(tput setaf 3)
    _cyan=$(tput setaf 6)
fi

_print() {
	printf "${_norm}%s${_norm}\n" "$@"
}
_info() {
	printf "${_cyan}➜ %s${_norm}\n" "$@"
}
_success() {
	printf "${_green}✓ %s${_norm}\n" "$@"
}
_successnoblank() {
	printf "${_green}%s${_norm}\n" "$@"
}
_warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
_warningnoblank() {
	printf "${_tan}%s${_norm}\n" "$@"
}
_error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}
_errornoblank() {
	printf "${_red}%s${_norm}\n" "$@"
}

_info "检测本机 IP 地址"
mapfile -t LOCAL_NIC_NAMES < <(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}')
for i in "${LOCAL_NIC_NAMES[@]}";do
    _print "本机网卡名: $i"
done
if [ "${#LOCAL_NIC_NAMES[@]}" -lt 1 ]; then
    _error "未检测到网卡，请联系脚本作者进行适配"
    exit 1
elif [ "${#LOCAL_NIC_NAMES[@]}" -gt 1 ]; then
    COUNT=0
    NICAvailableList=()
    for i in "${LOCAL_NIC_NAMES[@]}" ; do
        if ip -f inet address show "$i"|grep "state UP" >/dev/null 2>&1; then
            COUNT=$((COUNT + 1))
            mapfile -t -O "${#NICAvailableList[@]}" NICAvailableList < <(echo "$i")
        fi
    done
    case $COUNT in
    0)
        _error "检测到多张网卡均没有联网，请联系作者适配"
        exit 1
        ;;
    1)
        IP_RESULT1=$(ip -f inet address show "${NICAvailableList[0]}" | grep -Po 'inet \K[\d.]+')
        IP_RESULT2=$(ifconfig "${NICAvailableList[0]}" | grep -Po 'inet \K[\d.]+')
        if [ "${IP_RESULT1}" = "${IP_RESULT2}" ]; then
            LOCAL_IP=${IP_RESULT1}
            _success "本地 IP 地址已确定"
            _print "IP 地址: ${LOCAL_IP}"
        else
            _error "本机已锁定的 IP 地址存在不同测试结果，请联系脚本作者适配"
            exit 1
        fi
        ;;
    *)
        _error "检测到多张网卡已联网，请联系作者适配"
    esac
else
    LOCAL_NIC_NAME="${LOCAL_NIC_NAMES[0]}"
    IP_RESULT1=$(ip -f inet address show "${LOCAL_NIC_NAME}" | grep -Po 'inet \K[\d.]+')
    IP_RESULT2=$(ifconfig "${LOCAL_NIC_NAME}" | grep -Po 'inet \K[\d.]+')
    if [ "${IP_RESULT1}" = "${IP_RESULT2}" ]; then
        LOCAL_IP=${IP_RESULT1}
        _success "本地 IP 地址已确定"
        _print "IP 地址: ${LOCAL_IP}"
    else
        _error "检测到本机存在多个 IP，请联系脚本作者适配"
        exit 1
    fi
fi
