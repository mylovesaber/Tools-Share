#!/bin/bash
# 全局变量
shName="restart-cron"
timerList=()
portList=()
commandList=()
needClean=0
programExists=""
toDeploy=0

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
_infoNoBlank() {
	printf "${_cyan}%s${_norm}\n" "$@"
}
_success() {
	printf "${_green}✓ %s${_norm}\n" "$@"
}
_successNoBlank() {
	printf "${_green}%s${_norm}\n" "$@"
}
_warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
_warningNoBlank() {
	printf "${_tan}%s${_norm}\n" "$@"
}
_error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}
_errorNoBlank() {
	printf "${_red}%s${_norm}\n" "$@"
}

CheckRoot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
CheckRoot

Usage(){
    _infoNoBlank "
    以下为可用选项:"| column -t
    echo "
    -t | --timer 定时规则
    -p | --port 需要终止的程序所占用的端口号
    -r | --run-command 需要执行的命令
    -h | --help 打印此帮助信息并退出
    -c | --clean 彻底卸载部署的定时重启脚本" | column -t
    _warningNoBlank "-p/--port 和 -c/--command 为有参选项，必须同时指定，前者用于终止对应进程，后者用于启动程序"
    _warningNoBlank "-c/--command 的参数必须用双引号括起来，且只能写命令本身，不能添加标准输入/输出或错误输出指令，例:"
    _warningNoBlank "手动希望程序在后台运行而手动输入: "
    echo "nohup /opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root >/dev/null 2>&1 &"
    echo ""
    _warningNoBlank "则 -c/--command 应填写的参数为:"
    echo "/opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root"
    echo ""
    _warningNoBlank "使用范例(关闭两个端口号，启动两个进程):"
    echo "bash <(cat /var/log/${shName}/${shName}.sh) -p 8081 -p 8082 -r \"/opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root\" -r \"/opt/test/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=mysql\""
    echo ""
    _infoNoBlank "定时规则举例:"
    echo "每周四凌晨一点执行重启程序所需的定时规则: 0 1 * * 4"
    _warningNoBlank "则部署的定时范例(关闭一个端口号，启动一个进程，设置定时规则: 每周四凌晨一点执行):"
    echo "bash <(cat /var/log/${shName}/${shName}.sh) -p 8081 -r \"/opt/test/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=mysql\" -t \"0 1 * * 4\""
    echo ""
    _warningNoBlank "卸载脚本: "
    echo "bash <(cat /var/log/${shName}/${shName}.sh) -c"
}

if ! ARGS=$(getopt -a -o t:p:r:h,c -l timer:,port:,run-command:,help,clean -- "$@")
then
    echo "无效的参数，请查看可用选项"
    Usage
    exit 1
elif [ -z "$1" ]; then
    _error "没有设置选项，请查看以下帮助菜单"
    Usage
    exit 1
elif [ "$1" == "-" ]; then
    _error "选项写法出现错误"
    Usage
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in
    -t | --timer)
        timerList+=("$2")
        shift
        ;;
    -p | --port)
        portList+=("$2")
        shift
        ;;
    -r | --run-command)
        commandList+=("$2")
        shift
        ;;
    -h | --help)
        Usage
        exit 1
        ;;
    -c | --clean)
        needClean=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

DepDetect(){
    _info "正在检测脚本正常工作的必备依赖"
    if which netstat >/dev/null 2>&1; then
        programExists="netstat"
    elif which lsof >/dev/null 2>&1; then
        programExists="lsof"
    else
        _error "检测端口工具未找到，退出中"
        _warningNoBlank "内置检测工具指定: netstat/lsof"
        exit 1
    fi
    _success "已找到依赖: ${programExists}"
}

CheckOption(){
    if [[ "${#portList[@]}" -eq 0 ]] || [[ "${#commandList[@]}" -eq 0 ]]; then
        _error "端口号和命令必须同时指定"
        exit 1
    fi

    if [ "${#timerList[@]}" -gt 0 ]; then
        _info "开始检查定时指定次数"
        if [ "${#timerList[@]}" -eq 1 ]; then
            timerCron="${timerList[0]}"
            _success "已确定定时规则"
        elif [ "${#timerList[@]}" -gt 1 ]; then
            _error "只允许设置一种定时规则"
            exit 1
        fi
        toDeploy=1
    fi
    _info "正在检查端口号"
    local errorPortNumber
    for i in "${portList[@]}" ; do
        if [[ ! "${i}" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
            errorPortNumber+=("${i}")
        fi
    done
    if [ "${#errorPortNumber[@]}" -gt 0 ]; then
        _error "端口号写法有错，以下是全部错误端口号，请检查:"
        for i in "${errorPortNumber[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success " 端口号检测通过"

    local errorCommandWithoutOption
    local commandWithoutOption
    for i in "${commandList[@]}" ; do
        commandWithoutOption="$(awk '{print $1}' <<< "${i}")"
        if [[ ! -f "${commandWithoutOption}" ]] || [[ "${i}" =~ ^(/dev/null|2>|1>|nohup)$ ]]; then
            errorCommandWithoutOption+=("${i}")
        fi
    done
    if [ "${#errorCommandWithoutOption[@]}" -gt 0 ]; then
        _error "系统中不存在以下命令，以下是全部错误命令，请检查:"
        for i in "${errorCommandWithoutOption[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success " 命令可用性检测通过"
}

StopProcess(){
_info "开始基于端口号终止进程"
    local isExecError
    isExecError=0
    for i in "${portList[@]}" ; do
        case "${programExists}" in
            "netstat")
                if netstat -nlp|grep -q "${i}"; then
                    if kill -9 "$(netstat -nlp|awk -F '[/[:space:]]+' /"${i}"/'{print $(NF-2)}')"; then
                        _success "端口号对应进程停止成功"
                    else
                        _error "端口号对应进程停止失败，请手动查看问题来源，可能信息如下:"
                        netstat -nlp|grep "${i}"
                        exit 1
                    fi
                else
                    _warning "端口号未占用，跳过"
                fi
            ;;
            "lsof")
                if [[ "$(lsof -i:"${i}"|wc -l)" -gt 1 ]]; then
                    if kill -9 "$(lsof -i:"${i}"|awk '{if (NR!=1) print $2}')"; then
                        _success "端口号对应进程停止成功"
                    else
                        _error "端口号对应进程停止失败，请手动查看问题来源，可能信息如下:"
                        lsof -i:"${i}"
                        exit 1
                    fi
                else
                    _warning "端口号未占用，跳过"
                fi
            ;;
            *)
                echo "终止进程: 暂未适配"
                exit 1
        esac
    done
}

StartService(){
    _info "开始执行命令"
    for i in "${commandList[@]}" ; do
        nohup "${i}" >/dev/null 2>&1 &
    done
    _success "命令执行成功"
}

Deploy(){
    _info "开始部署"
    if [[ ! -d /var/log/${shName} ]]; then
        mkdir -p /var/log/${shName}
    fi
    cp -a "$(pwd)"/${shName}.sh /var/log/${shName}
    chmod +x /var/log/${shName}/${shName}.sh
    sed -i "/${shName}/d" /etc/crontab
    local portLine
    local commandLine
    portLine="-p \"${portList[0]}\""
    commandLine="-r \"${commandList[0]}\""
    if [ "${#portList[@]}" -gt 1 ]; then
        for (( i = 1; i < "${#portList[@]}"; i++ )); do
            portLine="${portLine} -p \"${portList[$i]}\""
        done
    fi
    if [ "${#commandList[@]}" -gt 1 ]; then
        for (( i = 1; i < "${#commandList[@]}"; i++ )); do
            commandLine="${commandLine} -r \"${commandList[$i]}\""
        done
    fi
    echo "${timerCron} root /usr/bin/bash -c 'bash <(cat /var/log/${shName}/${shName}.sh) ${portLine} ${commandLine}'" >> /etc/crontab
    _success "部署完成"
}

Clean(){
    _info "开始卸载"
    sed -i "/${shName}/d" /etc/crontab
    rm -rf /var/log/restart-cron
    _success "卸载完成"
}

if [[ "${needClean}" -eq 1 ]]; then
    Clean
    exit 0
fi

DepDetect
CheckOption
if [[ "${toDeploy}" -eq 1 ]]; then
    Deploy
    exit 0
fi
StopProcess
StartService
