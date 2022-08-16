#!/bin/bash
# 作者: 欧阳剑宇
# 功能: 为多机同步和备份数据方案提供安装卸载基本控制功能
# 修改日期: 2022-07-22

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

_checkroot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

# 变量名
# SH_NAME 值必须和脚本名完全相同，脚本名修改的话必须改这里
SH_NAME="multi-sync-backup"
EXEC_COMMON_LOGFILE=/var/log/${SH_NAME}/log/exec-"$(date +"%Y-%m-%d")".log
EXEC_ERROR_WARNING_SYNC_LOGFILE=/var/log/${SH_NAME}/log/exec-error-warning-sync-"$(date +"%Y-%m-%d")".log
EXEC_ERROR_WARNING_BACKUP_LOGFILE=/var/log/${SH_NAME}/log/exec-error-warning-backup-"$(date +"%Y-%m-%d")".log

SYNC_SOURCE_PATH=
SYNC_DEST_PATH=
BACKUP_SOURCE_PATH=
BACKUP_DEST_PATH=

SYNC_SOURCE_ALIAS=
SYNC_DEST_ALIAS=
BACKUP_SOURCE_ALIAS=
BACKUP_DEST_ALIAS=

SYNC_GROUP_INFO=
BACKUP_GROUP_INFO=
SYNC_TYPE=
BACKUP_TYPE=
SYNC_DATE_TYPE=
BACKUP_DATE_TYPE=
SYNC_OPERATION_NAME=
BACKUP_OPERATION_NAME=

OPERATION_CRON=
OPERATION_CRON_NAME=
LOG_CRON=

REMOVE_NODE_ALIAS=
REMOVE_GROUP_INFO=
REMOVE_OPERATION_FILE=
DEPLOY_NODE_ALIAS=
DEPLOY_GROUP_INFO=

ALLOW_DAYS=

CHECK_DEP_SEP=0
DELETE_EXPIRED_LOG=0
NEED_CLEAN=0
CONFIRM_CONTINUE=0
HELP=0

if ! ARGS=$(getopt -a -o G:,g:,T:,t:,D:,d:,N:,n:,O:,o:,L:,l:,R:,r:,F:,s,E:,e,c,y,h -l sync_source_path:,sync_dest_path:,backup_source_path:,backup_dest_path:,sync_source_alias:,sync_dest_alias:,backup_source_alias:,backup_dest_alias:,sync_group:,backup_group:,sync_type:,backup_type:,sync_operation_name:,backup_operation_name:,sync_date_type:,backup_date_type:,operation_cron:,operation_cron_name:,log_cron:,remove:,remove_group_info:,remove_operation_file:,deploy:,deploy_group_info:,days:,check_dep_sep,deploy,delete_expired_log,clean,yes,help -- "$@")
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
    -G | --sync_group)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            SYNC_GROUP_INFO="$2"
        fi
        shift
        ;;
    -g | --backup_group)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_GROUP_INFO="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定内容类型（纯文件或纯文件夹）
    -T | --sync_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            SYNC_TYPE="$2"
        fi
        shift
        ;;
    -t | --backup_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_TYPE="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定日期格式
    -D | --sync_date_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            SYNC_DATE_TYPE="$2"
        fi
        shift
        ;;
    -d | --backup_date_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_DATE_TYPE="$2"
        fi
        shift
        ;;

    # 指定同步或备份方案各自的名称
    -N | --sync_operation_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            SYNC_OPERATION_NAME="$2"
        fi
        shift
        ;;
    -n | --backup_operation_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_OPERATION_NAME="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定定时方案
    -O | --operation_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            OPERATION_CRON="$2"
        fi
        shift
        ;;
    -o | --operation_cron_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            OPERATION_CRON_NAME="$2"
        fi
        shift
        ;;
    -E | --log_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            LOG_CRON="$2"
        fi
        shift
        ;;

    # 安装卸载相关选项
    -R | --remove)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            REMOVE_NODE_ALIAS="$2"
        fi
        shift
        ;;
    -r | --remove_group_info)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            REMOVE_GROUP_INFO="$2"
        fi
        shift
        ;;
    -F | --remove_operation_file)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            REMOVE_OPERATION_FILE="$2"
        fi
        shift
        ;;
    -L | --deploy)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            DEPLOY_NODE_ALIAS="$2"
        fi
        shift
        ;;
    -l | --deploy_group_info)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            DEPLOY_GROUP_INFO="$2"
        fi
        shift
        ;;

    # 允许搜索的最长历史天数
    --days)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            ALLOW_DAYS="$2"
        fi
        shift
        ;;
    
    # 其他选项
    -s | --check_dep_sep)
        CHECK_DEP_SEP=1
        ;;
    -e | --delete_expired_log)
        DELETE_EXPIRED_LOG=1
        ;;
    -c | --clean)
        NEED_CLEAN=1
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
    mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '/Include/{print $2}' /root/.ssh/config)
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

CheckExecOption(){
    _info "开始检查传递的执行选项和参数"
    ################################################################
    # 仅运行同步备份或先同步再备份的所有选项
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${SYNC_GROUP_INFO}" ] && [ -n "${SYNC_TYPE}" ] && [ -n "${SYNC_DATE_TYPE}" ] && [ -z "${BACKUP_SOURCE_PATH}" ] && [ -z "${BACKUP_DEST_PATH}" ] && [ -z "${BACKUP_SOURCE_ALIAS}" ] && [ -z "${BACKUP_DEST_ALIAS}" ] && [ -z "${BACKUP_GROUP_INFO}" ] && [ -z "${BACKUP_TYPE}" ] && [ -z "${BACKUP_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ] && [ -n "${SYNC_OPERATION_NAME}" ] && [ -z "${BACKUP_OPERATION_NAME}" ]; then
        :
    elif [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ] && [ -n "${BACKUP_GROUP_INFO}" ] && [ -n "${BACKUP_TYPE}" ] && [ -n "${BACKUP_DATE_TYPE}" ] && [ -z "${SYNC_SOURCE_PATH}" ] && [ -z "${SYNC_DEST_PATH}" ] && [ -z "${SYNC_SOURCE_ALIAS}" ] && [ -z "${SYNC_DEST_ALIAS}" ] && [ -z "${SYNC_GROUP_INFO}" ] && [ -z "${SYNC_TYPE}" ] && [ -z "${SYNC_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ] && [ -z "${SYNC_OPERATION_NAME}" ] && [ -n "${BACKUP_OPERATION_NAME}" ]; then
        :
    elif [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${SYNC_GROUP_INFO}" ] && [ -n "${SYNC_TYPE}" ] && [ -n "${SYNC_DATE_TYPE}" ] && [ -z "${BACKUP_SOURCE_PATH}" ] && [ -z "${BACKUP_DEST_PATH}" ] && [ -z "${BACKUP_SOURCE_ALIAS}" ] && [ -z "${BACKUP_DEST_ALIAS}" ] && [ -z "${BACKUP_GROUP_INFO}" ] && [ -z "${BACKUP_TYPE}" ] && [ -z "${BACKUP_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        :
    elif [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ] && [ -n "${BACKUP_GROUP_INFO}" ] && [ -n "${BACKUP_TYPE}" ] && [ -n "${BACKUP_DATE_TYPE}" ] && [ -z "${SYNC_SOURCE_PATH}" ] && [ -z "${SYNC_DEST_PATH}" ] && [ -z "${SYNC_SOURCE_ALIAS}" ] && [ -z "${SYNC_DEST_ALIAS}" ] && [ -z "${SYNC_GROUP_INFO}" ] && [ -z "${SYNC_TYPE}" ] && [ -z "${SYNC_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        :
    else
        _error "用户层面只有两种输入选项参数的组合方式，同步或备份，先同步后备份则是执行两次，请仔细对比帮助信息并检查缺失或多输入的选项和参数"
        _warning "运行同步功能所需的八个有参选项(两个通用选项见下):"
        _errornoblank "
        --sync_source_path 设置源同步路径
        --sync_dest_path 设置目的同步路径
        --sync_source_alias 设置源同步节点别名
        --sync_dest_alias 设置目的同步节点别名"|column -t
        _errornoblank "
        -G | --sync_group 同步需指定的免密节点组名
        -T | --sync_type 同步的内容类型(文件或文件夹:file或dir)
        -D | --sync_date_type 指定同步时包含的日期格式"|column -t
        echo ""
        _warning "运行备份功能所需的八个有参选项(两个通用选项见下):"
        _errornoblank "
        --backup_source_path 设置源备份路径
        --backup_dest_path 设置目的备份路径
        --backup_source_alias 设置源备份节点别名
        --backup_dest_alias 设置目的备份节点别名"|column -t
        _errornoblank "
        -g | --backup_group 备份需指定的免密节点组名
        -t | --backup_type 备份的内容类型(文件或文件夹:file或dir)
        -d | --backup_date_type 指定备份时包含的日期格式"|column -t
        echo ""
        _error "运行任意一种功能均需设置最长查找历史天数的有参选项: --days"
        _warning "两种组合方式中，任何选项均没有次序要求"
        exit 1
    fi

    mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    # 同步节点组名非空时，检查其他所有同步选项
    if [ -n "${SYNC_GROUP_INFO}" ]; then
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${SYNC_GROUP_INFO}" ]; then
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

        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${SYNC_GROUP_INFO}"/config-"${SYNC_GROUP_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
                MARK=0
            [ "${i}" = "${SYNC_SOURCE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源同步节点别名错误，请检查指定的免密节点组名中可用的源同步节点别名:"
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
            _error "目标同步节点别名错误，请检查指定的免密节点组名中可用的目标同步节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if [ ! "${SYNC_TYPE}" = "dir" ] && [ ! "${SYNC_TYPE}" = "file" ]; then
            _error "必须正确指定需要操作的内容类型参数: 按日期排序的文件或文件夹"
            _error "纯文件参数写法: dir"
            _error "纯文件夹参数写法: file"
            exit 1
        fi

        if [[ "${SYNC_DATE_TYPE}" =~ ^[0-9a-zA-Z]{4}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}+$ ]]; then
            SYNC_DATE_TYPE_CONVERTED="YYYY-MMMM-DDDD"
        elif [[ "${SYNC_DATE_TYPE}" =~ ^[0-9a-zA-Z]{4}_[0-9a-zA-Z]{2}_[0-9a-zA-Z]{2}+$ ]]; then
            SYNC_DATE_TYPE_CONVERTED="YYYY_MMMM_DDDD"
        else
            _error "同步日期格式不存在，格式举例: abcd-Mm-12 或 2000_0a_3F，年份四位，月和日均为两位字符"
            _error "格式支持大小写字母和数字随机组合，只检测连接符号特征，支持的格式暂时只有连字符和下划线两种"
            exit 1
        fi
    fi

    # 备份节点组名非空时，检查其他所有备份选项
    if [ -n "${BACKUP_GROUP_INFO}" ]; then
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${BACKUP_GROUP_INFO}" ]; then
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
        
        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${BACKUP_GROUP_INFO}"/config-"${BACKUP_GROUP_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${BACKUP_SOURCE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源备份节点别名错误，请检查指定的免密节点组名中可用的源备份节点别名:"
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
            _error "目标备份节点别名错误，请检查指定的免密节点组名中可用的目标备份节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        if [ ! "${BACKUP_TYPE}" = "dir" ] && [ ! "${BACKUP_TYPE}" = "file" ]; then
            _error "必须正确指定需要操作的内容类型参数: 按日期排序的文件或文件夹"
            _error "纯文件参数写法: dir"
            _error "纯文件夹参数写法: file"
            exit 1
        fi
        
        if [[ "${BACKUP_DATE_TYPE}" =~ ^[0-9a-zA-Z]{4}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}+$ ]]; then
            BACKUP_DATE_TYPE_CONVERTED="YYYY-MMMM-DDDD"
        elif [[ "${BACKUP_DATE_TYPE}" =~ ^[0-9a-zA-Z]{4}_[0-9a-zA-Z]{2}_[0-9a-zA-Z]{2}+$ ]]; then
            BACKUP_DATE_TYPE_CONVERTED="YYYY_MMMM_DDDD"
        else
            _error "同步日期格式不存在，格式举例: abcd-Mm-12 或 2000_0a_3F，年份四位字符，月和日均为两位字符"
            _error "格式支持大小写字母和数字随意组合，只检测连接符号特征，支持的格式暂时只有连字符和下划线两种"
            exit 1
        fi
    fi

    if [ -z "${ALLOW_DAYS}" ] || [[ ! "${ALLOW_DAYS}" =~ ^[0-9]+$ ]]; then
        _error "未设置允许搜索的最早日期距离今日的最大天数，请检查"
        _error "选项名为: --days  参数为非负整数"
        exit 116
    fi
    _success "所有执行参数选项指定正确"
}

CheckDeployOption(){
    # 检查部署选项
    if [ -n "${DEPLOY_NODE_ALIAS}" ]; then
        _info "开始检查传递的部署选项和参数"
        if [ -n "${SYNC_OPERATION_NAME}" ] && [ -n "${BACKUP_OPERATION_NAME}" ] && [ -n "${LOG_CRON}" ] && [ -n "${OPERATION_CRON}" ] && [ -n "${OPERATION_CRON_NAME}" ] && [ -n "${DEPLOY_GROUP_INFO}" ]; then
            :
        elif [ -n "${SYNC_OPERATION_NAME}" ] && [ -n "${LOG_CRON}" ] && [ -n "${OPERATION_CRON}" ] && [ -n "${OPERATION_CRON_NAME}" ] && [ -n "${DEPLOY_GROUP_INFO}" ]; then
            :
        elif [ -n "${BACKUP_OPERATION_NAME}" ] && [ -n "${LOG_CRON}" ] && [ -n "${OPERATION_CRON}" ] && [ -n "${OPERATION_CRON_NAME}" ] && [ -n "${DEPLOY_GROUP_INFO}" ]; then
            :
        else
            _error "部署时用户层面只有三种输入选项参数的组合方式，除了需要以上执行同步、备份、同步后备份的操作的所有选项外，还需指定部署节点、删除过期日志定时、操作别名和操作定时，请仔细对比帮助信息并检查缺失的选项和参数"
            _warning "部署同步功能所需的六个有参选项(五个通用选项见下):"
            _errornoblank "
            -N | --sync_operation_name 设置同步操作的别名"|column -t
            echo ""
            _warning "部署备份功能所需的六个有参选项(五个通用选项见下):"
            _errornoblank "
            -n | --backup_operation_name 设置备份操作的别名"|column -t
            echo ""
            _warning "运行任意一种功能均需设置的五种通用有参选项: "
            _errornoblank "
            -L | --deploy 设置部署节点别名
            -O | --operation_cron 设置方案组启动定时规则
            -o | --operation_cron_name 设置方案组名
            -l | --deploy_group_info 指定部署节点所在的免密节点组名
            -E | --log_cron 设置删除过期日志定时规则"|column -t
            _warning "启用同步后备份的功能需要以上所有有参选项共七个，三种组合方式中，任何选项均没有次序要求"
            exit 1
        fi

        mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${DEPLOY_GROUP_INFO}" ]; then
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
        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${DEPLOY_GROUP_INFO}"/config-"${DEPLOY_GROUP_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${DEPLOY_NODE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "部署节点别名错误，请检查指定的免密节点组名中可用的部署节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if ssh -o BatchMode=yes "${DEPLOY_NODE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "部署节点 ${DEPLOY_NODE_ALIAS} 连接正常"
        else
            _error "部署节点 ${DEPLOY_NODE_ALIAS} 无法连接，请检查源部署节点硬件是否损坏"
            MARK=1
        fi

        # 参数传入规范检查
        if [[ ! "${LOG_CRON}" =~ ^[0-9\*,/[:blank:]-]*$ ]]; then
            _error "清理过期日志定时写法有错，请检查"
            exit 1
        fi
        if [[ ! "${OPERATION_CRON}" =~ ^[0-9\*,/[:blank:]-]*$ ]]; then
            _error "集合操作定时写法有错，请检查"
            exit 1
        fi
        if [[ ! "${OPERATION_CRON_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
            _error "集合操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
            exit 1
        fi
        if [ -n "${SYNC_OPERATION_NAME}" ]; then
            if [[ ! "${SYNC_OPERATION_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "同步操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi
        if [ -n "${BACKUP_OPERATION_NAME}" ]; then
            if [[ ! "${BACKUP_OPERATION_NAME}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "备份操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi

        mapfile -t OPERATION_CRON_NAME_FILE < <(ssh "${DEPLOY_NODE_ALIAS}" "find /var/log/${SH_NAME}/exec -maxdepth 1 -type f -name "*run-*"|sed 's/run-//g'|awk -F '/' '{print \$NF}'")
        MARK=0
        for i in "${OPERATION_CRON_NAME_FILE[@]}"; do
            [ "$i" = "${OPERATION_CRON_NAME}" ] && MARK=1
        done

        MARK_SYNC_OPERATION_NAME=0
        MARK_BACKUP_OPERATION_NAME=0
        if [ "${MARK}" -eq 1 ]; then
            mapfile -t SYNC_OPERATION_NAME_LIST < <(ssh "${DEPLOY_NODE_ALIAS}" "grep -o \"\-\-sync_operation_name .* \" /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}|awk '{print \$2}'")
            mapfile -t BACKUP_OPERATION_NAME_LIST < <(ssh "${DEPLOY_NODE_ALIAS}" "grep -o \"\-\-backup_operation_name .* \" /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}|awk '{print \$2}'")
            SAME_SYNC_OPERATION_NAME_LIST=()
            SAME_BACKUP_OPERATION_NAME_LIST=()
            for i in "${SYNC_OPERATION_NAME_LIST[@]}"; do
                [ "$i" = "${SYNC_OPERATION_NAME}" ] && MARK_SYNC_OPERATION_NAME=1 && break
            done

            for i in "${BACKUP_OPERATION_NAME_LIST[@]}"; do
                [ "$i" = "${BACKUP_OPERATION_NAME}" ] && MARK_BACKUP_OPERATION_NAME=1 && break
            done
            
            mapfile -t -O "${#SAME_SYNC_OPERATION_NAME_LIST[@]}" SAME_SYNC_OPERATION_NAME_LIST < <(ssh "${DEPLOY_NODE_ALIAS}" "grep \"\-\-sync_operation_name ${SYNC_OPERATION_NAME}\" /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}")
            mapfile -t -O "${#SAME_BACKUP_OPERATION_NAME_LIST[@]}" SAME_BACKUP_OPERATION_NAME_LIST < <(ssh "${DEPLOY_NODE_ALIAS}" "grep \"\-\-backup_operation_name ${BACKUP_OPERATION_NAME}\" /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}")
            # 信息汇总
            _success "已收集所需信息，请检查以下汇总信息:"
            _success "部署节点 ${DEPLOY_NODE_ALIAS} 中存在方案组文件 /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}"
            if [ "${MARK_SYNC_OPERATION_NAME}" -eq 1 ]; then
                _warning "在以上方案组文件中发现同名同步执行功能，请自行辨认，如果功能重复或只是希望更新信息，则请手动删除无用的执行功能"
                _warning "如果确认部署的话将追加而非替换，以下是全部同名同步执行功能:"
                for i in "${SAME_SYNC_OPERATION_NAME_LIST[@]}"; do
                    echo "$i"
                done
                echo ""
            fi
            if [ "${MARK_BACKUP_OPERATION_NAME}" -eq 1 ]; then
                _warning "在以上方案组文件中发现同名备份执行功能，请自行辨认，如果功能重复或只是希望更新信息，则请手动删除无用的执行功能"
                _warning "如果确认部署的话将追加而非替换，以下是全部同名备份执行功能:"
                for i in "${SAME_BACKUP_OPERATION_NAME_LIST[@]}"; do
                    echo "$i"
                done
                echo ""
            fi
            _warning "将向部署节点 ${DEPLOY_NODE_ALIAS} 中创建的 ${OPERATION_CRON_NAME} 方案组加入以下执行功能:"
            if [ -n "${SYNC_OPERATION_NAME}" ]; then
                echo "bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"${ALLOW_DAYS}\" --sync_source_path \"${SYNC_SOURCE_PATH}\" --sync_dest_path \"${SYNC_DEST_PATH}\" --sync_source_alias \"${SYNC_SOURCE_ALIAS}\" --sync_dest_alias \"${SYNC_DEST_ALIAS}\" --sync_group \"${SYNC_GROUP_INFO}\" --sync_type \"${SYNC_TYPE}\" --sync_date_type \"${SYNC_DATE_TYPE}\" --sync_operation_name \"${SYNC_OPERATION_NAME}\" -y"
                echo ""
            fi
            if [ -n "${BACKUP_OPERATION_NAME}" ]; then
                echo "bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"${ALLOW_DAYS}\" --backup_source_path \"${BACKUP_SOURCE_PATH}\" --backup_dest_path \"${BACKUP_DEST_PATH}\" --backup_source_alias \"${BACKUP_SOURCE_ALIAS}\" --backup_dest_alias \"${BACKUP_DEST_ALIAS}\" --backup_group \"${BACKUP_GROUP_INFO}\" --backup_type \"${BACKUP_TYPE}\" --backup_date_type \"${BACKUP_DATE_TYPE}\" --backup_operation_name \"${BACKUP_OPERATION_NAME}\" -y"
                echo ""
            fi
        else
            # 信息汇总
            _success "已收集所需信息，请检查以下汇总信息:"
            _warning "部署节点 ${DEPLOY_NODE_ALIAS} 中未找到方案组 /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME}，即将创建该文件"
            _warning "将向部署节点 ${DEPLOY_NODE_ALIAS} 中创建的 ${OPERATION_CRON_NAME} 方案组加入以下执行功能:"
            if [ -n "${SYNC_OPERATION_NAME}" ]; then
                echo "bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"${ALLOW_DAYS}\" --sync_source_path \"${SYNC_SOURCE_PATH}\" --sync_dest_path \"${SYNC_DEST_PATH}\" --sync_source_alias \"${SYNC_SOURCE_ALIAS}\" --sync_dest_alias \"${SYNC_DEST_ALIAS}\" --sync_group \"${SYNC_GROUP_INFO}\" --sync_type \"${SYNC_TYPE}\" --sync_date_type \"${SYNC_DATE_TYPE}\" --sync_operation_name \"${SYNC_OPERATION_NAME}\" -y"
            fi
            if [ -n "${BACKUP_OPERATION_NAME}" ]; then
                echo "bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"${ALLOW_DAYS}\" --backup_source_path \"${BACKUP_SOURCE_PATH}\" --backup_dest_path \"${BACKUP_DEST_PATH}\" --backup_source_alias \"${BACKUP_SOURCE_ALIAS}\" --backup_dest_alias \"${BACKUP_DEST_ALIAS}\" --backup_group \"${BACKUP_GROUP_INFO}\" --backup_type \"${BACKUP_TYPE}\" --backup_date_type \"${BACKUP_DATE_TYPE}\" --backup_operation_name \"${BACKUP_OPERATION_NAME}\" -y"
            fi
        fi

        # 部署流程末尾，无论是否确认，各自功能都会运行完成后退出
        if [ "${CONFIRM_CONTINUE}" -eq 1 ]; then
            Deploy
            exit 0
        else
            _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行部署"
            exit 0
        fi
    else
        if [ -n "${OPERATION_CRON}" ] || [ -n "${OPERATION_CRON_NAME}" ] || [ -n "${LOG_CRON}" ] || [ -n "${DEPLOY_GROUP_INFO}" ]; then
            _warning "以下四个选项均为部署时的独占功能，如果只是运行备份或同步功能的话不要加上这些选项中的任意一个或多个"
            _errornoblank "
            -O | --operation_cron 设置方案组启动定时规则
            -o | --operation_cron_name 设置方案组名
            -l | --deploy_group_info 指定部署节点所在的免密节点组名
            -E | --log_cron 设置删除过期日志定时规则"|column -t
            _errornoblank "以上选项必须和指定部署脚本的节点别名选项同时被指定: -L | --deploy"
            exit 1
        fi
    fi
}

CheckRemoveOption(){
    if [ -n "${REMOVE_NODE_ALIAS}" ]; then
        _info "开始检查传递的卸载选项和参数"
        if [ -n "${REMOVE_GROUP_INFO}" ] && [ -n "${REMOVE_OPERATION_FILE}" ]; then
            :
        else
            _error "卸载时用户层面只有一种输入选项参数的组合方式，需同时指定:"
            _error "1. 需要卸载同步及备份脚本所在的节点"
            _error "2. 节点所在的免密节点组（操作远程卸载的节点必须和需要卸载的节点处于同一节点组）"
            _error "3. 卸载的具体的方案"
            _error "请仔细对比帮助信息并检查缺失的选项和参数"
            _warning "需设置的三种通用有参选项: "
            _errornoblank "
            -R | --remove 指定卸载脚本的节点别名
            -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
            -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t
            _warning "以上任何选项写在同一行均没有次序要求"
            exit 1
        fi

        mapfile -t GROUP_NAME_IN_FILE < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
        for i in "${GROUP_NAME_IN_FILE[@]}"; do
            MARK=0
            if [ "$i" = "${REMOVE_GROUP_INFO}" ]; then
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
        mapfile -t HOST_ALIAS < <(cat /root/.ssh/"${REMOVE_GROUP_INFO}"/config-"${REMOVE_GROUP_INFO}"-*|awk '/Host / {print $2}')
        for i in "${HOST_ALIAS[@]}"; do
            MARK=0
            [ "${i}" = "${REMOVE_NODE_ALIAS}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "部署节点别名错误，请检查指定的免密节点组名中可用的部署节点别名:"
            for i in "${HOST_ALIAS[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if ssh -o BatchMode=yes "${REMOVE_NODE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "卸载节点 ${REMOVE_NODE_ALIAS} 连接正常"
        else
            _error "卸载节点 ${REMOVE_NODE_ALIAS} 无法连接，请检查源部署节点硬件是否损坏"
            MARK=1
        fi

        if [ -n "${REMOVE_OPERATION_FILE}" ]; then
            if [[ ! "${REMOVE_OPERATION_FILE}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "需移除的方案组别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi
        
        IS_REMOVE_ALL=0
        mapfile -t OPERATION_NAME_FILE < <(ssh "${REMOVE_NODE_ALIAS}" "find /var/log/${SH_NAME}/exec -maxdepth 1 -type f -name "run-*"|awk -F '/' '{print \$NF}'"|sed 's/run-//g')
        if [ "${REMOVE_OPERATION_FILE}" = "all" ]; then
            IS_REMOVE_ALL=1
        else
            MARK=0
            for i in "${OPERATION_NAME_FILE[@]}"; do
                [ "$i" = "${REMOVE_OPERATION_FILE}" ] && MARK=1 && break
            done
            if [ "${#OPERATION_NAME_FILE[@]}" -gt 0 ]; then
                if [ "${MARK}" -eq 0 ]; then
                    _error "请输入正确的方案组名称"
                    _error "可选的方案组名称如下:"
                    for i in "${OPERATION_NAME_FILE[@]}"; do
                        echo "${i}"
                    done
                    exit 1
                fi
            fi
        fi

        # 信息汇总
        if [ "${IS_REMOVE_ALL}" -eq 1 ]; then
            if [ "${#OPERATION_NAME_FILE[@]}" -eq 0 ]; then
                _warning "指定节点中不存在任何同步或备份方案组，继续执行将检查并清理系统中其余残留信息"
            else
                _warning "即将卸载指定节点中所有的同步或备份方案组，以下为需卸载节点中保存的所有方案细节:"
                ssh "${REMOVE_NODE_ALIAS}" "sed '/\/bin\/bash/d' /var/log/${SH_NAME}/exec/run-*"
            fi
        else
            if [ "${#OPERATION_NAME_FILE[@]}" -eq 0 ]; then
                _error "指定节点中不存在任何同步或备份方案组，如果不是人为因素导致此问题，请在卸载时直接将选项 --remove_operation_file 或 -F 的参数设置成 all 以完成全部卸载，再重新部署"
                exit 1
            else
                _warning "即将卸载指定节点中名为 ${REMOVE_OPERATION_FILE} 的同步或备份方案组，以下为需卸载节点中该方案细节:"
                ssh "${REMOVE_NODE_ALIAS}" "sed '/\/bin\/bash/d' /var/log/${SH_NAME}/exec/run-${REMOVE_OPERATION_FILE}"
            fi
        fi

        if [ "${CONFIRM_CONTINUE}" -eq 1 ]; then
            Remove
            exit 0
        else
            _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行卸载"
            exit 0
        fi
    else
        if [ -n "${REMOVE_GROUP_INFO}" ] || [ -n "${REMOVE_OPERATION_FILE}" ]; then
            _warning "以下两个选项均为卸载时的独占功能，如果只是运行备份或同步功能的话不要加上这些选项中的任意一个或多个"
            _errornoblank "
            -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
            -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t
            exit 1
        fi
    fi
}

CheckTransmissionStatus(){
    _info "测试节点连通性"
    MARK=0
    if [ -n "${SYNC_SOURCE_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${SYNC_SOURCE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "源同步节点 ${SYNC_SOURCE_ALIAS} 连接正常"
        else
            _error "源同步节点 ${SYNC_SOURCE_ALIAS} 无法连接，请检查源同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${SYNC_DEST_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${SYNC_DEST_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "目标同步节点 ${SYNC_DEST_ALIAS} 连接正常"
        else
            _error "目标同步节点 ${SYNC_DEST_ALIAS} 无法连接，请检查目标同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${BACKUP_SOURCE_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${BACKUP_SOURCE_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "源备份节点 ${BACKUP_SOURCE_ALIAS} 连接正常"
        else
            _error "源备份节点 ${BACKUP_SOURCE_ALIAS} 无法连接，请检查源备份节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${BACKUP_DEST_ALIAS}" ]; then
        if ssh -o BatchMode=yes "${BACKUP_DEST_ALIAS}" "echo "">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "目标备份节点 ${BACKUP_DEST_ALIAS} 连接正常"
        else
            _error "目标备份节点 ${BACKUP_DEST_ALIAS} 无法连接，请检查目标备份节点硬件是否损坏"
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

SearchCondition(){
    export LANG=en_US.UTF-8
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${SYNC_GROUP_INFO}" ] && [ -n "${SYNC_TYPE}" ] && [ -n "${SYNC_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        if [ "${SYNC_TYPE}" = "dir" ]; then
            SyncLocateFolders
        elif [ "${SYNC_TYPE}" = "file" ]; then
            SyncLocateFiles
        fi
    fi
    
    if [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ] && [ -n "${BACKUP_GROUP_INFO}" ] && [ -n "${BACKUP_TYPE}" ] && [ -n "${BACKUP_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        if [ "${BACKUP_TYPE}" = "dir" ]; then
            BackupLocateFolders
        elif [ "${BACKUP_TYPE}" = "file" ]; then
            BackupLocateFiles
        fi
    fi

    if [ "${CONFIRM_CONTINUE}" -eq 1 ]; then
        OperationCondition
    else
        _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行工作"
        exit 0
    fi
}

OperationCondition(){
    if [ -n "${SYNC_SOURCE_PATH}" ] && [ -n "${SYNC_DEST_PATH}" ] && [ -n "${SYNC_SOURCE_ALIAS}" ] && [ -n "${SYNC_DEST_ALIAS}" ] && [ -n "${SYNC_GROUP_INFO}" ] && [ -n "${SYNC_TYPE}" ] && [ -n "${SYNC_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        SyncOperation
    fi
    
    if [ -n "${BACKUP_SOURCE_PATH}" ] && [ -n "${BACKUP_DEST_PATH}" ] && [ -n "${BACKUP_SOURCE_ALIAS}" ] && [ -n "${BACKUP_DEST_ALIAS}" ] && [ -n "${BACKUP_GROUP_INFO}" ] && [ -n "${BACKUP_TYPE}" ] && [ -n "${BACKUP_DATE_TYPE}" ] && [ -n "${ALLOW_DAYS}" ]; then
        BackupOperation
    fi
}

SyncLocateFolders(){
    MARK_SYNC_SOURCE_FIND_PATH=0
    MARK_SYNC_DEST_FIND_PATH=0
    JUMP=0
    days=0
    for((LOOP=0;LOOP<"${ALLOW_DAYS}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        YEAR_VALUE=$(date -d ${days}days +%Y)
        MONTH_VALUE=$(date -d ${days}days +%m)
        DAY_VALUE=$(date -d ${days}days +%d)
        SYNC_DATE=$(echo "${SYNC_DATE_TYPE_CONVERTED}"|sed -e "s/YYYY/${YEAR_VALUE}/g; s/MMMM/${MONTH_VALUE}/g; s/DDDD/${DAY_VALUE}/g")
        mapfile -t SYNC_SOURCE_FIND_FOLDER_NAME_1 < <(ssh "${SYNC_SOURCE_ALIAS}" "cd \"${SYNC_SOURCE_PATH}\";find . -maxdepth 1 -type d -name \"*${SYNC_DATE}*\"|grep -v \"\.$\"|sed 's/^\.\///g'")
        mapfile -t SYNC_DEST_FIND_FOLDER_NAME_1 < <(ssh "${SYNC_DEST_ALIAS}" "cd \"${SYNC_DEST_PATH}\";find . -maxdepth 1 -type d -name \"*${SYNC_DATE}*\"|grep -v \"\.$\"|sed 's/^\.\///g'")

        SYNC_SOURCE_FIND_PATH=()
        for i in "${SYNC_SOURCE_FIND_FOLDER_NAME_1[@]}"; do
            mapfile -t -O "${#SYNC_SOURCE_FIND_PATH[@]}" SYNC_SOURCE_FIND_PATH < <(ssh "${SYNC_SOURCE_ALIAS}" "cd \"${SYNC_SOURCE_PATH}\";find . -type d|grep \"\./$i\"|sed 's/^\.\///g'")
        done
        
        SYNC_DEST_FIND_PATH=()
        for i in "${SYNC_DEST_FIND_FOLDER_NAME_1[@]}"; do
            mapfile -t -O "${#SYNC_DEST_FIND_PATH[@]}" SYNC_DEST_FIND_PATH < <(ssh "${SYNC_DEST_ALIAS}" "cd \"${SYNC_DEST_PATH}\";find . -type d|grep \"\./$i\"|sed 's/^\.\///g'")
        done
        
        SYNC_SOURCE_FIND_FILE=()
        for i in "${SYNC_SOURCE_FIND_FOLDER_NAME_1[@]}"; do
            mapfile -t -O "${#SYNC_SOURCE_FIND_FILE[@]}" SYNC_SOURCE_FIND_FILE < <(ssh "${SYNC_SOURCE_ALIAS}" "cd \"${SYNC_SOURCE_PATH}\";find . -type f|grep \"\./$i\"|sed 's/^\.\///g'")
        done
        
        SYNC_DEST_FIND_FILE=()
        for i in "${SYNC_DEST_FIND_FOLDER_NAME_1[@]}"; do
            mapfile -t -O "${#SYNC_DEST_FIND_FILE[@]}" SYNC_DEST_FIND_FILE < <(ssh "${SYNC_DEST_ALIAS}" "cd \"${SYNC_DEST_PATH}\";find . -type f|grep \"\./$i\"|sed 's/^\.\///g'")
        done
        
        [ "${#SYNC_SOURCE_FIND_PATH[@]}" -gt 0 ] && MARK_SYNC_SOURCE_FIND_PATH=1 && JUMP=1
        [ "${#SYNC_DEST_FIND_PATH[@]}" -gt 0 ] && MARK_SYNC_DEST_FIND_PATH=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
        days=$(( days - 1 ))
    done
        
    if [ "${MARK_SYNC_SOURCE_FIND_PATH}" -eq 1 ] && [ "${MARK_SYNC_DEST_FIND_PATH}" -eq 0 ]; then
        _warning "目标同步节点${SYNC_DEST_ALIAS}不存在指定日期格式${SYNC_DATE}的文件夹"
        ErrorWarningSyncLog
        echo "目标同步节点${SYNC_DEST_ALIAS}不存在指定日期格式${SYNC_DATE}的文件夹" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    elif [ "${MARK_SYNC_SOURCE_FIND_PATH}" -eq 0 ] && [ "${MARK_SYNC_DEST_FIND_PATH}" -eq 1 ]; then
        _warning "源同步节点${SYNC_SOURCE_ALIAS}不存在指定日期格式${SYNC_DATE}的文件夹"
        ErrorWarningSyncLog
        echo "源同步节点${SYNC_SOURCE_ALIAS}不存在指定日期格式${SYNC_DATE}的文件夹" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    elif [ "${MARK_SYNC_SOURCE_FIND_PATH}" -eq 1 ] && [ "${MARK_SYNC_DEST_FIND_PATH}" -eq 1 ]; then
        _success "源与目标同步节点均找到指定日期格式${SYNC_DATE}的文件夹"
    elif [ "${MARK_SYNC_SOURCE_FIND_PATH}" -eq 0 ] && [ "${MARK_SYNC_DEST_FIND_PATH}" -eq 0 ]; then
        _error "源与目标同步节点均不存在指定日期格式${SYNC_DATE}的文件夹，退出中"
        ErrorWarningSyncLog
        echo "源与目标同步节点均不存在指定日期格式${SYNC_DATE}的文件夹，退出中" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
        exit 1
    fi

    # 锁定目的节点需创建的文件夹的相对路径并转换成绝对路径存进数组
    LOCATE_DEST_NEED_FOLDER=()
    for i in "${SYNC_SOURCE_FIND_PATH[@]}"; do
        MARK=0
        for j in "${SYNC_DEST_FIND_PATH[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#LOCATE_DEST_NEED_FOLDER[@]}" LOCATE_DEST_NEED_FOLDER < <(echo "\"${SYNC_DEST_PATH}/$i\"")
        fi
    done
    
    # 锁定源节点需创建的文件夹的相对路径并转换成绝对路径存进数组
    LOCATE_SOURCE_NEED_FOLDER=()
    for i in "${SYNC_DEST_FIND_PATH[@]}"; do
        MARK=0
        for j in "${SYNC_SOURCE_FIND_PATH[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#LOCATE_SOURCE_NEED_FOLDER[@]}" LOCATE_SOURCE_NEED_FOLDER < <(echo "\"${SYNC_SOURCE_PATH}/$i\"")
        fi
    done
    
    # 锁定始到末需传送的文件的绝对路径
    CONFILICT_FILE=()
    for i in "${SYNC_SOURCE_FIND_FILE[@]}"; do
        MARK=0
        for j in "${SYNC_DEST_FIND_FILE[@]}"; do
            if [ "$i" = "$j" ]; then
                if [[ ! $(ssh "${SYNC_SOURCE_ALIAS}" "sha256sum \"${SYNC_SOURCE_PATH}/$i\"|awk '{print \$1}'") = $(ssh "${SYNC_DEST_ALIAS}" "sha256sum \"${SYNC_DEST_PATH}/$j\"|awk '{print \$1}'") ]]; then
                    _warning "源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点:\"${SYNC_DEST_PATH}/$j\" 文件校验值不同，请检查日志，同步时将跳过此文件"
                    CONFILICT_FILE+=("源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点: \"${SYNC_DEST_PATH}/$j\"")
                else
                    _success "源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点: \"${SYNC_DEST_PATH}/$j\" 文件校验值一致"
                fi
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            LOCATE_SOURCE_OUTGOING_FILE+=("\"${SYNC_SOURCE_PATH}/$i\"")
            LOCATE_DEST_INCOMING_FILE+=("\"${SYNC_DEST_PATH}/$i\"")
        fi
    done
    
    # 将同名不同内容的冲突文件列表写入日志
    ErrorWarningSyncLog
    echo "始末节点中的同名文件存在冲突，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    for i in "${CONFILICT_FILE[@]}"; do
        echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    done

    # 锁定末到始需传送的文件的绝对路径
    for i in "${SYNC_DEST_FIND_FILE[@]}"; do
        MARK=0
        for j in "${SYNC_SOURCE_FIND_FILE[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            LOCATE_DEST_OUTGOING_FILE+=("\"${SYNC_DEST_PATH}/$i\"")
            LOCATE_SOURCE_INCOMING_FILE+=("\"${SYNC_SOURCE_PATH}/$i\"")
        fi
    done
    
    # 信息汇总
    _success "已锁定需传送信息，以下将显示各类已锁定信息，请检查"
    _warning "源节点 —— 待创建文件夹绝对路径列表:"
    for i in "${LOCATE_SOURCE_NEED_FOLDER[@]}"; do
        echo "$i"
    done
    echo ""
    _warning "目的节点 —— 待创建文件夹绝对路径列表:"
    for i in "${LOCATE_DEST_NEED_FOLDER[@]}"; do
        echo "$i"
    done
    echo ""
    _warning "传输方向: 源节点 -> 目的节点 —— 源节点待传出-目的节点待传入文件绝对路径列表:"
    for i in "${!LOCATE_SOURCE_OUTGOING_FILE[@]}"; do
        echo "${LOCATE_SOURCE_OUTGOING_FILE[$i]} -> ${LOCATE_DEST_INCOMING_FILE[$i]}"
    done
    echo ""
    _warning "传输方向: 目的节点 -> 源节点 —— 目的节点待传出-源节点待传入文件绝对路径列表:"
    for i in "${!LOCATE_DEST_OUTGOING_FILE[@]}"; do
        echo "${LOCATE_DEST_OUTGOING_FILE[$i]} -> ${LOCATE_SOURCE_INCOMING_FILE[$i]}"
    done
    echo ""
    _warning "基于指定路径的始末节点存在冲突的文件绝对路径列表:"
    for i in "${CONFILICT_FILE[@]}"; do
        echo "$i"
    done
    echo ""
}

SyncLocateFiles(){
    MARK_SYNC_SOURCE_FIND_FILE_1=0
    MARK_SYNC_DEST_FIND_FILE_1=0
    JUMP=0
    days=0
    for ((LOOP=0;LOOP<"${ALLOW_DAYS}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        YEAR_VALUE=$(date -d ${days}days +%Y)
        MONTH_VALUE=$(date -d ${days}days +%m)
        DAY_VALUE=$(date -d ${days}days +%d)
        SYNC_DATE=$(echo "${SYNC_DATE_TYPE_CONVERTED}"|sed -e "s/YYYY/${YEAR_VALUE}/g; s/MMMM/${MONTH_VALUE}/g; s/DDDD/${DAY_VALUE}/g")
        mapfile -t SYNC_SOURCE_FIND_FILE_1 < <(ssh "${SYNC_SOURCE_ALIAS}" "cd \"${SYNC_SOURCE_PATH}\";find . -maxdepth 1 -type f -name \"*${SYNC_DATE}*\"|sed 's/^\.\///g'") # 如果全路径而不cd的话会出现find到的全是带中文单引号的情况，原因不明
        mapfile -t SYNC_DEST_FIND_FILE_1 < <(ssh "${SYNC_DEST_ALIAS}" "cd \"${SYNC_DEST_PATH}\";find . -maxdepth 1 -type f -name \"*${SYNC_DATE}*\"|sed 's/^\.\///g'")

        
        [ "${#SYNC_SOURCE_FIND_FILE_1[@]}" -gt 0 ] && MARK_SYNC_SOURCE_FIND_FILE_1=1 && JUMP=1
        [ "${#SYNC_DEST_FIND_FILE_1[@]}" -gt 0 ] && MARK_SYNC_DEST_FIND_FILE_1=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
        days=$(( days - 1 ))
    done
        
    if [ "${MARK_SYNC_SOURCE_FIND_FILE_1}" -eq 1 ] && [ "${MARK_SYNC_DEST_FIND_FILE_1}" -eq 0 ]; then
        _warning "目标同步节点${SYNC_DEST_ALIAS}不存在指定日期格式${SYNC_DATE}的文件"
        ErrorWarningSyncLog
        echo "目标同步节点${SYNC_DEST_ALIAS}不存在指定日期格式${SYNC_DATE}的文件" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    elif [ "${MARK_SYNC_SOURCE_FIND_FILE_1}" -eq 0 ] && [ "${MARK_SYNC_DEST_FIND_FILE_1}" -eq 1 ]; then
        _warning "源同步节点${SYNC_SOURCE_ALIAS}不存在指定日期格式${SYNC_DATE}的文件"
        ErrorWarningSyncLog
        echo "源同步节点${SYNC_SOURCE_ALIAS}不存在指定日期格式${SYNC_DATE}的文件" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    elif [ "${MARK_SYNC_SOURCE_FIND_FILE_1}" -eq 1 ] && [ "${MARK_SYNC_DEST_FIND_FILE_1}" -eq 1 ]; then
        _success "源与目标同步节点均找到指定日期格式${SYNC_DATE}的文件"
    elif [ "${MARK_SYNC_SOURCE_FIND_FILE_1}" -eq 0 ] && [ "${MARK_SYNC_DEST_FIND_FILE_1}" -eq 0 ]; then
        _error "源与目标同步节点均不存在指定日期格式${SYNC_DATE}的文件，退出中"
        ErrorWarningSyncLog
        echo "源与目标同步节点均不存在指定日期格式${SYNC_DATE}的文件，退出中" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
        exit 1
    fi

    # 锁定始到末需传送的文件的绝对路径
    CONFILICT_FILE=()
    for i in "${SYNC_SOURCE_FIND_FILE_1[@]}"; do
        MARK=0
        for j in "${SYNC_DEST_FIND_FILE_1[@]}"; do
            if [ "$i" = "$j" ]; then
                if [[ ! $(ssh "${SYNC_SOURCE_ALIAS}" "sha256sum \"${SYNC_SOURCE_PATH}/$i\"|awk '{print \$1}'") = $(ssh "${SYNC_DEST_ALIAS}" "sha256sum \"${SYNC_DEST_PATH}/$j\"|awk '{print \$1}'") ]]; then
                    _warning "源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点:\"${SYNC_DEST_PATH}/$j\" 文件校验值不同，请检查日志，同步时将跳过此文件"
                    CONFILICT_FILE+=("源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点: \"${SYNC_DEST_PATH}/$j\"")
                else
                    _success "源节点: \"${SYNC_SOURCE_PATH}/$i\"，目的节点: \"${SYNC_DEST_PATH}/$j\" 文件校验值一致"
                fi
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            LOCATE_SOURCE_OUTGOING_FILE+=("\"${SYNC_SOURCE_PATH}/$i\"")
            LOCATE_DEST_INCOMING_FILE+=("\"${SYNC_DEST_PATH}/$i\"")
        fi
    done
    
    # 将同名不同内容的冲突文件列表写入日志
    ErrorWarningSyncLog
    echo "始末节点中的同名文件存在冲突，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    for i in "${CONFILICT_FILE[@]}"; do
        echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
    done

    # 锁定末到始需传送的文件的绝对路径
    for i in "${SYNC_DEST_FIND_FILE_1[@]}"; do
        MARK=0
        for j in "${SYNC_SOURCE_FIND_FILE_1[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            LOCATE_DEST_OUTGOING_FILE+=("\"${SYNC_DEST_PATH}/$i\"")
            LOCATE_SOURCE_INCOMING_FILE+=("\"${SYNC_SOURCE_PATH}/$i\"")
        fi
    done
    
    # 信息汇总
    _success "已锁定需传送信息，以下将显示各类已锁定信息，请检查"
    _warning "传输方向: 源节点 -> 目的节点 —— 源节点待传出-目的节点待传入文件绝对路径列表:"
    for i in "${!LOCATE_SOURCE_OUTGOING_FILE[@]}"; do
        echo "${LOCATE_SOURCE_OUTGOING_FILE[$i]} -> ${LOCATE_DEST_INCOMING_FILE[$i]}"
    done
    echo ""
    _warning "传输方向: 目的节点 -> 源节点 —— 目的节点待传出-源节点待传入文件绝对路径列表:"
    for i in "${!LOCATE_DEST_OUTGOING_FILE[@]}"; do
        echo "${LOCATE_DEST_OUTGOING_FILE[$i]} -> ${LOCATE_SOURCE_INCOMING_FILE[$i]}"
    done
    echo ""
    _warning "基于指定路径的始末节点存在冲突的文件绝对路径列表:"
    for i in "${CONFILICT_FILE[@]}"; do
        echo "$i"
    done
    echo ""
}

BackupLocateFolders(){
    MARK_BACKUP_SOURCE_FIND_FOLDER_FULL_PATH=0
    JUMP=0
    days=0
    for((LOOP=0;LOOP<"${ALLOW_DAYS}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        YEAR_VALUE=$(date -d ${days}days +%Y)
        MONTH_VALUE=$(date -d ${days}days +%m)
        DAY_VALUE=$(date -d ${days}days +%d)
        BACKUP_DATE=$(echo "${BACKUP_DATE_TYPE_CONVERTED}"|sed -e "s/YYYY/${YEAR_VALUE}/g; s/MMMM/${MONTH_VALUE}/g; s/DDDD/${DAY_VALUE}/g")
        mapfile -t BACKUP_SOURCE_FIND_FOLDER_FULL_PATH < <(ssh "${BACKUP_SOURCE_ALIAS}" "find \"${BACKUP_SOURCE_PATH}\" -maxdepth 1 -type d -name \"*${BACKUP_DATE}*\"|grep -v \"\.$\"")
        
        [ "${#BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[@]}" -gt 0 ] && MARK_BACKUP_SOURCE_FIND_FOLDER_FULL_PATH=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
        days=$(( days - 1 ))
    done

    if [ "${MARK_BACKUP_SOURCE_FIND_FOLDER_FULL_PATH}" -eq 1 ]; then
        _success "源备份节点存在指定日期格式${BACKUP_DATE}的文件夹"
    elif [ "${MARK_BACKUP_SOURCE_FIND_FOLDER_FULL_PATH}" -eq 0 ]; then
        _error "源备份节点不存在指定日期格式${BACKUP_DATE}的文件夹，退出中"
        ErrorWarningBackupLog
        echo "源备份节点不存在指定日期格式${BACKUP_DATE}的文件夹，退出中" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
        exit 1
    fi
    
    # 信息汇总
    _success "已锁定需传送信息，以下将显示已锁定信息，请检查"
    _warning "源节点待备份文件夹绝对路径列表:"
    for i in "${!BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[@]}"; do
        echo "${BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[$i]}"
    done
    echo ""
}

BackupLocateFiles(){
    MARK_BACKUP_SOURCE_FIND_FILE_1=0
    JUMP=0
    days=0
    for ((LOOP=0;LOOP<"${ALLOW_DAYS}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        YEAR_VALUE=$(date -d ${days}days +%Y)
        MONTH_VALUE=$(date -d ${days}days +%m)
        DAY_VALUE=$(date -d ${days}days +%d)
        BACKUP_DATE=$(echo "${BACKUP_DATE_TYPE_CONVERTED}"|sed -e "s/YYYY/${YEAR_VALUE}/g; s/MMMM/${MONTH_VALUE}/g; s/DDDD/${DAY_VALUE}/g")
        mapfile -t BACKUP_SOURCE_FIND_FILE_1 < <(ssh "${BACKUP_SOURCE_ALIAS}" "find \"${BACKUP_SOURCE_PATH}\" -maxdepth 1 -type f -name \"*${BACKUP_DATE}*\"")

        [ "${#BACKUP_SOURCE_FIND_FILE_1[@]}" -gt 0 ] && MARK_BACKUP_SOURCE_FIND_FILE_1=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
        days=$(( days - 1 ))
    done
        
    if [ "${MARK_BACKUP_SOURCE_FIND_FILE_1}" -eq 1 ]; then
        _success "源备份节点已找到指定日期格式${BACKUP_DATE}的文件"
    elif [ "${MARK_BACKUP_SOURCE_FIND_FILE_1}" -eq 0 ]; then
        _error "源节点不存在指定日期格式${BACKUP_DATE}的文件，退出中"
        ErrorWarningBackupLog
        echo "源与目标同步节点均不存在指定日期格式${BACKUP_DATE}的文件，退出中" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
        exit 1
    fi

    # 信息汇总
    _success "已锁定需传送信息，以下将显示已锁定信息，请检查"
    _warning "源节点待备份文件绝对路径列表:"
    for i in "${!BACKUP_SOURCE_FIND_FILE_1[@]}"; do
        echo "${BACKUP_SOURCE_FIND_FILE_1[$i]}"
    done
    echo ""
}

SyncOperation(){
    if [ "${SYNC_TYPE}" = "dir" ]; then
        # 源节点需创建的文件夹
        if [ "${#LOCATE_SOURCE_NEED_FOLDER[@]}" -gt 0 ]; then
            _info "开始创建源同步节点所需文件夹"
            # ssh "${SYNC_SOURCE_ALIAS}" "for i in \"${LOCATE_SOURCE_NEED_FOLDER[@]}\";do echo \"$i\";mkdir -p \"$i\";done"  # 这行可能会调用 CONFILICT_FILE 数组导致出错
            for i in "${LOCATE_SOURCE_NEED_FOLDER[@]}";do
                echo "正在创建文件夹: $i"
                ssh "${SYNC_SOURCE_ALIAS}" "mkdir -p \"$i\""
            done
            _info "源同步节点所需文件夹已创建成功"
        fi
        
        # 目的节点需创建的文件夹
        if [ "${#LOCATE_DEST_NEED_FOLDER[@]}" -gt 0 ]; then
            _info "开始创建目的同步节点所需文件夹"
            # ssh "${SYNC_DEST_ALIAS}" "for i in \"${LOCATE_DEST_NEED_FOLDER[@]}\";do echo \"$i\";mkdir -p \"$i\";done"
            for i in "${LOCATE_DEST_NEED_FOLDER[@]}";do
                echo "正在创建文件夹: $i"
                ssh "${SYNC_DEST_ALIAS}" "mkdir -p \"$i\""
            done
            _info "目的同步节点所需文件夹已创建成功"
        fi
        
        # 传输方向: 源节点 -> 目的节点 —— 源节点待传出文件
        if [ "${#LOCATE_SOURCE_OUTGOING_FILE[@]}" -gt 0 ]; then
            _info "源节点 -> 目的节点 开始传输"
            SOURCE_TO_DEST_FAILED=()
            for i in "${!LOCATE_SOURCE_OUTGOING_FILE[@]}"; do
                if ! scp -r "${SYNC_SOURCE_ALIAS}":"${LOCATE_SOURCE_OUTGOING_FILE[$i]}" "${SYNC_DEST_ALIAS}":"${LOCATE_DEST_INCOMING_FILE[$i]}"; then
                    SOURCE_TO_DEST_FAILED+=("${LOCATE_SOURCE_OUTGOING_FILE[$i]} -> ${LOCATE_DEST_INCOMING_FILE[$i]}")
                fi
            done
            if [ "${#SOURCE_TO_DEST_FAILED[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 源节点 -> 目的节点 存在部分文件同步失败，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                for i in "${SOURCE_TO_DEST_FAILED[@]}"; do
                    echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                done
            fi
        fi
        
        # 传输方向: 目的节点 -> 源节点 —— 目的节点待传出文件
        if [ "${#LOCATE_DEST_OUTGOING_FILE[@]}" -gt 0 ]; then
            _info "目的节点 -> 源节点 开始传输"
            DEST_TO_SOURCE_FAILED=()
            for i in "${!LOCATE_DEST_OUTGOING_FILE[@]}"; do
                if ! scp -r "${SYNC_DEST_ALIAS}":"${LOCATE_DEST_OUTGOING_FILE[$i]}" "${SYNC_SOURCE_ALIAS}":"${LOCATE_SOURCE_INCOMING_FILE[$i]}"; then
                    DEST_TO_SOURCE_FAILED+=("${LOCATE_DEST_OUTGOING_FILE[$i]} -> ${LOCATE_SOURCE_INCOMING_FILE[$i]}")
                fi
            done
            if [ "${#DEST_TO_SOURCE_FAILED[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 目的节点 -> 源节点 存在部分文件同步失败，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                for i in "${DEST_TO_SOURCE_FAILED[@]}"; do
                    echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                done
            fi
        fi
        
    elif [ "${SYNC_TYPE}" = "file" ]; then
        # 传输方向: 源节点 -> 目的节点 —— 源节点待传出文件
        if [ "${#LOCATE_SOURCE_OUTGOING_FILE[@]}" -gt 0 ]; then
            _info "源节点 -> 目的节点 开始传输"
            SOURCE_TO_DEST_FAILED=()
            for i in "${!LOCATE_SOURCE_OUTGOING_FILE[@]}"; do
                if ! scp -r "${SYNC_SOURCE_ALIAS}":"${LOCATE_SOURCE_OUTGOING_FILE[$i]}" "${SYNC_DEST_ALIAS}":"${LOCATE_DEST_INCOMING_FILE[$i]}"; then
                    SOURCE_TO_DEST_FAILED+=("${LOCATE_SOURCE_OUTGOING_FILE[$i]} -> ${LOCATE_DEST_INCOMING_FILE[$i]}")
                fi
            done
            if [ "${#SOURCE_TO_DEST_FAILED[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 源节点 -> 目的节点 存在部分文件同步失败，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                for i in "${SOURCE_TO_DEST_FAILED[@]}"; do
                    echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                done
            fi
        fi
        
        # 传输方向: 目的节点 -> 源节点 —— 目的节点待传出文件
        if [ "${#LOCATE_DEST_OUTGOING_FILE[@]}" -gt 0 ]; then
            _info "目的节点 -> 源节点 开始传输"
            DEST_TO_SOURCE_FAILED=()
            for i in "${!LOCATE_DEST_OUTGOING_FILE[@]}"; do
                if ! scp -r "${SYNC_DEST_ALIAS}":"${LOCATE_DEST_OUTGOING_FILE[$i]}" "${SYNC_SOURCE_ALIAS}":"${LOCATE_SOURCE_INCOMING_FILE[$i]}"; then
                    DEST_TO_SOURCE_FAILED+=("${LOCATE_DEST_OUTGOING_FILE[$i]} -> ${LOCATE_SOURCE_INCOMING_FILE[$i]}")
                fi
            done
            if [ "${#DEST_TO_SOURCE_FAILED[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 目的节点 -> 源节点 存在部分文件同步失败，请检查" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                for i in "${DEST_TO_SOURCE_FAILED[@]}"; do
                    echo "$i" >> "${EXEC_ERROR_WARNING_SYNC_LOGFILE}"
                done
            fi
        fi
    fi
}

BackupOperation(){
    if [ "${BACKUP_TYPE}" = "dir" ]; then
        _info "源节点文件夹备份开始"
        SOURCE_TO_DEST_FAILED=()
        for i in "${!BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[@]}"; do
            if ! scp -r "${BACKUP_SOURCE_ALIAS}":"${BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[$i]}" "${BACKUP_DEST_ALIAS}":"${BACKUP_DEST_PATH}"; then
                SOURCE_TO_DEST_FAILED+=("${BACKUP_SOURCE_FIND_FOLDER_FULL_PATH[$i]} -> ${BACKUP_DEST_PATH}")
            fi
        done
        if [ "${#SOURCE_TO_DEST_FAILED[@]}" -gt 0 ]; then
            _warning "部分文件夹传输失败，请查看报错日志"
            ErrorWarningBackupLog
            echo "源节点部分文件夹备份失败，请检查" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
            for i in "${SOURCE_TO_DEST_FAILED[@]}"; do
                echo "$i" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
            done
        fi
    elif [ "${BACKUP_TYPE}" = "file" ]; then
        _info "源节点文件备份开始"
        SOURCE_TO_DEST_FAILED=()
        for i in "${!BACKUP_SOURCE_FIND_FILE_1[@]}"; do
            if ! scp -r "${BACKUP_SOURCE_ALIAS}":"${BACKUP_SOURCE_FIND_FILE_1[$i]}" "${BACKUP_DEST_ALIAS}":"${BACKUP_DEST_PATH}"; then
                SOURCE_TO_DEST_FAILED+=("${BACKUP_SOURCE_FIND_FILE_1[$i]} -> ${BACKUP_DEST_PATH}")
            fi
        done
        if [ "${#SOURCE_TO_DEST_FAILED[@]}" -gt 0 ]; then
            _warning "部分文件传输失败，请查看报错日志"
            ErrorWarningBackupLog
            echo "源节点部分文件备份失败，请检查" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
            for i in "${SOURCE_TO_DEST_FAILED[@]}"; do
                echo "$i" >> "${EXEC_ERROR_WARNING_BACKUP_LOGFILE}"
            done
        fi
    fi
}

ErrorWarningSyncLog(){
    [ ! -d /var/log/${SH_NAME}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}/{exec,log}
    cat >> /var/log/${SH_NAME}/log/exec-error-warning-sync-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

ErrorWarningBackupLog(){
    [ ! -d /var/log/${SH_NAME}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}/{exec,log}
    cat >> /var/log/${SH_NAME}/log/exec-error-warning-backup-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

CommonLog(){
    [ ! -d /var/log/${SH_NAME}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}/{exec,log}
    cat >> /var/log/${SH_NAME}/log/exec-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

DeleteExpiredLog(){
    _info "开始清理陈旧日志文件"
    logfile=$(find /var/log/${SH_NAME}/log -name "exec*.log" -mtime +10)
    for a in $logfile
    do
        rm -f "${a}"
    done
    _success "日志清理完成"
}

Deploy(){
    _info "开始部署..."
    ssh "${DEPLOY_NODE_ALIAS}" "mkdir -p /var/log/${SH_NAME}/{exec,log}"
    scp "$(pwd)"/"${SH_NAME}".sh "${DEPLOY_NODE_ALIAS}":/var/log/${SH_NAME}/exec/${SH_NAME}
    ssh "${DEPLOY_NODE_ALIAS}" "chmod +x /var/log/${SH_NAME}/exec/${SH_NAME}"
    ssh "${DEPLOY_NODE_ALIAS}" "sed -i \"/${SH_NAME}/d\" /etc/bashrc"
    ssh "${DEPLOY_NODE_ALIAS}" "echo \"alias msb='/usr/bin/bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME})'\" >> /etc/bashrc"
    ssh "${DEPLOY_NODE_ALIAS}" "sed -i \"/${SH_NAME})\ -e/d\" /etc/crontab"
    ssh "${DEPLOY_NODE_ALIAS}" "echo \"${LOG_CRON} root /usr/bin/bash -c 'bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) -e'\" >> /etc/crontab"

    # 集合定时任务，里面将存放各种同步或备份的执行功能(if判断如果写在ssh命令会出现判断功能失效的毛病)
    ssh "${DEPLOY_NODE_ALIAS}" "[ ! -f /var/log/${SH_NAME}/exec/run-\"${OPERATION_CRON_NAME}\" ] && echo \"#!/bin/bash\" >/var/log/${SH_NAME}/exec/run-\"${OPERATION_CRON_NAME}\" && chmod +x /var/log/${SH_NAME}/exec/run-\"${OPERATION_CRON_NAME}\""
    if [ "$(ssh "${DEPLOY_NODE_ALIAS}" "grep -c \"${OPERATION_CRON_NAME}\" /etc/crontab")" -eq 0 ]; then
        ssh "${DEPLOY_NODE_ALIAS}" "echo \"${OPERATION_CRON} root /usr/bin/bash -c 'bash <(cat /var/log/${SH_NAME}/exec/run-${OPERATION_CRON_NAME})'\" >> /etc/crontab"
    fi
    # 向集合定时任务添加具体执行功能
    if [ -n "${SYNC_OPERATION_NAME}" ]; then
        ssh "${DEPLOY_NODE_ALIAS}" "echo \"bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"\"${ALLOW_DAYS}\"\" --sync_source_path \"\"${SYNC_SOURCE_PATH}\"\" --sync_dest_path \"\"${SYNC_DEST_PATH}\"\" --sync_source_alias \"\"${SYNC_SOURCE_ALIAS}\"\" --sync_dest_alias \"\"${SYNC_DEST_ALIAS}\"\" --sync_group \"\"${SYNC_GROUP_INFO}\"\" --sync_type \"\"${SYNC_TYPE}\"\" --sync_date_type \"\"${SYNC_DATE_TYPE}\"\" --sync_operation_name \"\"${SYNC_OPERATION_NAME}\"\" -y\" >> /var/log/${SH_NAME}/exec/run-\"${OPERATION_CRON_NAME}\""
    fi
    if [ -n "${BACKUP_OPERATION_NAME}" ]; then
        ssh "${DEPLOY_NODE_ALIAS}" "echo \"bash <(cat /var/log/${SH_NAME}/exec/${SH_NAME}) --days \"\"${ALLOW_DAYS}\"\" --backup_source_path \"\"${BACKUP_SOURCE_PATH}\"\" --backup_dest_path \"\"${BACKUP_DEST_PATH}\"\" --backup_source_alias \"\"${BACKUP_SOURCE_ALIAS}\"\" --backup_dest_alias \"\"${BACKUP_DEST_ALIAS}\"\" --backup_group \"\"${BACKUP_GROUP_INFO}\"\" --backup_type \"\"${BACKUP_TYPE}\"\" --backup_date_type \"\"${BACKUP_DATE_TYPE}\"\" --backup_operation_name \"\"${BACKUP_OPERATION_NAME}\"\" -y\" >> /var/log/${SH_NAME}/exec/run-\"${OPERATION_CRON_NAME}\""
    fi
    _success "部署成功"
}

Remove(){
    if [ "${REMOVE_OPERATION_FILE}" = "all" ]; then
        _info "开始卸载工具本身和生成的日志，不会对同步或备份文件产生任何影响"
        ssh "${REMOVE_NODE_ALIAS}" "rm -rf /var/log/${SH_NAME}"
        ssh "${REMOVE_NODE_ALIAS}" "sed -i \"/${SH_NAME}/d\" /etc/bashrc"
        ssh "${REMOVE_NODE_ALIAS}" "sed -i \"/${SH_NAME}/d\" /etc/crontab"
    else
        _info "开始卸载指定的方案组，不会对其他方案组、同步或备份文件产生任何影响"
        ssh "${REMOVE_NODE_ALIAS}" "rm -rf /var/log/${SH_NAME}/exec/run-${REMOVE_OPERATION_FILE}"
        ssh "${REMOVE_NODE_ALIAS}" "sed -i \"/${REMOVE_OPERATION_FILE}/d\" /etc/crontab"
    fi
    _success "卸载成功"
}

Clean(){
    if [ -d "/var/log/${SH_NAME}" ]; then
        _warning "发现脚本运行残留，正在清理"
        rm -rf /var/log/${SH_NAME}
        _success "清理完成"
    else
        _success "未发现脚本运行残留"
    fi
}

Help(){
    _successnoblank "
    本脚本依赖SCP传输
    所有内置选项及传参格式如下，有参选项必须加具体参数，否则脚本会自动检测并阻断运行:"| column -t

    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    --sync_source_path 同步源路径
    --sync_dest_path 同步目的路径
    --backup_source_path 备份源路径
    --backup_dest_path 备份目的路径

    --sync_source_alias 同步源节点别名
    --sync_dest_alias 同步目的节点别名
    --backup_source_alias 备份源节点别名
    --backup_dest_alias 备份目的节点别名
    --days 指定允许搜索的最长历史天数" | column -t

    echo ""
    echo "
    -G | --sync_group 同步需指定的免密节点组名
    -g | --backup_group 备份需指定的免密节点组名
    -T | --sync_type 同步的内容类型(文件或文件夹:file或dir)
    -t | --backup_type 备份的内容类型(文件或文件夹:file或dir)

    -D | --sync_date_type 指定同步时包含的日期格式
    -d | --backup_date_type 指定备份时包含的日期格式

    -N | --sync_operation_name 指定部署的同步操作名称(仅部署时用于识别，执行时可不写)
    -n | --backup_operation_name 指定部署的备份操作名称(仅部署时用于识别，执行时可不写)

    -O | --operation_cron 指定方案组工作的定时规则
    -o | --operation_cron_name 指定方案组名称
    -E | --log_cron 指定删除过期日志的定时规则

    -R | --remove 指定卸载脚本的节点别名
    -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
    -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)
    -L | --deploy 指定部署脚本的节点别名
    -l | --deploy_group_info 指定部署脚本的节点所属免密节点组名" | column -t
    
    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -s | --check_dep_sep 只检测并打印脚本运行必备依赖情况的详细信息并退出
    -e | --delete_expired_log 即时删除超期历史日志文件并退出
    -c | --clean 清理脚本在本地测试运行或部署功能时的残留(不含指定错误路径导致的文件夹被新建情况)
    -y | --yes 确认执行所有检测结果后的实际操作
    -h | --help 打印此帮助信息并退出" | column -t
    echo ""
    echo "----------------------------------------------------------------"
    _warningnoblank "以下为根据脚本内置5种可重复功能归类各自选项(存在选项复用情况)"
    echo ""
    _successnoblank "|------------|"
    _successnoblank "|部署同步功能|"
    _successnoblank "|------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    --sync_source_path 同步源路径
    --sync_dest_path 同步目的路径
    --sync_source_alias 同步源节点别名
    --sync_dest_alias 同步目的节点别名
    --days 指定允许搜索的最长历史天数" | column -t

    echo ""
    echo "
    -G | --sync_group 同步需指定的免密节点组名
    -T | --sync_type 同步的内容类型(文件或文件夹:file或dir)
    -D | --sync_date_type 指定同步时包含的日期格式
    -N | --sync_operation_name 指定部署的同步操作名称(仅部署时用于识别)" | column -t

    echo ""
    echo "
    -O | --operation_cron 指定方案组工作的定时规则
    -o | --operation_cron_name 指定方案组名称
    -E | --log_cron 指定删除过期日志的定时规则
    -L | --deploy 指定部署脚本的节点别名
    -l | --deploy_group_info 指定部署脚本的节点所属免密节点组名" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""


    _successnoblank "|------------|"
    _successnoblank "|部署备份功能|"
    _successnoblank "|------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    --backup_source_path 备份源路径
    --backup_dest_path 备份目的路径
    --backup_source_alias 备份源节点别名
    --backup_dest_alias 备份目的节点别名
    --days 指定允许搜索的最长历史天数" | column -t

    echo ""
    echo "
    -g | --backup_group 备份需指定的免密节点组名
    -t | --backup_type 备份的内容类型(文件或文件夹:file或dir)
    -d | --backup_date_type 指定备份时包含的日期格式
    -n | --backup_operation_name 指定部署的备份操作名称(仅部署时用于识别)" | column -t

    echo ""
    echo "
    -O | --operation_cron 指定方案组工作的定时规则
    -o | --operation_cron_name 指定方案组名称
    -E | --log_cron 指定删除过期日志的定时规则
    -L | --deploy 指定部署脚本的节点别名
    -l | --deploy_group_info 指定部署脚本的节点所属免密节点组名" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successnoblank "|------------|"
    _successnoblank "|执行同步功能|"
    _successnoblank "|------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    --sync_source_path 同步源路径
    --sync_dest_path 同步目的路径
    --sync_source_alias 同步源节点别名
    --sync_dest_alias 同步目的节点别名
    --days 指定允许搜索的最长历史天数" | column -t

    echo ""
    echo "
    -G | --sync_group 同步需指定的免密节点组名
    -T | --sync_type 同步的内容类型(文件或文件夹:file或dir)
    -D | --sync_date_type 指定同步时包含的日期格式
    -N | --sync_operation_name 指定部署的同步操作名称(仅部署时用于识别，执行时可不写)" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successnoblank "|------------|"
    _successnoblank "|执行备份功能|"
    _successnoblank "|------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    --backup_source_path 备份源路径
    --backup_dest_path 备份目的路径
    --backup_source_alias 备份源节点别名
    --backup_dest_alias 备份目的节点别名
    --days 指定允许搜索的最长历史天数" | column -t

    echo ""
    echo "
    -g | --backup_group 备份需指定的免密节点组名
    -t | --backup_type 备份的内容类型(文件或文件夹:file或dir)
    -d | --backup_date_type 指定备份时包含的日期格式
    -n | --backup_operation_name 指定部署的备份操作名称(仅部署时用于识别，执行时可不写)" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successnoblank "|--------------------|"
    _successnoblank "|卸载方案组或全部功能|"
    _successnoblank "|--------------------|"
    _warningnoblank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    -R | --remove 指定卸载脚本的节点别名
    -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
    -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t

    _warningnoblank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""
}

Main(){
    EnvCheck
    # 卸载检测和执行
    CheckRemoveOption  # 这里有一个检测退出和确认执行完成后退出的功能，只要进入此模块后成功进入部署分支，无论成功与否都不会走完此模块后往下执行
    CheckExecOption
    CheckDeployOption  # 这里有一个检测退出和确认执行完成后退出的功能，只要进入此模块后成功进入部署分支，无论成功与否都不会走完此模块后往下执行
    CheckTransmissionStatus
    SearchCondition
}

# 只执行完就直接退出
[ "${HELP}" -eq 1 ] && Help && exit 0
[ "${DELETE_EXPIRED_LOG}" -eq 1 ] && DeleteExpiredLog && exit 0
[ "${NEED_CLEAN}" -eq 1 ] && Clean && exit 0

[ ! -d /var/log/${SH_NAME} ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}/{exec,log}
Main | tee -a "${EXEC_COMMON_LOGFILE}"
