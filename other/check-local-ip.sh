#!/bin/bash
_info "检测本机 IP 地址"
mapfile -t LOCAL_NIC_NAMES < <(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}')
for i in "${LOCAL_NIC_NAMES[@]}";do
    _print "本机网卡名: $i"
done
if [ "${#LOCAL_NIC_NAMES[@]}" -lt 1 ]; then
    _error "未检测到网卡，请联系脚本作者进行适配"
    exit 1
elif [ "${#LOCAL_NIC_NAMES[@]}" -gt 1 ]; then
    _error "检测到多个网卡，请联系脚本作者进行适配"
    exit 1
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