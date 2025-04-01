#!/bin/bash
# 常量
toolName=$0
tomcatPath=###TOMCAT_PATH###
tomcatService=###TOMCAT_SERVICE###
# 全局颜色
if ! which tput >/dev/null 2>&1; then
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
_infonoblank() {
    printf "${_cyan}%s${_norm}\n" "$@"
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

function CheckRoot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
CheckRoot

HelpOperation(){
    echo -e "
Tomcat控制工具

本工具可以指定Tomcat端口号和运行所需环境变量，以及控制tomcat的启停和开机自启行为
使用纯命令行控制方式将直接执行功能，所以请确认你真的有需求必须通过命令行的方式操作
默认情况下输入 tomcat-tool 将直接启动图形化界面而没必要使用以下纯命令行功能和选项

可用选项如下：
"
echo -e "
set 设置网页访问端口号和停止tomcat的监听端口号
add 添加环境变量
delete 删除环境变量
list 显示已有哪些环境变量、端口号、服务工作状态和开机自启状态
start/stop/restart/status 控制tomcat启停和详细状态查询
enable/disable 控制tomcat开机自启行为" | column -t
    echo -e "
可以通过在选项名称后面添加help字段以查看各个选项后面的详细配置信息，例：

${toolName} set help

以上命令将查看set选项后面如何填写参数以及相关的限制条件等
"
    exit 0
}

HelpSet(){
    echo -e "
set 用于设置网页访问端口号和停止tomcat的监听端口号
两个端口号必须同时设置且顺序不能错，例：

${toolName} set A B

A：设置网页访问端口号
B：设置停止tomcat的监听端口号
A和B均为1-65536之间的纯数字

如果设置错误，可以重复设置，每次设置均会覆盖上一次设置的值
"
    exit 0
}

HelpAdd(){
    echo -e "
add 用于设置要添加的环境变量，一次只能添加一个，如果有双引号的需求，需要使用单引号(')将整行变量都括起来
以下四行写法实现的是 tomcat 设置 JVM 最大堆大小为 2048m 并跳过扫描三个 jar 包：
my-jar-1.0.jar
my-jar-2.0.jar
my-jar-4.0.jar

${toolName} add 'CATALINA_OPTS=\"\$CATALINA_OPTS -Dtomcat.util.scan.StandardJarScanFilter.jarsToSkip=my-jar-1.0.jar\"'
${toolName} add 'CATALINA_OPTS=\"\$CATALINA_OPTS -Dtomcat.util.scan.StandardJarScanFilter.jarsToSkip.my-jar-2.0.jar\"'
${toolName} add 'CATALINA_OPTS=\"\$CATALINA_OPTS -Dtomcat.util.scan.StandardJarScanFilter.jarsToSkip.my-jar-4.0.jar\"'
${toolName} add 'CATALINA_OPTS=\"\$CATALINA_OPTS -Xmx2048m\"'

注意：
1. 以上四行参数中 jarsToSkip 后面第一行是 \"=\" ，相同变量从第二行起均为 \".\"
2. add后跟的参数只要不是 help 均会直接作为环境变量写入配置文件,所以如果写错，请使用 list 选项查看其对应的行号，然后使用 delete 选项删除
"
    exit 0
}

HelpList(){
    echo -e "
list 用于显示配置文件中已有哪些环境变量、tomcat访问和停止服务所需端口号和服务的工作及开机自启状态，
其中环境变量展示方式为一行一个或一组环境变量，每行为显示此格式：

行号：环境变量名=环境变量参数

例：
1:JRE_HOME=/usr/java/latest
2:CATALINA_PID=\"\$CATALINA_BASE/tomcat.pid\"
"
    exit 0
}

HelpDelete(){
    echo -e "
delete 用于删除已经设置过的环境变量，其后面跟上行号，可以一次添加多个行号以删除多行。
具体行号可以通过list命令获取。例：
删除配置环境变量中第5行的环境变量：

${toolName} delete 5

删除配置环境变量中第5、6、10行的环境变量：

${toolName} delete 5 6 10
"
    exit 0
}

HelpControl(){
    echo -e "
start/stop/restart/enable/disable 用于控制tomcat服务。

启动tomcat：
${toolName} start

停止tomcat：
${toolName} stop

重启tomcat：
${toolName} restart

查询tomcat：
${toolName} status

设置tomcat开机自启：
${toolName} enable

禁用tomcat开机自启
${toolName} disable
"
    exit 0
}

HelpLog(){
    echo -e "
log 用于删除已经设置过的环境变量，其后面跟上行号，可以一次添加多个行号以删除多行。
具体行号可以通过list命令获取。例：
删除配置环境变量中第5行的环境变量：

${toolName} delete 5

删除配置环境变量中第5、6、10行的环境变量：

${toolName} delete 5 6 10
"
    exit 0
}

SetPort(){
    # 传入参数数组并检查help情况（数组改名麻烦还耗费性能时间，如果有help也放portList里面）
    local portList i j accessPort shutdownPort
    portList=()
    for i in "$@" ; do
        portList+=("${i}")
    done

    if [[ ${portList[0]} == "help" ]]; then
        if [[ -z ${portList[1]} ]]; then
            HelpSet
        else
            _error "如果想查看 set 选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -z ${portList[0]} ]]; then
        _error "未填写参数，修改未生效，退出中"
        exit 1
    fi

    # 传输数组元素的合规性判断并最终锁定两个端口号
    _info "正在校验端口号"
    for j in "${portList[@]}" ; do
        if [[ ! ${j} =~ ^[0-9]+$ ]] || [[ ${#portList[@]} -ne 2 ]]; then
            _error "必须且只能同时输入两个纯数字的端口号，修改未生效，退出中"
            exit 1
        else
            if [[ ${j} -lt 1 || ${j} -gt 65536 ]]; then
                _error "设置的端口号: ${j}"
                _error "此端口号不在 1-65536 范围内，修改未生效，退出中"
                exit 1
            else
                if lsof -i:"${j}" >/dev/null 2>&1; then
                    _error "设置的端口号: ${j}"
                    _error "此端口号已被占用，修改未生效，请检查，退出中"
                    exit 1
                fi
            fi
        fi
    done
    accessPort="${portList[0]}"
    shutdownPort="${portList[1]}"
    if [ "${accessPort}" == "${shutdownPort}" ]; then
        _error "禁止设置两个相同端口号，修改未生效，退出中"
        exit 1
    fi
    _success "端口号校验通过"
    _successnoblank "网页访问端口号：${accessPort}"
    _successnoblank "终止监听端口号：${shutdownPort}"

    # 停止tomcat并为已屏蔽的定制配置文件创建新的副本，将两个端口号替换进副本
    case $(systemctl is-active ${tomcatService}) in
    "active")
        _info "检测到 tomcat 已启动，正在停止服务"
        if systemctl stop ${tomcatService}; then
            _success "tomcat 服务已停止"
        else
            _error "tomcat 服务停止失败，请检查，修改未生效，退出中"
            exit 1
        fi
        ;;
    "inactive"|"failed"|"unknown")
        _success "检测到 tomcat 已停止或未启动服务"
        ;;
    *)
        _error "异常情况，请检查 tomcat 状态，修改未生效，退出中"
        exit 1
    esac

    _info "开始修改端口号"
    sed -i -e "\
        s/Server port=\".*.\" shutdown=\"SHUTDOWN\"/Server port=\"${shutdownPort}\" shutdown=\"SHUTDOWN\"/g; \
        s/Connector port=\".*.\" protocol=\"HTTP\/1.1\"/Connector port=\"${accessPort}\" protocol=\"HTTP\/1.1\"/g" \
        ${tomcatPath}/conf/server.xml

    if systemctl start ${tomcatService}; then
        _success "tomcat 服务已启动，端口号修改完成"
    else
        _error "tomcat 服务启动失败，请检查，但端口号已修改，请解决 tomcat 异常后重新设置端口号"
        _error "退出中"
        exit 1
    fi
}

AddEnvVariable(){
    # 传入参数数组并检查help情况
    local elementList i
    elementList=()
    for i in "$@" ; do
        elementList+=("${i}")
    done

    if [[ ${elementList[0]} == "help" ]]; then
        if [[ -z ${elementList[1]} ]]; then
            HelpAdd
        else
            _error "如果想查看 add 选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -z ${elementList[0]} ]]; then
        _error "未填写参数，修改未生效，退出中"
        exit 1
    fi

    # 添加新环境变量，一次调用加一行
    echo "${elementList[0]}" >> ${tomcatPath}/bin/setenv.sh
    if [[ -f ${tomcatPath}/conf/server.xml ]]; then
        if systemctl restart ${tomcatService}; then
            _success "tomcat 服务已重启成功，新环境变量添加完成"
        else
            _error "tomcat 服务重启失败，请检查，但设置的参数已写入"
            _error "请解决 tomcat 异常后使用 list 选项查看其对应的行号，然后使用 delete 选项删除新增的参数"
            _error "退出中"
            exit 1
        fi
    else
        _warning "tomcat 启动所需配置文件不存在，请通过 set 选项设置端口号以自动生成一个，已跳过重启服务"
        _success "新环境变量添加完成"
    fi
}

DeleteEnvVariable(){
    # 传入参数数组并检查help情况
    local elementList i j k lineNum validLineNum
    elementList=()
    for i in "$@" ; do
        elementList+=("${i}")
    done

    if [[ ${elementList[0]} == "help" ]]; then
        if [[ -z ${elementList[1]} ]]; then
            HelpDelete
        else
            _error "如果想查看 delete 选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -z ${elementList[0]} ]]; then
        _error "未填写参数，修改未生效，退出中"
        exit 1
    fi

    # 存放环境变量文件的行数
    lineNum=$(wc -l ${tomcatPath}/bin/setenv.sh | awk '{print $1}')
    # 检查传入行数合规性
    for j in "${elementList[@]}" ; do
        if [[ ${j} =~ ^[0-9]+$ ]]; then
            if [[ ${j} -le ${lineNum} ]]; then
                validLineNum+="${j}d;"
            else
                _error "设置的行号 ${j} 在配置文件中不存在，修改未生效，退出中"
                exit 1
            fi
        else
            _error "只能输入通过 list 选项查看到的行号，应用未生效，退出中"
            exit 1
        fi
    done

    # 删除文件中所有指定行
    sed -i "${validLineNum}" ${tomcatPath}/bin/setenv.sh
    if [[ -f ${tomcatPath}/conf/server.xml ]]; then
        if systemctl restart ${tomcatService}; then
            _success "tomcat 服务已重启成功，环境变量删除完成"
        else
            _error "tomcat 服务重启失败，请检查，但指定行对应的参数已删除，请解决 tomcat 异常"
            _error "退出中"
            exit 1
        fi
    else
        _warning "tomcat 启动所需配置文件不存在，请通过 set 选项设置端口号以自动生成一个，已跳过重启服务"
        _success "环境变量删除完成"
    fi
}

ListEnvVariable(){
    # 传入参数数组并检查help情况
    local elementList i shutdownPort accessPort isEnable isActive
    elementList=()
    for i in "$@" ; do
        elementList+=("${i}")
    done

    if [[ ${elementList[0]} == "help" ]]; then
        if [[ -z ${elementList[1]} ]]; then
            HelpList
        else
            _error "如果想查看 list 选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -n ${elementList[0]} ]]; then
        _error "list 选项后面禁止填写除help以外的参数，退出中"
        exit 1
    fi

    isEnable=$(systemctl is-enabled ${tomcatService})
    isActive=$(systemctl is-active ${tomcatService})
    if [[ -f ${tomcatPath}/conf/server.xml ]]; then
        shutdownPort=$(grep -o '^<Server port=".*." shutdown="SHUTDOWN">' ${tomcatPath}/conf/server.xml | awk '{print $2}' | cut -d'"' -f2)
        accessPort=$(grep -o '<Connector port=".*." protocol="HTTP/1.1"' ${tomcatPath}/conf/server.xml | awk '{print $2}' | cut -d'"' -f2)

        _warningnoblank "网页访问的端口号：${accessPort}"
        _warningnoblank "停止进程的监听端口号：${shutdownPort}"
        _warningnoblank "是否开机自启：${isEnable}"
        _warningnoblank "当前状态：${isActive}"
        echo
        _warningnoblank "以下是自定义的环境变量："
    else
        accessPort="读取失败"
        shutdownPort="读取失败"
        _error "服务端配置文件不存在，请设置所需端口号"

        _errornoblank "网页访问的端口号：${accessPort}"
        _errornoblank "停止进程的监听端口号：${shutdownPort}"
        _errornoblank "是否开机自启：${isEnable}"
        _errornoblank "当前状态：${isActive}"
        echo
        _errornoblank "以下是自定义的环境变量："
    fi
    if [ ! -f ${tomcatPath}/bin/setenv.sh ]; then
        _print "暂未设置过环境变量"
    else
        cat -n ${tomcatPath}/bin/setenv.sh
    fi
}

LogOperation(){
    # 传入参数数组并检查help情况
    local elementList i
    elementList=()
    for i in "$@" ; do
        elementList+=("${i}")
    done

    if [[ ${elementList[0]} == "help" ]]; then
        if [[ -z ${elementList[1]} ]]; then
            HelpLog
        else
            _error "如果想查看 log 选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -z ${elementList[0]} ]]; then
        _error "未填写参数，功能未生效，退出中"
        HelpLog
    fi

    case "${elementList[1]}" in
        "show")
            command ...
            ;;
        "get")
            command ...
            ;;
        *)
            command ...
            ;;
    esac
}

ControlOperation(){
    # 传入参数数组并检查help情况
    local elementList i
    elementList=()
    for i in "$@" ; do
        elementList+=("${i}")
    done

    if [[ ${elementList[1]} == "help" ]]; then
        if [[ -z ${elementList[2]} ]]; then
            HelpControl
        else
            _error "如果想查看控制选项的具体用法，help 字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
    elif [[ -n ${elementList[1]} ]]; then
        _error "控制选项禁止填写除help以外的参数，控制未生效，退出中"
        exit 1
    fi

    if [[ ! -f ${tomcatPath}/conf/server.xml ]]; then
        _error "服务端配置文件不存在，请先设置所需端口号，退出中"
        exit 1
    fi

    # 根据参数指派功能
    case ${elementList[0]} in
    "start")
        if systemctl start ${tomcatService}; then
            _success "已执行启动服务功能"
        else
            _error "出现意外，请检查"
        fi
        ;;
    "stop")
        if systemctl stop ${tomcatService}; then
            _success "已执行停止服务功能"
        else
            _error "出现意外，请检查"
        fi
        ;;
    "restart")
        if systemctl restart ${tomcatService}; then
            _success "已执行重启服务功能"
        else
            _error "出现意外，请检查"
        fi
        ;;
    "status")
        local returnCode
        systemctl status -l --no-pager ${tomcatService}
        returnCode=$?
        if [[ ${returnCode} -eq 3 ]] || [[ ${returnCode} -eq 0 ]]; then
            _success "已执行查询服务功能"
        else
            _warning "若执行 stop 后再执行 status 时没有报错输出或输出143返回码"
            _warning "则一般情况下是 tomcat 对于系统对其发送停止信号的正常反馈表现"
        fi
        ;;
    "enable")
        if systemctl enable ${tomcatService}; then
            _success "已执行启用开机自启功能"
        else
            _error "出现意外，请检查"
        fi
        ;;
    "disable")
        if systemctl disable ${tomcatService}; then
            _success "已执行禁用开机自启功能"
        else
            _error "出现意外，请检查"
        fi
        ;;
    esac
}

allElementList=("${@:1}")
if ! which lsof >/dev/null 2>&1; then
    _error "未安装lsof，退出中"
    exit 1
fi

case ${allElementList[0]} in
    "help"|"-h"|"--help")
        if [[ -n ${allElementList[1]} ]]; then
            _error "如果想查看程序所有选项的具体用法，help字段后面禁止添加其他参数或选项，退出中"
            exit 1
        fi
        HelpOperation
    ;;
    "set")
        SetPort "${allElementList[@]:1}"
    ;;
    "add")
        AddEnvVariable "${allElementList[@]:1}"
    ;;
    "delete")
        DeleteEnvVariable "${allElementList[@]:1}"
    ;;
    "list")
        ListEnvVariable "${allElementList[@]:1}"
    ;;
    "start"|"stop"|"restart"|"status"|"enable"|"disable")
        ControlOperation "${allElementList[@]}"
    ;;
#    "log")
#        LogOperation "${allElementList[@]:1}"
#    ;;
    *)
        _error "没有此名称的选项，请使用以下命令查看帮助菜单："
        _warningnoblank "${toolName} help"
        HelpOperation
esac
