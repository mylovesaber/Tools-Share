#!/bin/bash
# 作者: Oliver
# 功能: 为后续所有脚本提供基于作者自定义规则的自检流程提供稳定免密环境的部署功能
# 日期: 2022-07-23

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

_checkroot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

# 变量
DEPLOY_GROUP_NAME=
REMOVE_GROUP_NAME=
DEPLOY_NODE_INFO=
REMOVE_NODE_ALIAS=
KEY_TYPE=
CHECK_DEP_SEP=0
CONFIRM_CONTINUE=0
HELP=0
GEN_SH_NAME="generated-script"

if ! ARGS=$(getopt -a -o G:,g:,N:,n:,t:,s,y,h -l deploy_group_name:,remove_group_name:,deploy_node_info:,remove_node_alias:,type:,check_dep_sep,yes,help -- "$@")
then
    _error "脚本中没有此无参选项或此选项为有参选项"
    exit 1
elif [ -z "$1" ]; then
    _error "没有设置选项"
    exit 1
elif [ "$1" == "-" ]; then
    _error "选项写法出现错误"
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in
    # 始末端同步和备份路径
    -G | --deploy_group_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            DEPLOY_GROUP_NAME="$2"
        fi
        shift
        ;;
    -g | --remove_group_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            REMOVE_GROUP_NAME="$2"
        fi
        shift
        ;;
    -N | --deploy_node_info)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            DEPLOY_NODE_INFO="$2"
        fi
        shift
        ;;
    -n | --remove_node_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            REMOVE_NODE_ALIAS="$2"
        fi
        shift
        ;;
    -t | --type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            KEY_TYPE="$2"
        fi
        shift
        ;;

    # 其他选项
    -s | --check_dep_sep)
        CHECK_DEP_SEP=1
        ;;
    -y | --yes)
        CONFIRM_CONTINUE=1
        ;;
    -h | --help)
        HELP=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

EnvCheck(){
    _info "环境自检中，请稍后"
    # 检查必要软件包安装情况(集成独立检测依赖功能)
    #_info "检查脚本使用的有关软件安装情况"
    appList="tput scp pwd basename sort tail tee md5sum ip ifconfig shuf column sha256sum dirname stat"
    appNotInstalled=""
    for i in ${appList}; do
        if which "$i" >/dev/null 2>&1; then
            [ "${CHECK_DEP_SEP}" == 1 ] && _success "$i 已安装"
        else
            [ "${CHECK_DEP_SEP}" == 1 ] && _error "$i 未安装"
            appNotInstalled="${appNotInstalled} $i"
        fi
    done
    if [ -n "${appNotInstalled}" ]; then
        _error "未安装的软件为: ${appNotInstalled}"
        _error "当前运行环境不支持部分脚本功能，为安全起见，此脚本在重新适配前运行都将自动终止进程"
        exit 1
    elif [ -z "${appNotInstalled}" ]; then
        [ "${CHECK_DEP_SEP}" == 1 ] && _success "脚本正常工作所需依赖全部满足要求" && exit 0
    fi

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
}

CheckOption(){
    [ "${CHECK_DEP_SEP}" -eq 1 ] && EnvCheck && exit 0
    if [ -n "${DEPLOY_GROUP_NAME}" ] && [ -n "${DEPLOY_NODE_INFO}" ] && [ -n "${KEY_TYPE}" ] && [ -z "${REMOVE_GROUP_NAME}" ] && [ -z "${REMOVE_NODE_ALIAS}" ]; then
        DeployCheck
    elif [ -n "${DEPLOY_GROUP_NAME}" ] && [ -n "${DEPLOY_NODE_INFO}" ] && [ -z "${KEY_TYPE}" ] && [ -z "${REMOVE_GROUP_NAME}" ] && [ -z "${REMOVE_NODE_ALIAS}" ]; then
        DeployCheck
    # elif [ -n "${REMOVE_GROUP_NAME}" ] && [ -n "${REMOVE_NODE_ALIAS}" ] && [ -z "${DEPLOY_GROUP_NAME}" ] && [ -z "${DEPLOY_NODE_INFO}" ] && [ -z "${KEY_TYPE}" ]; then
    #     RemoveNodeCheck
    # elif [ -n "${REMOVE_GROUP_NAME}" ] && [ -z "${REMOVE_NODE_ALIAS}" ] && [ -z "${DEPLOY_GROUP_NAME}" ] && [ -z "${DEPLOY_NODE_INFO}" ] && [ -z "${KEY_TYPE}" ]; then
    #     RemoveGroupCheck
    else
        # _error "本脚本只有安装和卸载共四种可重复使用的选项组合方式，请仔细对比帮助信息并检查缺失或多输入的选项和参数"
        _error "本脚本只有两种可重复使用的选项组合方式，请仔细对比帮助信息并检查缺失或多输入的选项和参数"
        _errornoblank "1. 部署一个免密节点组并为该组添加一个或多个节点信息:"
        _warningnoblank "
        -G | --deploy_group_name 设置免密节点组名称
        -N | --deploy_node_info 设置组内每个节点的信息(每个节点信息填写顺序为：节点别名,登录名,IP,端口号，不同节点信息用空格隔开)
        -t | --type 设置生成密钥的类型(可选类型:dsa/ecdsa/ed25519/rsa/rsa1)"|column -t
        echo ""

        _errornoblank "2. 向已存在的免密节点组追加一个或多个节点信息:"
        _warningnoblank "
        -G | --deploy_group_name 设置免密节点组名称
        -N | --deploy_node_info 设置组内每个节点的信息(每个节点信息填写顺序为：节点别名,登录名,IP,端口号，不同节点信息用空格隔开)"|column -t
        echo ""

        # _errornoblank "3. 卸载指定免密节点组中的一个或多个节点信息:"
        # _warningnoblank "
        # -g | --remove_group_name 设置需要卸载的节点所在免密节点组名称
        # -n | --remove_node_alias 设置指定免密节点组中的一个或多个节点别名"|column -t
        # echo ""

        # _errornoblank "4. 卸载指定免密节点组及其所有节点信息:"
        # _warningnoblank "
        # -g | --remove_group_name 设置需要完整卸载的免密节点组名称"|column -t
        # echo ""

        _errornoblank "执行任意一种功能均需设置确认执行的无参选项: -y 或 --yes"
        _errornoblank "否则脚本只进行检测但不会实际运行"
        _warningnoblank "几种组合方式中，任何选项均没有次序要求"
        exit 1
    fi
}

DeployCheck(){
    # 参数传入规范检查
    # 检测免密节点组名
    _info "正在检测免密节点组名"
    count=$(wc -c <<< "${DEPLOY_GROUP_NAME}")
    if [[ ! "${DEPLOY_GROUP_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
        _error "需部署的免密节点组名格式有错，只支持大小写字母、数字、下划线(_)和连字符(-)，请检查"
        exit 1
    elif grep -wq "${DEPLOY_GROUP_NAME}" <<< "${RESERVED_NAMES[@]}"; then
        _error "需部署的免密节点组名禁止使用系统内置命令名称!"
        exit 1
    elif [[ $count -lt 3 || $count -gt 32 ]]; then
        _error "需部署的免密节点组名字符数量必须控制在 3-32 个(包括 3 和 32 个字符)!"
        exit 1
    fi

    if [ -d /root/.ssh/"${DEPLOY_GROUP_NAME}" ]; then
        if [ ! -f /root/.ssh/"${DEPLOY_GROUP_NAME}"/.backup_config ]; then
            _error "已存在同名非本脚本创建的文件夹，请更换名称"
            exit 1
        fi
    fi
    GROUP_EXIST=0
    if [ -f /root/.ssh/config ]; then
        mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '/Include/{print $2}' /root/.ssh/config)
        # 代码段开始行，以下这段防止后续部署失败时往 config 文件写入了本不存在的节点组信息或节点组内没有节点信息，对遍历出来的节点组名对比实际文件夹排除掉没有对应文件夹或节点组内没有节点信息的节点组名
        for i in "${GROUP_NAME_IN_FILE[@]}";do
            if [ -d /root/.ssh/"${i}" ] && [ -n "$(find /root/.ssh/"${i}" -maxdepth 1 -type f -name "config-${i}-*")" ]; then
                TEMP_GROUP_NAME_IN_FILE+=("${i}")
            fi
        done
        TEMP_GROUP_NAME_IN_FILE_STRING=$(declare -p TEMP_GROUP_NAME_IN_FILE)
        eval "declare -A GROUP_NAME_IN_FILE=""${TEMP_GROUP_NAME_IN_FILE_STRING#*=}"
        # 代码段结束行，以上这段在后面写入 config 时有判断是否重复，重复就跳过

        if grep -wq "${DEPLOY_GROUP_NAME}" <<< "${GROUP_NAME_IN_FILE[@]}"; then
            _success "${DEPLOY_GROUP_NAME} 免密节点组已存在"
            GROUP_EXIST=1
        else
            _warning "免密节点组不存在，将创建对应节点组"
        fi
    fi
    if [ "${GROUP_EXIST}" -eq 0 ]; then
        case "${KEY_TYPE}" in
            "dsa")shift;;
            "ecdsa")shift;;
            "ed25519")shift;;
            "rsa")shift;;
            "rsa1")shift;;
            *) _error "密钥类型填写错误，选项: -t | --type，可选参数: dsa | ecdsa | ed25519 | rsa | rsa1";exit 1
        esac
    elif [ "${GROUP_EXIST}" -eq 1 ]; then
        if [ -n "${KEY_TYPE}" ]; then
            _error "向已有免密组添加节点不需要设置密钥类型，请删除该选项"
            exit 1
        fi
    fi

    _info "正在检测节点信息完整性"
    RESERVED_NAMES=('adm' 'admin' 'audio' 'backup' 'bin' 'cdrom' 'crontab' 'daemon' 'dialout' 'dip' 'disk' 'fax' 'floppy' 'fuse' 'games' 'gnats' 'irc' 'kmem' 'landscape' 'libuuid' 'list' 'lp' 'mail' 'man' 'messagebus' 'mlocate' 'netdev' 'news' 'nobody' 'nogroup' 'operator' 'plugdev' 'proxy' 'root' 'sasl' 'shadow' 'src' 'ssh' 'sshd' 'staff' 'sudo' 'sync' 'sys' 'syslog' 'tape' 'tty' 'users' 'utmp' 'uucp' 'video' 'voice' 'whoopsie' 'www-data')
    NODE_ALIAS=()
    USER_NAME=()
    IP_ADDRESS=()
    PORT_NUMBER=()
    ERROR_NODE_INFO=()
    # 检测节点信息是不是四段式
    # 将字符串转换成另一个数组，然后将该数组重命名
    for i in ${DEPLOY_NODE_INFO}; do
        CONVERT_TO_ARRAY+=("$i")
    done
    CONVERT_TO_ARRAY_STRING=$(declare -p CONVERT_TO_ARRAY)
    eval "declare -A DEPLOY_NODE_INFO=""${CONVERT_TO_ARRAY_STRING#*=}"

    for i in "${DEPLOY_NODE_INFO[@]}"; do
        if [ "$(awk -F ',' '{print NF}' <<< "${i}")" -ne 4 ]; then
            ERROR_NODE_INFO+=("$i")
        else
            mapfile -t -O "${#NODE_ALIAS[@]}" NODE_ALIAS < <(awk -F ',' '{print $1}' <<< "${i}")
            mapfile -t -O "${#USER_NAME[@]}" USER_NAME < <(awk -F ',' '{print $2}' <<< "${i}")
            mapfile -t -O "${#IP_ADDRESS[@]}" IP_ADDRESS < <(awk -F ',' '{print $3}' <<< "${i}")
            mapfile -t -O "${#PORT_NUMBER[@]}" PORT_NUMBER < <(awk -F ',' '{print $4}' <<< "${i}")
        fi
    done

    # 检查本机 IP 对应的节点别名，如果是新建节点，则新增节点信息中必须包含本机节点信息，否则报错退出
    # 如果向已有节点组添加节点，则节点组中必须已有本机节点信息，否则报错退出
    LOCAL_ALIAS=
    NUM=
    if [ "${GROUP_EXIST}" -eq 0 ]; then
        for i in "${!IP_ADDRESS[@]}";do
            if [ "${LOCAL_IP}" = "${IP_ADDRESS[$i]}" ]; then
                NUM=$i
                break
            fi
        done
        if [ -z "${NUM}" ]; then
            _error "新增节点信息中必须包含本机节点信息"
            exit 1
        else
            LOCAL_ALIAS="${NODE_ALIAS[$NUM]}"
        fi
    elif [ "${GROUP_EXIST}" -eq 1 ]; then
        mapfile -t EXIST_NODE_FILE_NAME < <(find /root/.ssh/"${DEPLOY_GROUP_NAME}" -maxdepth 1 -type f -name "config-${DEPLOY_GROUP_NAME}-*")
        for i in "${EXIST_NODE_FILE_NAME[@]}";do
            if [ "$(awk '/HostName/{print $2}' "${i}")" = "${LOCAL_IP}" ];then
                LOCAL_ALIAS=$(awk '/Host\ /{print $2}' "${i}")
            fi
        done
        if [ -z "${LOCAL_ALIAS}" ]; then
            _error "指定的节点组中必须存在本机节点信息"
            exit 1
        fi
    fi

    if [ "${GROUP_EXIST}" -eq 0 ]; then
        if [ "${#DEPLOY_NODE_INFO[@]}" -eq 1 ]; then
            _error "新创建的节点组中至少要有两个节点的配置"
            exit 1
        fi
    fi
    if [ "${#ERROR_NODE_INFO[@]}" -gt 0 ]; then
        _error "节点信息必须包括四个信息: 别名、用户名、ipv4地址、端口号，四个信息通过英文逗号(,)分隔，次序不能出错"
        _error "例: alias_name,root,1.1.1.1,22"
        _error "以下是全部错误节点信息，请检查:"
        for i in "${ERROR_NODE_INFO[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success "所有节点信息完整"
    
    # 检测节点别名合法性
    _info "正在检测节点别名合法性"
    ERROR_NODE_ALIAS_FORMAT=()
    ERROR_NODE_ALIAS_NAME=()
    ERROR_NODE_ALIAS_LENGTH=()
    ERROR_SAME_NODE_ALIAS=()
    for i in "${NODE_ALIAS[@]}"; do
        count=$(wc -c <<< "${i}")
        if [[ ! "${i}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
            ERROR_NODE_ALIAS_FORMAT+=("$i")
        elif grep -wq "${i}" <<< "${RESERVED_NAMES[@]}"; then
            ERROR_NODE_ALIAS_NAME+=("$i")
        elif [[ $count -lt 2 || $count -gt 32 ]]; then
            ERROR_NODE_ALIAS_LENGTH+=("$i")
        fi
    done
    if [ "${#ERROR_NODE_ALIAS_FORMAT[@]}" -gt 0 ]; then
        _error "需部署的免密节点别名格式有错，只支持大小写字母、数字、下划线(_)和连字符(-)"
        _error "例: This_is-123-Name"
        _error "以下是格式错误的节点别名，请检查:"
        for i in "${ERROR_NODE_ALIAS_FORMAT[@]}"; do
            echo "$i"
        done
        exit 1
    elif [ "${#ERROR_NODE_ALIAS_NAME[@]}" -gt 0 ]; then
        _error "节点别名禁止使用系统内置命令名称!"
        _error "以下是使用系统内置命令的节点别名，请检查:"
        for i in "${ERROR_NODE_ALIAS_NAME[@]}"; do
            echo "$i"
        done
        exit 1
    elif [ "${#ERROR_NODE_ALIAS_LENGTH[@]}" -gt 0 ]; then
        _error "节点别名字符数量必须控制在 3-32 个(包括 3 和 32 个字符)!"
        _error "以下是长度超过限制的节点别名，请检查:"
        for i in "${ERROR_NODE_ALIAS_LENGTH[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    if [ "${GROUP_EXIST}" -eq 1 ]; then
        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${DEPLOY_GROUP_NAME}"/config-"${DEPLOY_GROUP_NAME}"-*|awk '/Host / {print $2}')
        for i in "${NODE_ALIAS[@]}"; do
            if grep -wq "${i}" <<< "${HOST_ALIAS[@]}"; then
                ERROR_SAME_NODE_ALIAS+=("$i")
            fi
        done
        if [ "${#ERROR_SAME_NODE_ALIAS[@]}" -gt 0 ]; then
            _error "${DEPLOY_GROUP_NAME} 免密节点组中存在同名节点别名，同免密组内的每一个节点别名必须是独一无二的"
            _error "以下是同名节点别名，请检查:"
            for i in "${ERROR_SAME_NODE_ALIAS[@]}"; do
                echo "$i"
            done
            exit 1
        fi
    fi
    _success "节点别名检测通过"

    # 检测用户名合法性
    _info "正在检测用户名合法性"
    ERROR_USER_NAME=()
    for i in "${USER_NAME[@]}"; do
        # if [[ ! "${i}" =~ ^[0-9a-zA-Z_-]*$ ]]; then  # 未来考虑增加非root用户部署
        if [[ ! "${i}" = "root" ]]; then
            ERROR_USER_NAME+=("$i")
        fi
    done
    if [ "${#ERROR_USER_NAME[@]}" -gt 0 ]; then
        _error "用户名写法有错，暂时只支持 root"
        exit 1
    fi
    _success "用户名检测通过"
    
    # 检测 IPV4 地址合法性
    _info "正在检测 IPV4 地址合法性"
    ERROR_IP_ADDRESS=()
    for i in "${IP_ADDRESS[@]}"; do
        if [[ ! "${i}" =~ ^(([1-9]|[1-9][0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.(([1-9]?[0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.){2}([1-9]?[0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5])))$ ]]; then
            ERROR_IP_ADDRESS+=("$i")
        fi
    done
    if [ "${#ERROR_IP_ADDRESS[@]}" -gt 0 ]; then
        _error "需部署的免密节点 IP 写法有错，只支持 IPV4 地址"
        _error "以下是全部错误节点 IP，请检查:"
        for i in "${ERROR_IP_ADDRESS[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success " IPV4 地址格式全部正确"

    # 检测 IPV4 地址连通性
    _info "正在检测 IPV4 地址连通性"
    UNREACHABLE_IP_ADDRESS=()
    for i in "${IP_ADDRESS[@]}"; do
        if ! timeout 5s ping -c2 -W1 "${i}" > /dev/null 2>&1; then
            UNREACHABLE_IP_ADDRESS+=("$i")
        fi
    done
    if [ "${#UNREACHABLE_IP_ADDRESS[@]}" -gt 0 ]; then
        _error "以下 IP 地址无法 ping 通，可能 IP 地址填写错误或者宕机了？"
        for i in "${UNREACHABLE_IP_ADDRESS[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success " IPV4 地址均可连通"

    if [ "${GROUP_EXIST}" -eq 1 ]; then
        MARK=0
        _info "开始检查已加入免密节点组中的节点免密情况"
        # HOST_ALIAS 数组在上面节点别名合法性中被定义
        for i in "${HOST_ALIAS[@]}";do
            if ssh -o BatchMode=yes "${i}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
                VALIDATION_SUCCESS_LIST+=("${i}")
            else
                VALIDATION_FAILURE_LIST+=("${i}")
                MARK=1
            fi
        done
        if [ "${MARK}" -eq 1 ]; then
            _warning "存在免密故障的节点"
        elif [ "${MARK}" -eq 0 ]; then
            _success "免密节点检测通过"
        fi
    fi

    # 检测端口号合法性
    _info "正在检测端口号合法性"
    ERROR_PORT_NUMBER=()
    for i in "${PORT_NUMBER[@]}"; do
        if [[ ! "${i}" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
            ERROR_PORT_NUMBER+=("$i")
        fi
    done
    if [ "${#ERROR_PORT_NUMBER[@]}" -gt 0 ]; then
        _error "需部署的免密节点端口号写法有错，"
        _error "以下是全部错误端口号，请检查:"
        for i in "${ERROR_PORT_NUMBER[@]}"; do
            echo "$i"
        done
        exit 1
    fi
    _success " 端口号检测通过"

    # 汇总
    _success "已收集所需信息，请检查以下汇总信息:"
    if [ ! -d /root/.ssh ]; then
        _warning ".ssh 文件夹未找到，确认部署将自动创建"
    elif [ ! -f /root/.ssh/config ]; then
        _warning "核心配置文件未找到，即将创建核心配置文件"
    fi
    if [ ! -d /root/.ssh ] || [ ! -f /root/.ssh/config ] || [ "${GROUP_EXIST}" -eq 0 ]; then
        _info "即将创建 ${DEPLOY_GROUP_NAME} 免密节点组"
        _info "已指定密钥类型: ${KEY_TYPE}"
    fi
    
    _info "即将向 ${DEPLOY_GROUP_NAME} 免密节点组添加以下节点:"
    for i in "${!DEPLOY_NODE_INFO[@]}";do
        j=$(( i + 1 ))
        echo "
        节点信息$j
        别名: ${NODE_ALIAS[$i]}
        用户名: ${USER_NAME[$i]}
        IP地址: ${IP_ADDRESS[$i]}
        端口号: ${PORT_NUMBER[$i]}"|column -t
        echo ""
    done

    if [ "${#VALIDATION_SUCCESS_LIST[@]}" -gt 0 ];then
        _info "以下是 ${DEPLOY_GROUP_NAME} 免密节点组中免密检测通过的节点名:"
        for i in "${VALIDATION_SUCCESS_LIST[@]}";do
            _success "${i}"
        done
    fi
    if [ "${#VALIDATION_FAILURE_LIST[@]}" -gt 0 ];then
        _info "以下是 ${DEPLOY_GROUP_NAME} 免密节点组中免密检测失败的节点名:"
        for i in "${VALIDATION_FAILURE_LIST[@]}";do
            _warning "${i}"
        done
        _warning "继续执行将创建用于修复免密检测失败节点和部署新增节点的子脚本"
    fi
    if [ "${CONFIRM_CONTINUE}" -eq 1 ]; then
        Deploy "${GROUP_EXIST}"
        exit 0
    else
        _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行部署"
        exit 0
    fi
}

Deploy(){
    _info "开始部署"
    if [ ! -d /root/.ssh ]; then
        _warning ".ssh 文件夹未创建，开始创建"
        mkdir -p /root/.ssh
    fi
    if [ "${GROUP_EXIST}" -eq 0 ]; then
        _info "正在创建免密节点组"
        mkdir -p /root/.ssh/"${DEPLOY_GROUP_NAME}"
    fi
    if [ ! -f /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-key ] || [ ! -f /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-authorized_keys ]; then
        _info "正在生成并部署公密钥"
        ssh-keygen -t "${KEY_TYPE}" -q -N "" -C "" -f /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-key <<< y >/dev/null 2>&1
        mv /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-key.pub /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-authorized_keys
    fi

    _info "正在添加免密节点组至免密组配置列表"
    if [ ! -f /root/.ssh/config ]; then
        echo "Include ${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-*" > /root/.ssh/config
    else
        if ! grep "${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-\*" /root/.ssh/config >/dev/null 2>&1; then
            sed -i "1s/^/Include ${DEPLOY_GROUP_NAME}\/config-${DEPLOY_GROUP_NAME}-*\n/" /root/.ssh/config
        fi
    fi
    ln -f /root/.ssh/config /root/.ssh/"${DEPLOY_GROUP_NAME}"/.backup_config

    _info "正在生成免密节点配置"
    for i in "${!DEPLOY_NODE_INFO[@]}";do
        cat >> /root/.ssh/"${DEPLOY_GROUP_NAME}"/config-"${DEPLOY_GROUP_NAME}"-"${NODE_ALIAS[$i]}" << EOF
Host ${NODE_ALIAS[$i]}
HostName ${IP_ADDRESS[$i]}
User ${USER_NAME[$i]}
Port ${PORT_NUMBER[$i]}
StrictHostKeyChecking no
IdentityFile ~/.ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-key

EOF
    done

    _info "正在设置权限"
    chmod 700 /root/.ssh
    [ -f /root/.ssh/known_hosts ] && chmod 644 /root/.ssh/known_hosts
    chmod -R 644 /root/.ssh/config /root/.ssh/"${DEPLOY_GROUP_NAME}"
    chmod 600 /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-key

    # 向 /etc/ssh/sshd_config 添加公钥文件路径，如果已存在就跳过
    _info "正在检查公钥文件路径"
    [[ "$(grep "AuthorizedKeysFile" /etc/ssh/sshd_config)" =~ "#" ]] && sed -i -e 's/^#AuthorizedKeysFile/AuthorizedKeysFile/; s/^#\ AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
    IFS=" " read -r -a SSHD_CONFIG_PATH <<< "$(awk '/AuthorizedKeysFile/{$1="";print $0}' /etc/ssh/sshd_config)"
    MARK=0
    for i in "${SSHD_CONFIG_PATH[@]}"; do
        if [ "${i}" = ".ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-authorized_keys" ];then
            MARK=1
            break
        fi
    done
    if [ "${MARK}" -eq 0 ]; then
        _warning "sshd 配置文件缺少有关免密参数，正在修改"
        i=$(sed 's/\//\\\//g' <<< ".ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-authorized_keys")
        sed -i "/AuthorizedKeysFile/s/$/\ ${i}/g" /etc/ssh/sshd_config
        systemctl restart sshd
    fi
    _success "本机公密钥配置已完成"
    if [ "${#VALIDATION_SUCCESS_LIST[@]}" -gt 0 ]; then
        _info "开始向指定免密组工作正常的节点更新新增节点信息"
        for i in "${VALIDATION_SUCCESS_LIST[@]}";do
            if [ "${i}" != "${LOCAL_ALIAS}" ]; then
                _successnoblank "正在更新 ${i} 节点中保存的节点信息"
                scp -r /root/.ssh/"${DEPLOY_GROUP_NAME}"/* "${i}":/root/.ssh/"${DEPLOY_GROUP_NAME}"
                ssh "${i}" "chmod -R 644 /root/.ssh/${DEPLOY_GROUP_NAME};chmod 600 /root/.ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-key"
            fi
        done
    fi
    GenerateDeployScript
    Tips
}

GenerateDeployScript(){
    CONFIG_FILE=$(cat /root/.ssh/"${DEPLOY_GROUP_NAME}"/config-"${DEPLOY_GROUP_NAME}"-*)
    AUTHORIZED_KEYS=$(cat /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-authorized_keys)
    PRIVATE_KEY=$(cat /root/.ssh/"${DEPLOY_GROUP_NAME}"/"${DEPLOY_GROUP_NAME}"-key)

    _info "开始生成指定免密节点组中的服务器使用的自动部署脚本"
    _successnoblank "存放位置: /root/${GEN_SH_NAME}.sh"
    cat > /root/"${GEN_SH_NAME}".sh <<EOF
#!/bin/bash
# 作者: 欧阳剑宇
# 功能: 为后续所有脚本提供基于作者自定义规则的自检流程提供稳定免密环境的部署功能
# 日期: 2022-07-23

# 全局颜色
if ! which tput >/dev/null 2>&1;then
    _norm="\033[39m"
    _red="\033[31m"
    _green="\033[32m"
    _tan="\033[33m"     
    _cyan="\033[36m"
else
    _norm=\$(tput sgr0)
    _red=\$(tput setaf 1)
    _green=\$(tput setaf 2)
    _tan=\$(tput setaf 3)
    _cyan=\$(tput setaf 6)
fi

_print() {
	printf "\${_norm}%s\${_norm}\n" "\$@"
}
_info() {
	printf "\${_cyan}➜ %s\${_norm}\n" "\$@"
}
_success() {
	printf "\${_green}✓ %s\${_norm}\n" "\$@"
}
_warning() {
	printf "\${_tan}⚠ %s\${_norm}\n" "\$@"
}
_error() {
	printf "\${_red}✗ %s\${_norm}\n" "\$@"
}

_checkroot() {
	if [ \$EUID != 0 ] || [[ \$(grep "^\$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

# OVERRIDE=0
# DELETE=0

# if ! ARGS=\$(getopt -a -o o,d -l override,delete -- "\$@")
# then
#     _error "脚本中没有此选项"
#     exit 1
# elif [ -z "\$1" ]; then
#     _error "没有设置选项"
#     exit 1
# elif [ "\$1" == "-" ]; then
#     _error "选项写法出现错误"
#     exit 1
# fi
# eval set -- "\${ARGS}"
# while true; do
#     case "\$1" in
#     -o | --override)
#         OVERRIDE=1
#         ;;
#     -d | --delete)
#         DELETE=1
#         ;;
#     --)
#         shift
#         break
#         ;;
#     esac
#     shift
# done

# [ "\${DELETE}" -eq 1 ] && rm -rf /root/.ssh && exit 0

_info "开始检测此子脚本是否存在于可用的 IP 列表中"
COUNT=0
LOCAL_NIC_NAME=\$(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print \$NF}')
for i in \${LOCAL_NIC_NAME};do
    COUNT=\$(( COUNT + 1 ))
    _print "本机网卡名: \$i"
done
if [ "\${COUNT}" -lt 1 ]; then
    _error "未检测到网卡，请联系脚本作者进行适配"
    exit 1
elif [ "\${COUNT}" -gt 1 ]; then
    _error "检测到多个网卡，请联系脚本作者进行适配"
    exit 1
else
    IP_RESULT1=\$(ip -f inet address show "\${LOCAL_NIC_NAME}" | grep -Po 'inet \K[\d.]+')
    IP_RESULT2=\$(ifconfig "\${LOCAL_NIC_NAME}" | grep -Po 'inet \K[\d.]+')
    if [ "\${IP_RESULT1}" = "\${IP_RESULT2}" ]; then
        LOCAL_IP=\${IP_RESULT1}
        _success "本地 IP 地址已确定"
        _print "IP 地址: \${LOCAL_IP}"
    else
        _error "检测到多个 IP，请联系脚本作者适配"
        exit 1
    fi
fi

CONFIG_FILE="$CONFIG_FILE"
AUTHORIZED_KEYS="$AUTHORIZED_KEYS"
PRIVATE_KEY="$PRIVATE_KEY"
# 测试用途
# echo "\$CONFIG_FILE"
# echo "\$AUTHORIZED_KEYS"
# echo "\$PRIVATE_KEY"
# echo ""

if [ ! "\$(grep "\${LOCAL_IP}" <<< "\${CONFIG_FILE}" | awk '{print \$2}')" = "\${LOCAL_IP}" ]; then
    _error "此服务器不在自动装配列表中，退出中"
    exit 1
else
    _success "此服务器在自动装配列表中"
fi

_info "开始部署免密环境"
if [ ! -d /root/.ssh ]; then
    mkdir -p /root/.ssh
fi
chmod 700 /root/.ssh

if [ ! -d /root/.ssh/${DEPLOY_GROUP_NAME} ]; then
    mkdir -p /root/.ssh/${DEPLOY_GROUP_NAME}
fi

# 调整 config 文件
_info "正在添加免密节点组至免密组配置列表"
if [ ! -f /root/.ssh/config ]; then
    echo "Include ${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-*" > /root/.ssh/config
else
    if ! grep "${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-\*" /root/.ssh/config >/dev/null 2>&1; then
        sed -i "1s/^/Include ${DEPLOY_GROUP_NAME}\/config-${DEPLOY_GROUP_NAME}-*\n/" /root/.ssh/config
    fi
fi
ln -f /root/.ssh/config /root/.ssh/${DEPLOY_GROUP_NAME}/.backup_config

# 生成公密钥文件
_info "正在部署公密钥"
if [ -n "\$AUTHORIZED_KEYS" ] && [ -n "\$PRIVATE_KEY" ]; then
    echo "\$AUTHORIZED_KEYS" > /root/.ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-authorized_keys
    echo "\$PRIVATE_KEY" > /root/.ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-key
fi

# 生成每个节点的配置文件（拆分、补全、重命名、删除临时文件）
_info "正在生成免密节点配置"
echo "\$CONFIG_FILE" | awk 'BEGIN{i++} !NF{++i;next} {print > ("/root/.ssh/${DEPLOY_GROUP_NAME}/ToConvertFile-"i)}'
mapfile -t toConvertFile < <(find /root/.ssh/${DEPLOY_GROUP_NAME} -maxdepth 1 -type f -name "ToConvertFile-*"|awk -F '/' '{print \$NF}')
for i in "\${toConvertFile[@]}";do
    echo "" >> /root/.ssh/${DEPLOY_GROUP_NAME}/"\$i"
    RENAME_INFO=\$(awk '/Host /{print \$2}' /root/.ssh/${DEPLOY_GROUP_NAME}/"\$i")
    if [ ! -f /root/.ssh/${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-"\${RENAME_INFO}" ]; then
        mv /root/.ssh/${DEPLOY_GROUP_NAME}/"\$i" /root/.ssh/${DEPLOY_GROUP_NAME}/config-${DEPLOY_GROUP_NAME}-"\${RENAME_INFO}"
    fi
done
rm -rf /root/.ssh/${DEPLOY_GROUP_NAME}/ToConvertFile-*

_info "正在设置权限"
chmod 700 /root/.ssh
[ -f /root/.ssh/known_hosts ] && chmod 644 /root/.ssh/known_hosts
chmod -R 644 /root/.ssh/config /root/.ssh/${DEPLOY_GROUP_NAME}
chmod 600 /root/.ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-key

# 向 /etc/ssh/sshd_config 添加公钥文件路径
_info "正在添加公钥文件路径"
[[ "\$(grep "AuthorizedKeysFile" /etc/ssh/sshd_config)" =~ "#" ]] && sed -i -e 's/^#AuthorizedKeysFile/AuthorizedKeysFile/; s/^#\ AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
IFS=" " read -r -a SSHD_CONFIG_PATH <<< "\$(awk '/AuthorizedKeysFile/{\$1="";print \$0}' /etc/ssh/sshd_config)"
MARK=0
for i in "\${SSHD_CONFIG_PATH[@]}"; do
    if [ "\${i}" = ".ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-authorized_keys" ];then
        MARK=1
        break
    fi
done
if [ "\${MARK}" -eq 0 ]; then
    _warning "sshd 配置文件缺少有关免密参数，正在修改"
    i=\$(sed 's/\//\\\\\//g' <<< ".ssh/${DEPLOY_GROUP_NAME}/${DEPLOY_GROUP_NAME}-authorized_keys")
    sed -i "/AuthorizedKeysFile/s/\$/\ \${i}/g" /etc/ssh/sshd_config
fi
systemctl restart sshd
_success "免密环境部署成功"
EOF
}

Tips(){
    _success "此服务器已完成部署，已自动生成子自动部署脚本"
    _success "生成的子脚本会检测所在设备 IP 是否在安装列表中，故在非安装列表 IP 中的服务器上会自动中断运行"
    if [ "${GROUP_EXIST}" -eq 0 ]; then
        _success "请将生成的子脚本放置在以下 IP 的服务器上并执行部署:"
        mapfile -t PRE_ADD_LIST < <(awk '/HostName/{print $2}' <<< cat /root/.ssh/"${DEPLOY_GROUP_NAME}"/config-"${DEPLOY_GROUP_NAME}"-*)
        for i in "${PRE_ADD_LIST[@]}"; do
            if [ "${i}" != "${LOCAL_IP}" ]; then
                echo "${i}"
            fi
        done
        echo ""
    elif [ "${GROUP_EXIST}" -eq 1 ]; then
        if [ "${#VALIDATION_FAILURE_LIST[@]}" -gt 0 ]; then
            _warning "检测到部分节点存在免密故障，请在以下这些故障节点中重新运行新生成的子自动部署脚本:"
            for i in "${VALIDATION_FAILURE_LIST[@]}"; do
                echo "${i}"
            done
        fi
        if [ "${#VALIDATION_SUCCESS_LIST[@]}" -gt 1 ]; then
            _success "已向组内检测通过的免密节点 IP 同步更新新增节点，生成的子自动部署脚本不用在以下节点中重复安装:"
            for i in "${VALIDATION_SUCCESS_LIST[@]}"; do
                if [ "${i}" != "${LOCAL_ALIAS}" ]; then
                    echo "${i}"
                fi
            done
        fi
        _success "请将生成的子脚本放置在以下新增的节点中执行部署:"
        for i in "${IP_ADDRESS[@]}"; do
            echo "${i}"
        done
    fi
    _infonoblank "部署命令: "
    _infonoblank "当 authorized_keys 文件不存在或其中存在其他项目写入的免密公钥则实现清理残留文件和配置信息后再完成新信息的配置: "
    _print "bash <(cat ${GEN_SH_NAME}.sh)"
    _infonoblank "待以上 IP 列表中的所有服务器均部署完毕后，子脚本将保持可用状态直到父脚本执行增减节点或节点组。"
}

# RemoveNodeCheck(){
#     # 参数传入规范检查
#     if [[ ! "${REMOVE_GROUP_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
#         _error "需移除的节点所属组名写法有错，只支持大小写字母、数字、下划线(_)和连字符(-)，请检查"
#         exit 1
#     fi
#     if [[ ! "${REMOVE_NODE_ALIAS}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
#         _error "需移除的节点名写法有错，只支持大小写字母、数字、下划线(_)和连字符(-)，请检查"
#         exit 1
#     fi
# }

# RemoveGroupCheck(){
#     # 参数传入规范检查
#     if [[ ! "${REMOVE_GROUP_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
#         _error "需完整移除的免密节点组名写法有错，只支持大小写字母、数字、下划线(_)和连字符(-)，请检查"
#         exit 1
#     fi
# }

Help(){
    _successnoblank "
    所有内置选项及传参格式如下，有参选项必须加具体参数，否则脚本会自动检测并阻断运行:"| column -t

    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    
    echo "
    -G | --deploy_group_name 设置免密节点组名称
    -N | --deploy_node_info 设置组内每个节点的信息(每个节点信息填写顺序为：节点别名,登录名,IP,端口号，不同节点信息用空格隔开)
    -t | --type 设置生成密钥的类型(可选类型:dsa/ecdsa/ed25519/rsa/rsa1)" | column -t

    # echo "
    # -G | --deploy_group_name 设置免密节点组名称
    # -g | --remove_group_name 设置需要完整卸载的免密节点组名称
    # -N | --deploy_node_info 设置组内每个节点的信息
    # -n | --remove_node_alias 设置指定免密节点组中的一个或多个节点别名
    # -t | --type 设置生成密钥的类型" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -s | --check_dep_sep 只检测并打印脚本运行必备依赖情况的详细信息并退出
    -y | --yes 确认执行所有检测结果后的实际操作
    -h | --help 打印此帮助信息并退出" | column -t
    echo ""
    _errornoblank "执行任意一种功能均需设置确认执行的无参选项: -y 或 --yes"
    _errornoblank "否则脚本只进行检测但不会实际运行"
    _warningnoblank "所有组合方式中，任何选项均没有次序要求"

    echo "----------------------------------------------------------------"
    _warningnoblank "以下为根据脚本内置可重复功能归类各自必要选项(存在选项复用情况)"
    echo ""
    _successnoblank "|--------------------------------|"
    _successnoblank "|新增一个免密节点组和多个节点信息|"
    _successnoblank "|--------------------------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t

    echo ""
    echo "
    -G | --deploy_group_name 设置免密节点组名称
    -N | --deploy_node_info 设置组内每个节点的信息(每个节点信息填写顺序为：节点别名,登录名,IP,端口号，不同节点信息用空格隔开)
    -t | --type 设置生成密钥的类型(可选类型:dsa/ecdsa/ed25519/rsa/rsa1)"|column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successnoblank "|--------------------------------------|"
    _successnoblank "|向已有免密节点组追加一个或多个节点信息|"
    _successnoblank "|--------------------------------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t

    echo ""
    echo "
    -G | --deploy_group_name 设置免密节点组名称
    -N | --deploy_node_info 设置组内每个节点的信息(每个节点信息填写顺序为：节点别名,登录名,IP,端口号，不同节点信息用空格隔开)"|column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    # _successnoblank "|----------------------------------------|"
    # _successnoblank "|卸载指定免密节点组中的一个或多个节点信息|"
    # _successnoblank "|----------------------------------------|"
    # _warningnoblank "
    # 以下为有参选项，必须带上相应参数"| column -t

    # echo ""
    # echo "
    # -g | --remove_group_name 设置需要卸载的节点所在免密节点组名称
    # -n | --remove_node_alias 设置指定免密节点组中需要卸载的一个或多个节点别名"|column -t

    # _warningnoblank "
    # 以下为无参选项:"| column -t
    # echo "
    # -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    # echo ""

    # _successnoblank "|----------------------------------|"
    # _successnoblank "|卸载指定免密节点组及其所有节点信息|"
    # _successnoblank "|----------------------------------|"
    # _warningnoblank "
    # 以下为有参选项，必须带上相应参数"| column -t

    # echo ""
    # echo "
    # -g | --remove_group_name 设置需要完整卸载的免密节点组名称"|column -t

    # _warningnoblank "
    # 以下为无参选项:"| column -t
    # echo "
    # -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    # echo ""
}

[ "${HELP}" -eq 1 ] && Help && exit 0
EnvCheck
CheckOption
