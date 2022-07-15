#!/bin/bash
# 作者: Ou Yang Jian Yu
# 日期: 2022-07-07
# 默认设置只对于按照特定格式筛选出来的文件夹进行传输，有需求自己修改下文件夹名的形式：xxxFULL_年_月_日_xxx 或 xxxINCREMENT_年_月_日_xxx

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
_warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
_error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}

_checkroot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

# 变量名
SH_NAME="multi-sync-backup"
EXEC_LOGFILE=/var/log/${SH_NAME}/exec-"$(date +"%Y-%m-%d")".log

SYNC_SOURCE_PATH=
SYNC_DEST_PATH=
BACKUP_SOURCE_PATH=
BACKUP_DEST_PATH=

SYNC_SOURCE_ALIAS=
SYNC_DEST_ALIAS=
BACKUP_SOURCE_ALIAS=
BACKUP_DEST_ALIAS=

TIMEOUT=
OPEARTION_CRON=
LOG_CRON=
SYNC_MARK_INFO=
BACKUP_MARK_INFO=
TIP_INFO=

CHECK_DEP_SEP=0
DEPLOY=0
REMOVE=0
RMLOG=0
CONFIRM_CONTINUE=0
HELP=0
FILES_NAME=

if ! ARGS=$(getopt -a -o t:,o:,l:,M:,m:,T:,C,L,R,r,y,h -l sync_source_path:,sync_dest_path:,backup_source_path:,backup_dest_path:,sync_source_alias:,sync_dest_alias:,backup_source_alias:,backup_dest_alias:,timeout:,operation_cron:,log_cron:,sync_mark:,backup_mark:,tips:,check_dep_sep,deploy,remove,rmlog,yes,help -- "$@")
then
    _error "脚本中没有此选项"
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
    --sync_source_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            SYNC_SOURCE_PATH="$2"
        fi
        shift
        ;;
    --sync_dest_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 2
        else
            SYNC_DEST_PATH="$2"
        fi
        shift
        ;;
    --backup_source_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            BACKUP_SOURCE_PATH="$2"
        fi
        shift
        ;;
    --backup_dest_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 2
        else
            BACKUP_DEST_PATH="$2"
        fi
        shift
        ;;

    # 始末端同步和备份节点别名
    --sync_source_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            SYNC_SOURCE_ALIAS="$2"
        fi
        shift
        ;;
    --sync_dest_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            SYNC_DEST_ALIAS="$2"
        fi
        shift
        ;;
    --backup_source_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            BACKUP_SOURCE_ALIAS="$2"
        fi
        shift
        ;;
    --backup_dest_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            BACKUP_DEST_ALIAS="$2"
        fi
        shift
        ;;

    # 同步或备份方案的节点组名    
    -M | --sync_mark)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            SYNC_MARK_INFO="$2"
        fi
        shift
        ;;
    -m | --backup_mark)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_MARK_INFO="$2"
        fi
        shift
        ;;

    # 其他选项
    -t | --timeout)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            TIMEOUT="$2"
        fi
        shift
        ;;
    -o | --operation_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            OPEARTION_CRON="$2"
        fi
        shift
        ;;
    -l | --log_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            LOG_CRON="$2"
        fi
        shift
        ;;
    -T | --tips)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            TIP_INFO="$2"
        fi
        shift
        ;;
    -C | --check_dep_sep)
        CHECK_DEP_SEP=1
        ;;
    -L | --deploy)
        DEPLOY=1
        ;;
    -R | --remove)
        REMOVE=1
        ;;
    -r | --rmlog)
        RMLOG=1
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
    appList="timeout tput scp pwd basename sort tail tee md5sum ip ifconfig shuf column sha1sum dirname stat"
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
    # 此环节用于检测是否有人为修改免密节点组信息的情况，并且在存在这种情况的前提下尝试自动修复，/root/.ssh/config 文件中应该包含各种免密组的文件夹名，所以默认脚本均检测此文件内容
    # 为防止此文件被误删，在每个创建的免密组文件夹中均有一个创建该组时对 config 硬链接的文件，名字是 .backup_config
    
    # 自检流程：
    # 1. 如果 /root/.ssh/config 不存在，则遍历 /root/.ssh 下的所有文件夹，查找里面的 .backup_config，如果都不存在则表示环境被毁或没有用专用脚本做免密部署，直接报错退出，如果存在，则取找到的列表中的第一个直接做个硬链接成 /root/.ssh/config
    if [ ! -f /root/.ssh/config ]; then
        _warning "自动部署的业务节点免密组配置文件被人为删除，正在尝试恢复"
        mapfile -t BACKUP_CONFIG < <(find /root/.ssh -type f -name ".backup_config")
        if [ "${#BACKUP_CONFIG[@]}" -eq 0 ]; then
            _error "所有 ssh 业务节点免密组的配置文件均未找到，如果此服务器未使用本脚本作者所写免密部署脚本部署，请先使用免密部署工具进行预部署后再执行此脚本"
            _error "如果曾经预部署过，请立即人工恢复，否则所有此脚本作者所写的自动化脚本将全体失效"
            exit 1
        elif [ "${#BACKUP_CONFIG[@]}" -ne 0 ]; then
            ln "${BACKUP_CONFIG[0]}" /root/.ssh/config
            _success "业务节点免密组默认配置文件恢复"
        fi
    fi

    # 2. 如果 /root/.ssh/config 存在，则遍历 /root/.ssh/config 中保存的节点组名的配置对比 /root/.ssh 下的所有文件夹名，查找里面的 .backup_config，在 /root/.ssh/config 中存在但对应文件夹中不存在 .backup_config 则做个硬链接到对应文件夹，
    # 如果文件夹被删，则删除 config 中的配置并报错退出
    mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    for i in "${GROUP_NAME_IN_FILE[@]}"; do
        if [ ! -f /root/.ssh/"${i}"/.backup_config ]; then
            if [ ! -d /root/.ssh/"${i}" ]; then
                _error "业务节点免密组被人为删除，已从配置文件中删除此节点组引用，请重新运行免密部署脚本以添加需要的组"
                sed -i "/\ ${i}/d" /root/.ssh/config
                exit 1
            else
                _warning "${i} 业务节点免密组的备份配置被人为删除，正在恢复"
                ln /root/.ssh/config /root/.ssh/"${i}"/.backup_config
                _success "${i} 业务节点免密组默认配置文件恢复"
            fi
        fi
    done

    # 3. 遍历 /root/.ssh 中的所有子文件夹中的 .backup_config 文件，然后对比查看对应文件夹名在 config 文件中是否有相关信息（上一步的 GROUP_NAME_IN_FILE 数组），没有的话添加上
    # 如果出现 config 文件与免密组文件夹名对不上的情况，可以清空 config 文件中的内容，通过文件夹的方式重新生成
    mapfile -t DIR_GROUP_NAME < <(find /root/.ssh -type f -name ".backup_config"|awk -F '/' '{print $(NF-1)}')
    mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    for i in "${DIR_GROUP_NAME[@]}"; do
        MARK=0
        for j in "${GROUP_NAME_IN_FILE[@]}"; do
            if [ "$i" = "${j}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            if [ -f /root/.ssh/"${i}"/"${i}"-authorized_keys ] && [ -f /root/.ssh/"${i}"/"${i}"-key ] && [ -n "$(find /root/.ssh/"${i}" -type f -name "config-${i}-*")" ];then
                if [ "$(find /root/.ssh/"${i}" -name "*-authorized_keys"|wc -l)" -eq 1 ];then
                    _warning "默认配置文件中存在未添加的节点组信息，正在添加"
                    if [ -n "$(cat /root/.ssh/config)" ]; then
                        sed -i "1s/^/Include ${i}\/config-${i}-*\n/" /root/.ssh/config
                    else
                        echo -e "Include ${i}/config-${i}-*" >> /root/.ssh/config
                    fi
                else
                    _error "发现多个公钥，请自行检查哪个可用"
                    _error "这里不想适配了，哪能手贱成这样啊？？？自动部署的地方非要手动不按规矩改？？？"
                    exit 1
                fi
            else
                _warning "/root/.ssh/${i} 文件夹可能不是通过免密部署脚本实现的，将移除其中的 .backup_config 文件防止未来反复报错，其余文件请自行检查"
                rm -rf /root/.ssh/"${i}"/.backup_config
            fi
        fi
    done
    # 4. 将 .ssh 为开头的路径的数组对比 /etc/ssh/sshd_config，如果 ssh 配置文件不存在则添加上并重启 ssh
    [[ "$(grep "AuthorizedKeysFile" /etc/ssh/sshd_config)" =~ "#" ]] && sed -i 's/^#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
    mapfile -t DIR_AUTHORIZED_KEYS_PATH < <(find /root/.ssh -type f -name "*-authorized_keys"|sed 's/\/root\///g')
    IFS=" " read -r -a SSHD_CONFIG_PATH <<< "$(grep "AuthorizedKeysFile" /etc/ssh/sshd_config|awk '$1=""; {print $0}')"
    IF_NEED_RESTART_SSHD=0
    for i in "${DIR_AUTHORIZED_KEYS_PATH[@]}"; do
        MARK=0
        for j in "${SSHD_CONFIG_PATH[@]}"; do
            if [ "${i}" = "${j}" ];then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            IF_NEED_RESTART_SSHD=1
            _warning "sshd 配置文件缺少有关免密参数，正在修改"
            i=$(echo "$i"|sed 's/\//\\\//g')
            sed -i "/AuthorizedKeysFile/s/$/\ ${i}/g" /etc/ssh/sshd_config
        fi
    done
    [ "${IF_NEED_RESTART_SSHD}" -eq 1 ] && systemctl restart sshd
    _success "环境自检完成"
}

CheckOption(){
    # 只执行完就直接退出
    [ "${HELP}" -eq 1 ] && Help && exit 0
    [ "${REMOVE}" -eq 1 ] && Remove && exit 0
    [ "${RMLOG}" -eq 1 ] && RMLog && exit 0

    _info "开始检查传递的选项和参数"
    if [ "${DEPLOY}" -eq 1 ]; then
        [ -z "${OPEARTION_CRON}" ] && _error "未设置操作定时规则，请检查" && exit 116
        [ -z "${LOG_CRON}" ] && _error "未设置删除过期日志定时规则，请检查" && exit 116
    fi
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${SYNC_MARK_INFO}" ] && [ -n "${BACKUP_MARK_INFO}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ]; then
        :
    elif [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${SYNC_MARK_INFO}" ] && [ -z "${BACKUP_SOURCE_PATH}" ] && [ -z "${BACKUP_DEST_PATH}" ] && [ -z "${BACKUP_SOURCE_ALIAS}" ] && [ -z "${BACKUP_DEST_ALIAS}" ] && [ -z "${BACKUP_MARK_INFO}" ]; then
        :
    elif [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ] && [ -n "${BACKUP_MARK_INFO}" ] && [ -z "${SYNC_SOURCE_PATH}" ] && [ -z "${SYNC_DEST_PATH}" ] && [ -z "${SYNC_SOURCE_ALIAS}" ] && [ -z "${SYNC_DEST_ALIAS}" ] && [ -z "${SYNC_MARK_INFO}" ]; then
        :
    else
        _error "用户层面只有三种输入选项参数的组合方式，同步、备份、同步后备份，请仔细对比帮助信息并检查缺失的选项和参数"
        _warning "启用同步功能所需的五个有参选项:"
        _error "--sync_source_path"
        _error "--sync_dest_path"
        _error "--sync_source_alias"
        _error "--sync_dest_alias"
        _error "--sync_mark"
        echo ""
        _warning "启用备份功能所需的五个有参选项:"
        _error "--backup_source_path"
        _error "--backup_dest_path"
        _error "--backup_source_alias"
        _error "--backup_dest_alias"
        _error "--backup_mark"
        echo ""
        _warning "启用同步后备份的功能需要以上所有有参选项共十个，三种组合方式中，任何选项均没有次序要求"
        exit 1
    fi

    mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    # 同步节点组名非空时，检查其他所有同步选项
    if [ -n "${SYNC_MARK_INFO}" ]; then
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${SYNC_MARK_INFO}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的同步免密节点组名称"
            _error "可用节点组如下:"
            for i in "${GROUP_NAME_IN_FILE[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        [[ ! "${SYNC_SOURCE_PATH}" =~ ^/ ]] && _error "设置的源同步节点路径必须为绝对路径，请检查" && exit 112
        [[ ! "${SYNC_DEST_PATH}" =~ ^/ ]] && _error "设置的目标同步节点路径必须为绝对路径，请检查" && exit 112

        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${SYNC_MARK_INFO}"/config-"${SYNC_MARK_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${SYNC_SOURCE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源同步节点别名错误，请检查可用的源同步节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${SYNC_DEST_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "目标同步节点别名错误，请检查可用的目标同步节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
    fi

    # 备份节点组名非空时，检查其他所有备份选项
    if [ -n "${BACKUP_MARK_INFO}" ]; then
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${BACKUP_MARK_INFO}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的免密节点组名称"
            _error "可用节点组如下:"
            for i in "${GROUP_NAME_IN_FILE[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        [[ ! "${BACKUP_SOURCE_PATH}" =~ ^/ ]] && _error "设置的源备份节点路径必须为绝对路径，请检查" && exit 112
        [[ ! "${BACKUP_DEST_PATH}" =~ ^/ ]] && _error "设置的目标备份节点路径必须为绝对路径，请检查" && exit 112
        
        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${BACKUP_MARK_INFO}"/config-"${BACKUP_MARK_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${BACKUP_SOURCE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源备份节点别名错误，请检查可用的源备份节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${BACKUP_DEST_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "目标备份节点别名错误，请检查可用的目标备份节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
    fi

    [ -z "${TIMEOUT}" ] && _error "未设置超时时间，请检查" && exit 116
    _success "所有参数选项指定正确"
}

CheckTransmissionStatus(){
    _info "测试节点连通性"
    MARK=0
    if [ -n "${SYNC_SOURCE_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${SYNC_SOURCE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            echo "源同步节点连接正常"
        else
            _error "源同步节点无法连接，请检查源同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${SYNC_DEST_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${SYNC_DEST_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            echo "目标同步节点连接正常"
        else
            _error "目标同步节点无法连接，请检查目标同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${BACKUP_SOURCE_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${BACKUP_SOURCE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            echo "源备份节点连接正常"
        else
            _error "源备份节点无法连接，请检查源备份节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${BACKUP_DEST_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${BACKUP_DEST_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            echo "目标备份节点连接正常"
        else
            _error "目标备份节点无法连接，请检查目标备份节点硬件是否损坏"
            MARK=1
        fi
    fi

    [ "${MARK}" -eq 1 ] && _error "节点连通性存在问题，请先检查节点硬件是否损坏" && exit 1
    _success "节点连通性检测通过"

    _info "开始同步/备份节点路径检查和处理"
    # 备份一下，忘了为什么之前会用这个写法，当时应该是能正常工作的，但现在无法工作： sed -e "s/'/'\\\\''/g"
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ]; then
        SYNC_SOURCE_PATH=$(echo "${SYNC_SOURCE_PATH}" | sed -e "s/\/$//g")
        if ssh "${SYNC_SOURCE_ALIAS}" "[ -d \"${SYNC_SOURCE_PATH}\" ]"; then
            _info "修正后的源同步节点路径: ${SYNC_SOURCE_PATH}"
        else
            _error "源同步节点路径不存在，请检查: ${SYNC_SOURCE_ALIAS}"
            exit 1
        fi
        SYNC_DEST_PATH=$(echo "${SYNC_DEST_PATH}" | sed -e "s/\/$//g")
        ssh "${SYNC_DEST_ALIAS}" "[ ! -d \"${SYNC_DEST_PATH}\" ] && echo \"目标同步节点路径不存在，将创建路径: ${SYNC_DEST_PATH}\" && mkdir -p \"${SYNC_DEST_PATH}\""
        _info "修正后的目标同步节点路径: ${SYNC_DEST_PATH}"
    fi
    if [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ]; then
        BACKUP_SOURCE_PATH=$(echo "${BACKUP_SOURCE_PATH}" | sed -e "s/\/$//g")
        if ssh "${BACKUP_SOURCE_ALIAS}" "[ -d \"${BACKUP_SOURCE_PATH}\" ]"; then
            _info "修正后的源备份节点路径: ${BACKUP_SOURCE_PATH}"
        else
            _error "源备份节点路径不存在，请检查，退出中"
            exit 1
        fi
        BACKUP_DEST_PATH=$(echo "${BACKUP_DEST_PATH}" | sed -e "s/\/$//g")
        ssh "${BACKUP_DEST_ALIAS}" "[ ! -d \"${BACKUP_DEST_PATH}\" ] && echo \"目标备份节点路径不存在，将创建路径: ${BACKUP_DEST_PATH}\" && mkdir -p \"${BACKUP_DEST_PATH}\""
        _info "修正后的目标备份节点路径: ${BACKUP_DEST_PATH}"
    fi
    _success "节点路径检查和处理完毕"
}

OperationSelect(){
    SearchCondition
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ]; then
        dd
    fi

    if [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ]; then
        dd
    fi
}

SearchCondition(){
    _info "正在设置语言环境..."
    export LANG=en_US.UTF-8
    
    if [ -n "${SYNC_SOURCE_PATH}" ]; then
        ssh "${SYNC_SOURCE_ALIAS}" "find \"${SYNC_SOURCE_PATH}\" -type d"
    elif [ -n "${BACKUP_SOURCE_PATH}" ]; then
        dd
    fi
}

LocateFile(){

    _info "正在搜索昨日生成的备份文件名"
    YESTERDAY_DATE=$(date -d yesterday +%Y-%m-%d)
    FILES_NAME=$(find "${SOURCE_PATH}" -maxdepth 1 -type f -name "${YESTERDAY_DATE}*" | sed 's#.*/##' s/.*\///| xargs)
    for i in ${FILES_NAME}; do
        echo "已发现文件: $i"
    done
    if [ -z "${FILES_NAME}" ]; then
        _error "当前路径没有任何一种类型的备份文件，可能源路径设置错误？"
        _error "请手动查看问题来源，退出中"
        exit 1
    fi
    
    if [ -z "${FILES_NAME}" ]; then
        _error "当日没有生成任何一种类型的备份文件夹或日志文件，请手动查看问题来源，退出中"
        exit 1
    fi
    _success "昨日需备份的文件名称已确定"
}

LocateFile(){
    _info "正在设置语言环境..."
    export LANG=en_US.UTF-8

    _info "正在搜索最新备份的名称"
    FULL_DIR_NAME=$(find "${SOURCE_PATH}" -maxdepth 1 -type d -name "*FULL*" | sed 's#.*/##' | sort -uV | tail -1)
    echo "变量 FULL_DIR_NAME=${FULL_DIR_NAME}"
    if [ -z "${FULL_DIR_NAME}" ]; then
        _warning "全量备份文件夹未找到"
    fi

    INCREMENT_DIR_NAME=$(find "${SOURCE_PATH}" -maxdepth 1 -type d -name "*INCREMENT*" | sed 's#.*/##' | sort -uV | tail -1)
    echo "变量 INCREMENT_DIR_NAME=${INCREMENT_DIR_NAME}"
    if [ -z "${INCREMENT_DIR_NAME}" ]; then
        _warning "增量备份文件夹未找到"
    fi

    RELATIME_LOG_NAME=$(ls -Ggt --time-style=+%Y-%m-%d_%T "${SOURCE_PATH}"/ARCHIVE_LOCAL* | awk '{print $5}' | head -1 | sed 's#.*/##')
    echo "变量 RELATIME_LOG_NAME=${RELATIME_LOG_NAME}"
    if [ -z "${RELATIME_LOG_NAME}" ]; then
        _warning "数据库日志文件未找到"
    fi
    
    if [ -z "${FULL_DIR_NAME}" ] && [ -z "${INCREMENT_DIR_NAME}" ] && [ -z "${RELATIME_LOG_NAME}" ]; then
        _error "当前路径没有任何一种类型的备份文件夹或日志文件，可能源路径设置错误？"
        _error "请手动查看问题来源，退出中"
        exit 1
    fi

    _info "名称搜索完成，开始校验时效性"
    if [[ "${FULL_DIR_NAME}" =~ $(date +"%Y_%m_%d") ]]; then
        _success "本地最新版本全量备份文件夹对应日期与当日时间一致！"
    else
        FULL_DIR_NAME=
        _warning "本地最新版本全量备份文件夹对应日期与当日时间不同！终止该备份工作！"
    fi

    if [[ "${INCREMENT_DIR_NAME}" =~ $(date +"%Y_%m_%d") ]]; then
        _success "本地最新版本增量备份文件夹对应日期与当日时间一致！"
    else
        INCREMENT_DIR_NAME=
        _warning "本地最新版本增量备份文件夹对应日期与当日时间不同！终止该备份工作！"
    fi
    
    if [ -z "${FULL_DIR_NAME}" ] && [ -z "${INCREMENT_DIR_NAME}" ] && [ -z "${RELATIME_LOG_NAME}" ]; then
        _error "当日没有生成任何一种类型的备份文件夹或日志文件，请手动查看问题来源，退出中"
        exit 1
    fi
    _success "需备份的数据库备份文件夹和日志文件名称已确定"
}

SyncOperation(){
    dd
}

BackupOperation(){
    dd
}

RecoverSyncOperation(){
    gg
}

BackupOperation(){
    LogInfo
    _info "开始传输..."
    if [ -n "${FILES_NAME}" ]; then
        _info "开始传输前日备份文件"
        for i in ${FILES_NAME}; do
            if ! timeout "${TIMEOUT}" scp "${SOURCE_PATH}"/"$i" "${USER}"@"${ADDRESS}":"${DEST_PATH}" 2>&1; then
                _error "${SOURCE_PATH}/$i 连接断开，请手动检查未完成的残留文件"
            fi
        done
    fi
}

RecoverBackupOperation(){
    gg
}

SendAlarm(){
    gg
}

LogInfo(){
    [ ! -d /var/log/${SH_NAME} ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}
    cat >> /var/log/${SH_NAME}/exec-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%Y-%m-%d %H:%M:%S")
执行情况：
EOF
}

RMLog(){
    _info "开始清理陈旧日志文件"
    logfile=$(find /var/log/${SH_NAME}/ -name "exec*.log" -mtime +10)
    for a in $logfile
    do
        rm -f "${a}"
    done
    _success "日志清理完成"
}

Deploy(){
    _info "开始部署..."
    cp -af "$(pwd)"/"${SH_NAME}".sh /${SH_NAME}
    chmod +x /${SH_NAME}
    mkdir -p /var/log/${SH_NAME}
    sed -i "/${SH_NAME}/d" /etc/crontab
    echo "${BACKUP_CRON} root /usr/bin/bash -c 'bash <(cat /${SH_NAME}) -P ${SOURCE_PATH} -p ${DEST_PATH} -u ${USER} -d ${ADDRESS} -t ${TIMEOUT}'" >> /etc/crontab
    echo "${LOG_CRON} root /usr/bin/bash -c 'bash <(cat /${SH_NAME}) -r'" >> /etc/crontab
    _success "部署成功"
}

Remove(){
    _info "开始清空同步工具本身和生成的日志，不会对备份文件产生任何影响"
    rm -rf /${SH_NAME}.sh /var/log/${SH_NAME}
    sed -i "/${SH_NAME}/d" /etc/crontab
    _success "清理成功"
}

Help(){
    echo "
    本脚本依赖 SCP 传输
    所有内置选项及传参格式如下，有参选项必须加具体参数，否则脚本会自动检测并阻断运行：
    -P | --source_path <本地发送方的绝对路径>           有参选项，脚本会从此路径下查找符合条件的搜索结果，
                                                        找不到的话会停止工作防止通过 SCP 往远程节点乱拉屎

    -p | --dest_path <远程节点接收方的绝对路径>         有参选项，脚本会检查远程节点是否存在此目录，没有的话会自动创建，
                                                        如果用户错误输入非绝对路径，会根据目的节点默认登录路径自动修复为绝对路径

    -u | --user <远程节点的登录用户名>           有参选项，脚本无法检测是否正确，但如果填写错误的话，
                                                        在已经配置了密钥公钥的两台服务器之间使用 scp 会提示要输入密码

    -d | --address <远程节点的 IP 地址>         有参选项，脚本无法检测是否正确，但如果填写错误的话，
                                                        脚本会根据超时时长到时间自动退出防止死在当前不可继续的任务上

    -t | --timeout <SCP 传输超时时长>                   有参选项，用于限制 scp 单次传输时长，防止接收内容的远程节点硬件损坏
                                                        导致 scp 死在当前不可继续的任务上使得后续所有备份任务被阻塞，
                                                        参数举例：
                                                        15s  15秒
                                                        15m  15分钟
                                                        15h  15小时
                                                        15d  15天
    -L | --deploy                                       不可独立无参选项，目的是一键部署，但必须与所有有参选项同时搭配才能完成部署
    -B | --backup_cron                                  有参选项，方便测试和生产环境定时备份的一键设置，不设置此选项则默认生产环境参数
    -l | --log_cron                                     有参选项，方便测试和生产环境定时删日志的一键设置，不设置此选项则默认生产环境参数
    -r | --rmlog <删除脚本产生的超时陈旧日志>           可独立无参选项，指定后会立即清理超过预定时间的陈旧日志
    -R | --remove                                       可独立无参选项，目的是一键移除脚本对系统所做的所有修改。
    -h | --help                                         打印此帮助信息并退出

    部署和立即同步只有一个 -L 区别，其他完全相同，部署的时候不会进行同步。

    使用示例：
    1.1 测试部署(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP + 节点中备份的目标路径 + 超时阈值)
    bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s -B \"*/2 * * * *\" -l \"* * */10 * *\" -L

    1.2 生产部署(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP + 节点中备份的目标路径 + 超时阈值)
    bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s -B \"30 23 * * *\" -l \"* * */10 * *\" -L

    2. 立即同步(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP + 节点中备份的目标路径 + 超时阈值)
    bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s

    3. 删除陈旧日志(默认10天)
    bash <(cat ${SH_NAME}.sh) -r

    4. 卸载
    bash <(cat ${SH_NAME}.sh) -R
"
}

Main(){
    EnvCheck
    CheckOption
    CheckTransmissionStatus
    LocateFile
    [ "${DEPLOY}" -eq 1 ] && Deploy && exit 0
    if [ "${CONFIRM_CONTINUE}" -eq 1 ]; then
        CloneOperation
    fi
}

EnvCheck
CheckOption
CheckTransmissionStatus
# [ ! -d /var/log/${SH_NAME} ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}
# Main | tee "${EXEC_LOGFILE}"
