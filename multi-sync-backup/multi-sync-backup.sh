#!/bin/bash
# 作者: Oliver
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

# 变量名
# shName 值必须和脚本名完全相同，脚本名修改的话必须改这里
shName="multi-sync-backup"
execCommonLogFile=/var/log/${shName}/log/exec-"$(date +"%Y-%m-%d")".log
execErrorWarningSyncLogFile=/var/log/${shName}/log/exec-error-warning-sync-"$(date +"%Y-%m-%d")".log
execErrorWarningBackupLogFile=/var/log/${shName}/log/exec-error-warning-backup-"$(date +"%Y-%m-%d")".log

syncSourcePath=
syncDestPath=
backupSourcePath=
backupDestPath=

syncSourceAlias=
syncDestAlias=
backupSourceAlias=
backupDestAlias=

syncGroupInfo=
backupGroupInfo=
syncType=
backupType=
syncDateType=
backupDateType=
syncOperationName=
backupOperationName=

operationCron=
operationCronName=
logCron=

removeNodeAlias=
removeGroupInfo=
removeOperationFile=
deployNodeAlias=
deployGroupInfo=

allowDays=

checkDepSep=0
deleteExpiredLog=0
needClean=0
confirmContinue=0
needHelp=0
createdTempSyncSourceFolder=""
createdTempSyncDestFolder=""
createdTempBackupDestFolder=""

if ! ARGS=$(getopt -a -o G:,g:,T:,t:,D:,d:,N:,n:,O:,o:,L:,l:,R:,r:,F:,s,E:,e,c,y,h -l sync_source_path:,sync_dest_path:,backup_source_path:,backup_dest_path:,sync_source_alias:,sync_dest_alias:,backup_source_alias:,backup_dest_alias:,sync_group:,backup_group:,sync_type:,backup_type:,sync_operation_name:,backup_operation_name:,sync_date_type:,backup_date_type:,operation_cron:,operation_cron_name:,log_cron:,remove:,remove_group_info:,remove_operation_file:,deploy:,deploy_group_info:,days:,check_dep_sep,deploy,delete_expired_log,clean,yes,help -- "$@")
then
    _error "脚本中没有此无参选项或此选项为有参选项"
    exit 1
elif [ -z "$1" ]; then
    _error "没有设置选项，请查看以下帮助菜单"
    needHelp=1
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
            syncSourcePath="$2"
        fi
        shift
        ;;
    --sync_dest_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 2
        else
            syncDestPath="$2"
        fi
        shift
        ;;
    --backup_source_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            backupSourcePath="$2"
        fi
        shift
        ;;
    --backup_dest_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 2
        else
            backupDestPath="$2"
        fi
        shift
        ;;

    # 始末端同步和备份节点别名
    --sync_source_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            syncSourceAlias="$2"
        fi
        shift
        ;;
    --sync_dest_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            syncDestAlias="$2"
        fi
        shift
        ;;
    --backup_source_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            backupSourceAlias="$2"
        fi
        shift
        ;;
    --backup_dest_alias)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            backupDestAlias="$2"
        fi
        shift
        ;;

    # 同步或备份方案的节点组名    
    -G | --sync_group)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            syncGroupInfo="$2"
        fi
        shift
        ;;
    -g | --backup_group)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            backupGroupInfo="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定内容类型（纯文件或纯文件夹）
    -T | --sync_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            syncType="$2"
        fi
        shift
        ;;
    -t | --backup_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            backupType="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定日期格式
    -D | --sync_date_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            syncDateType="$2"
        fi
        shift
        ;;
    -d | --backup_date_type)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            backupDateType="$2"
        fi
        shift
        ;;

    # 指定同步或备份方案各自的名称
    -N | --sync_operation_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            syncOperationName="$2"
        fi
        shift
        ;;
    -n | --backup_operation_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            backupOperationName="$2"
        fi
        shift
        ;;

    # 同步或备份方案的指定定时方案
    -O | --operation_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            operationCron="$2"
        fi
        shift
        ;;
    -o | --operation_cron_name)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            operationCronName="$2"
        fi
        shift
        ;;
    -E | --log_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            logCron="$2"
        fi
        shift
        ;;

    # 安装卸载相关选项
    -R | --remove)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            removeNodeAlias="$2"
        fi
        shift
        ;;
    -r | --remove_group_info)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            removeGroupInfo="$2"
        fi
        shift
        ;;
    -F | --remove_operation_file)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            removeOperationFile="$2"
        fi
        shift
        ;;
    -L | --deploy)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            deployNodeAlias="$2"
        fi
        shift
        ;;
    -l | --deploy_group_info)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            deployGroupInfo="$2"
        fi
        shift
        ;;

    # 允许搜索的最长历史天数
    --days)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            allowDays="$2"
        fi
        shift
        ;;
    
    # 其他选项
    -s | --check_dep_sep)
        checkDepSep=1
        ;;
    -e | --delete_expired_log)
        deleteExpiredLog=1
        ;;
    -c | --clean)
        needClean=1
        ;;
    -y | --yes)
        confirmContinue=1
        ;;
    -h | --help)
        needHelp=1
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
    [ "${checkDepSep}" == 1 ] && _info "开始检查脚本正常工作所需依赖的安装情况"
    local appList
    appList="tput scp pwd basename sort tail tee md5sum ip ifconfig shuf column sha256sum dirname stat"
    local appNotInstalled
    appNotInstalled=""
    for i in ${appList}; do
        if which "$i" >/dev/null 2>&1; then
            [ "${checkDepSep}" == 1 ] && _success "$i 已安装"
        else
            [ "${checkDepSep}" == 1 ] && _error "$i 未安装"
            appNotInstalled="${appNotInstalled} $i"
        fi
    done
    if [ -n "${appNotInstalled}" ]; then
        _error "未安装的软件为: ${appNotInstalled}"
        _error "当前运行环境不支持部分脚本功能，为安全起见，此脚本在重新适配前运行都将自动终止进程"
        exit 1
    elif [ -z "${appNotInstalled}" ]; then
        [ "${checkDepSep}" == 1 ] && _success "脚本正常工作所需依赖已全部安装"
    fi

    # 以下环节用于检测是否有人为修改免密节点组信息的情况，并且在存在这种情况的前提下尝试自动修复，/root/.ssh/config 文件中应该包含各种免密组的文件夹名，所以默认脚本均检测此文件内容
    # 为防止此文件被误删，在每个创建的免密组文件夹中均有一个创建该组时对 config 硬链接的文件，名字是 .backup_config
    # 自检流程：
    [ "${checkDepSep}" == 1 ] && _info "开始检查系统免密环境完整性，如存在破坏情况则尝试自动修复，实在无法修复将停止运行，不会影响到系统本身"
    # 1. 如果 /root/.ssh/config 不存在，则遍历 /root/.ssh 下的所有文件夹，查找里面的 .backup_config，如果都不存在则表示环境被毁或没有用专用脚本做免密部署，直接报错退出，如果存在，则取找到的列表中的第一个直接做个硬链接成 /root/.ssh/config
    if [ ! -f /root/.ssh/config ]; then
        _warning "自动部署的业务节点免密组配置文件被人为删除，正在尝试恢复"
        local backupConfig
        mapfile -t backupConfig < <(find /root/.ssh -type f -name ".backup_config")
        if [ "${#backupConfig[@]}" -eq 0 ]; then
            _error "所有 ssh 业务节点免密组的配置文件均未找到，如果此服务器未使用本脚本作者所写免密部署脚本部署，请先使用免密部署工具进行预部署后再执行此脚本"
            _error "如果曾经预部署过，请立即人工恢复，否则所有此脚本作者所写的自动化脚本将全体失效"
            exit 1
        elif [ "${#backupConfig[@]}" -ne 0 ]; then
            ln "${backupConfig[0]}" /root/.ssh/config
            _success "业务节点免密组默认配置文件恢复"
        fi
    fi

    # 2. 如果 /root/.ssh/config 存在，则遍历 /root/.ssh/config 中保存的节点组名的配置对比 /root/.ssh 下的所有文件夹名，查找里面的 .backup_config，在 /root/.ssh/config 中存在但对应文件夹中不存在 .backup_config 则做个硬链接到对应文件夹，
    # 如果文件夹被删，则删除 config 中的配置并报错退出
    mapfile -t groupNameInFile < <(awk -F '[ /]' '/Include/{print $2}' /root/.ssh/config)
    for i in "${groupNameInFile[@]}"; do
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

    # 3. 遍历 /root/.ssh 中的所有子文件夹中的 .backup_config 文件，然后对比查看对应文件夹名在 config 文件中是否有相关信息（上一步的 groupNameInFile 数组），没有的话添加上
    # 如果出现 config 文件与免密组文件夹名对不上的情况，可以清空 config 文件中的内容，通过文件夹的方式重新生成
    local dirGroupName
    mapfile -t dirGroupName < <(find /root/.ssh -type f -name ".backup_config"|awk -F '/' '{print $(NF-1)}')
    mapfile -t groupNameInFile < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    for i in "${dirGroupName[@]}"; do
        MARK=0
        for j in "${groupNameInFile[@]}"; do
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
    local dirAuthorizedKeysPath
    mapfile -t dirAuthorizedKeysPath < <(find /root/.ssh -type f -name "*-authorized_keys"|sed 's/\/root\///g')
    local sshdConfigPath
    IFS=" " read -r -a sshdConfigPath <<< "$(grep "AuthorizedKeysFile" /etc/ssh/sshd_config|awk '$1=""; {print $0}')"
    local needRestartSshd
    needRestartSshd=0
    for i in "${dirAuthorizedKeysPath[@]}"; do
        MARK=0
        for j in "${sshdConfigPath[@]}"; do
            if [ "${i}" = "${j}" ];then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            needRestartSshd=1
            _warning "sshd 配置文件缺少有关免密参数，正在修改"
            i=$(echo "$i"|sed 's/\//\\\//g')
            sed -i "/AuthorizedKeysFile/s/$/\ ${i}/g" /etc/ssh/sshd_config
        fi
    done
    [ "${needRestartSshd}" -eq 1 ] && systemctl restart sshd
    [ "${checkDepSep}" == 1 ] && _success "系统免密环境完整性检测完成，已自动修复脚本正常工作所依赖的系统完整性(如果存在被破坏情况)" && _success "环境自检完成" && exit 0
    _success "环境自检完成"
}

CheckExecOption(){
    _info "开始检查传递的执行选项和参数"
    ################################################################
    # 仅运行同步备份或先同步再备份的所有选项
      if [ -n "${syncSourcePath}" ] && [ -n "${syncDestPath}" ] && [ -n "${syncSourceAlias}" ] && [ -n "${syncDestAlias}" ] && [ -n "${syncGroupInfo}" ] && [ -n "${syncType}" ] && [ -n "${syncDateType}" ] && [ -z "${backupSourcePath}" ] && [ -z "${backupDestPath}" ] && [ -z "${backupSourceAlias}" ] && [ -z "${backupDestAlias}" ] && [ -z "${backupGroupInfo}" ] && [ -z "${backupType}" ] && [ -z "${backupDateType}" ] && [ -n "${allowDays}" ] && [ -n "${syncOperationName}" ] && [ -z "${backupOperationName}" ]; then
        :
    elif [ -n "${syncSourcePath}" ] && [ -n "${syncDestPath}" ] && [ -n "${syncSourceAlias}" ] && [ -n "${syncDestAlias}" ] && [ -n "${syncGroupInfo}" ] && [ -n "${syncType}" ] && [ -n "${syncDateType}" ] && [ -z "${backupSourcePath}" ] && [ -z "${backupDestPath}" ] && [ -z "${backupSourceAlias}" ] && [ -z "${backupDestAlias}" ] && [ -z "${backupGroupInfo}" ] && [ -z "${backupType}" ] && [ -z "${backupDateType}" ] && [ -n "${allowDays}" ]; then
        :
    elif [ -z "${syncSourcePath}" ] && [ -z "${syncDestPath}" ] && [ -z "${syncSourceAlias}" ] && [ -z "${syncDestAlias}" ] && [ -z "${syncGroupInfo}" ] && [ -z "${syncType}" ] && [ -z "${syncDateType}" ] && [ -n "${backupSourcePath}" ] && [ -n "${backupDestPath}" ] && [ -n "${backupSourceAlias}" ] && [ -n "${backupDestAlias}" ] && [ -n "${backupGroupInfo}" ] && [ -n "${backupType}" ] && [ -n "${backupDateType}" ] && [ -n "${allowDays}" ] && [ -z "${syncOperationName}" ] && [ -n "${backupOperationName}" ]; then
        :
    elif [ -z "${syncSourcePath}" ] && [ -z "${syncDestPath}" ] && [ -z "${syncSourceAlias}" ] && [ -z "${syncDestAlias}" ] && [ -z "${syncGroupInfo}" ] && [ -z "${syncType}" ] && [ -z "${syncDateType}" ] && [ -n "${backupSourcePath}" ] && [ -n "${backupDestPath}" ] && [ -n "${backupSourceAlias}" ] && [ -n "${backupDestAlias}" ] && [ -n "${backupGroupInfo}" ] && [ -n "${backupType}" ] && [ -n "${backupDateType}" ] && [ -n "${allowDays}" ]; then
        :
    else
        _error "用户层面只有两种输入选项参数的组合方式，同步或备份，先同步后备份则是执行两次，请仔细对比帮助信息并检查缺失或多输入的选项和参数"
        _warning "运行同步功能所需的八个有参选项(两个通用选项见下):"
        _errorNoBlank "
        --sync_source_path 设置源同步路径
        --sync_dest_path 设置目的同步路径
        --sync_source_alias 设置源同步节点别名
        --sync_dest_alias 设置目的同步节点别名"|column -t
        _errorNoBlank "
        -G | --sync_group 同步需指定的免密节点组名
        -T | --sync_type 同步的内容类型(文件或文件夹:file或dir)
        -D | --sync_date_type 指定同步时包含的日期格式"|column -t
        echo ""
        _warning "运行备份功能所需的八个有参选项(两个通用选项见下):"
        _errorNoBlank "
        --backup_source_path 设置源备份路径
        --backup_dest_path 设置目的备份路径
        --backup_source_alias 设置源备份节点别名
        --backup_dest_alias 设置目的备份节点别名"|column -t
        _errorNoBlank "
        -g | --backup_group 备份需指定的免密节点组名
        -t | --backup_type 备份的内容类型(文件或文件夹:file或dir)
        -d | --backup_date_type 指定备份时包含的日期格式"|column -t
        echo ""
        _warning "两种组合方式中，任何选项均没有次序要求"
        _errorNoBlank "运行任意一种功能均需设置最长查找历史天数的有参选项: --days"
        exit 1
    fi

    mapfile -t groupNameInFile < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
    # 同步节点组名非空时，检查其他所有同步选项
    if [ -n "${syncGroupInfo}" ]; then
        for i in "${groupNameInFile[@]}"; do
            MARK=0
            if [ "$i" = "${syncGroupInfo}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的同步免密节点组名称"
            _error "可用节点组如下:"
            for i in "${groupNameInFile[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        [[ ! "${syncSourcePath}" =~ ^/ ]] && _error "设置的源同步节点路径必须为绝对路径，请检查" && exit 112
        [[ ! "${syncDestPath}" =~ ^/ ]] && _error "设置的目的同步节点路径必须为绝对路径，请检查" && exit 112

        mapfile -t hostAlias < <(cat /root/.ssh/"${syncGroupInfo}"/config-"${syncGroupInfo}"-*|awk '/Host / {print $2}')
        for i in "${hostAlias[@]}"; do
                MARK=0
            [ "${i}" = "${syncSourceAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源同步节点别名错误，请检查指定的免密节点组名中可用的源同步节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        for i in "${hostAlias[@]}"; do
            MARK=0
            [ "${i}" = "${syncDestAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "目的同步节点别名错误，请检查指定的免密节点组名中可用的目的同步节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if [ ! "${syncType}" = "dir" ] && [ ! "${syncType}" = "file" ]; then
            _error "必须正确指定需要操作的内容类型参数: 按日期排序的文件或文件夹"
            _error "纯文件参数写法: dir"
            _error "纯文件夹参数写法: file"
            exit 1
        fi

        if [[ "${syncDateType}" =~ ^[0-9a-zA-Z]{4}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}+$ ]]; then
            syncDateTypeConverted="YYYY-MMMM-DDDD"
        elif [[ "${syncDateType}" =~ ^[0-9a-zA-Z]{4}_[0-9a-zA-Z]{2}_[0-9a-zA-Z]{2}+$ ]]; then
            syncDateTypeConverted="YYYY_MMMM_DDDD"
        else
            _error "同步日期格式不存在，格式举例: abcd-Mm-12 或 2000_0a_3F，年份四位，月和日均为两位字符"
            _error "格式支持大小写字母和数字随机组合，只检测连接符号特征，支持的格式暂时只有连字符(-)和下划线(_)两种"
            exit 1
        fi
    fi

    # 备份节点组名非空时，检查其他所有备份选项
    if [ -n "${backupGroupInfo}" ]; then
        for i in "${groupNameInFile[@]}"; do
            MARK=0
            if [ "$i" = "${backupGroupInfo}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的免密节点组名称"
            _error "可用节点组如下:"
            for i in "${groupNameInFile[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        [[ ! "${backupSourcePath}" =~ ^/ ]] && _error "设置的源备份节点路径必须为绝对路径，请检查" && exit 112
        [[ ! "${backupDestPath}" =~ ^/ ]] && _error "设置的目的备份节点路径必须为绝对路径，请检查" && exit 112
        
        mapfile -t hostAlias < <(cat /root/.ssh/"${backupGroupInfo}"/config-"${backupGroupInfo}"-*|awk '/Host / {print $2}')
        for i in "${hostAlias[@]}"; do
            MARK=0
            [ "${i}" = "${backupSourceAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "源备份节点别名错误，请检查指定的免密节点组名中可用的源备份节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        for i in "${hostAlias[@]}"; do
            MARK=0
            [ "${i}" = "${backupDestAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "目的备份节点别名错误，请检查指定的免密节点组名中可用的目的备份节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi

        if [ ! "${backupType}" = "dir" ] && [ ! "${backupType}" = "file" ]; then
            _error "必须正确指定需要操作的内容类型参数: 按日期排序的文件或文件夹"
            _error "纯文件参数写法: dir"
            _error "纯文件夹参数写法: file"
            exit 1
        fi
        
        if [[ "${backupDateType}" =~ ^[0-9a-zA-Z]{4}-[0-9a-zA-Z]{2}-[0-9a-zA-Z]{2}+$ ]]; then
            backupDateTypeConverted="YYYY-MMMM-DDDD"
        elif [[ "${backupDateType}" =~ ^[0-9a-zA-Z]{4}_[0-9a-zA-Z]{2}_[0-9a-zA-Z]{2}+$ ]]; then
            backupDateTypeConverted="YYYY_MMMM_DDDD"
        else
            _error "同步日期格式不存在，格式举例: abcd-Mm-12 或 2000_0a_3F，年份四位字符，月和日均为两位字符"
            _error "格式支持大小写字母和数字随意组合，只检测连接符号特征，支持的格式暂时只有连字符和下划线两种"
            exit 1
        fi
    fi

    if [ -z "${allowDays}" ] || [[ ! "${allowDays}" =~ ^[0-9]+$ ]]; then
        _error "未设置允许搜索的最早日期距离今日的最大天数，请检查"
        _error "选项名为: --days  参数为非负整数"
        exit 116
    fi
    _success "所有执行参数选项指定正确"
}

CheckDeployOption(){
    # 检查部署选项
    if [ -n "${deployNodeAlias}" ]; then
        _info "开始检查传递的部署选项和参数"
          if [ -n "${operationCron}" ] && [ -n "${operationCronName}" ] && [ -n "${deployGroupInfo}" ] && [ -n "${logCron}" ] && [ -n "${syncOperationName}" ] && [ -n "${backupOperationName}" ]; then
            :
        elif [ -n "${operationCron}" ] && [ -n "${operationCronName}" ] && [ -n "${deployGroupInfo}" ] && [ -n "${logCron}" ] && [ -n "${syncOperationName}" ]; then
            :
        elif [ -n "${operationCron}" ] && [ -n "${operationCronName}" ] && [ -n "${deployGroupInfo}" ] && [ -n "${logCron}" ] && [ -n "${backupOperationName}" ]; then
            :
        else
            _error "部署时用户层面只有三种输入选项参数的组合方式，除了需要以上执行同步、备份、同步后备份的操作的所有选项外，还需指定部署节点、删除过期日志定时、操作别名和操作定时，请仔细对比帮助信息并检查缺失的选项和参数"
            _warning "部署同步功能所需的六个有参选项(五个通用选项见下):"
            _errorNoBlank "
            -N | --sync_operation_name 设置同步操作的别名"|column -t
            echo ""
            _warning "部署备份功能所需的六个有参选项(五个通用选项见下):"
            _errorNoBlank "
            -n | --backup_operation_name 设置备份操作的别名"|column -t
            echo ""
            _warning "运行任意一种功能均需设置的五种通用有参选项: "
            _errorNoBlank "
            -L | --deploy 设置部署节点别名
            -O | --operation_cron 设置方案组启动定时规则
            -o | --operation_cron_name 设置方案组名
            -l | --deploy_group_info 指定部署节点所在的免密节点组名
            -E | --log_cron 设置删除过期日志定时规则"|column -t
            _warning "启用同步后备份的功能需要以上所有有参选项共七个，三种组合方式中，任何选项均没有次序要求"
            exit 1
        fi

        mapfile -t groupNameInFile < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
        for i in "${groupNameInFile[@]}"; do
            MARK=0
            if [ "$i" = "${deployGroupInfo}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的同步免密节点组名称"
            _error "可用节点组如下:"
            for i in "${groupNameInFile[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        mapfile -t hostAlias < <(cat /root/.ssh/"${deployGroupInfo}"/config-"${deployGroupInfo}"-*|awk '/Host / {print $2}')
        for i in "${hostAlias[@]}"; do
            MARK=0
            [ "${i}" = "${deployNodeAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "部署节点别名错误，请检查指定的免密节点组名中可用的部署节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if ssh -o BatchMode=yes "${deployNodeAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "部署节点 ${deployNodeAlias} 连接正常"
        else
            _error "部署节点 ${deployNodeAlias} 无法连接，请检查源部署节点硬件是否损坏"
            MARK=1
        fi

        # 参数传入规范检查
        if [[ ! "${logCron}" =~ ^[0-9\*,/[:blank:]-]*$ ]]; then
            _error "清理过期日志定时写法有错，请检查"
            exit 1
        fi
        if [[ ! "${operationCron}" =~ ^[0-9\*,/[:blank:]-]*$ ]]; then
            _error "集合操作定时写法有错，请检查"
            exit 1
        fi
        if [[ ! "${operationCronName}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
            _error "集合操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
            exit 1
        fi
        if [ -n "${syncOperationName}" ]; then
            if [[ ! "${syncOperationName}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "同步操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi
        if [ -n "${backupOperationName}" ]; then
            if [[ ! "${backupOperationName}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "备份操作别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi
        local operationCronNameFile
        mapfile -t operationCronNameFile < <(ssh "${deployNodeAlias}" "find /var/log/${shName}/exec -maxdepth 1 -type f -name "*run-*"|sed 's/run-//g'|awk -F '/' '{print \$NF}'")
        MARK=0
        for i in "${operationCronNameFile[@]}"; do
            [ "$i" = "${operationCronName}" ] && MARK=1
        done

        local markSyncOperationName
        local markBackupOperationName
        markSyncOperationName=0
        markBackupOperationName=0
        if [ "${MARK}" -eq 1 ]; then
            local syncOperationNameList
            local backupOperationNameList
            mapfile -t syncOperationNameList < <(ssh "${deployNodeAlias}" "grep -o \"\-\-sync_operation_name .* \" /var/log/${shName}/exec/run-${operationCronName}|awk '{print \$2}'")
            mapfile -t backupOperationNameList < <(ssh "${deployNodeAlias}" "grep -o \"\-\-backup_operation_name .* \" /var/log/${shName}/exec/run-${operationCronName}|awk '{print \$2}'")
            local sameSyncOperationNameList
            local sameBackupOperationNameList
            sameSyncOperationNameList=()
            sameBackupOperationNameList=()
            for i in "${syncOperationNameList[@]}"; do
                [ "$i" = "${syncOperationName}" ] && markSyncOperationName=1 && break
            done

            for i in "${backupOperationNameList[@]}"; do
                [ "$i" = "${backupOperationName}" ] && markBackupOperationName=1 && break
            done
            
            mapfile -t -O "${#sameSyncOperationNameList[@]}" sameSyncOperationNameList < <(ssh "${deployNodeAlias}" "grep \"\-\-sync_operation_name ${syncOperationName}\" /var/log/${shName}/exec/run-${operationCronName}")
            mapfile -t -O "${#sameBackupOperationNameList[@]}" sameBackupOperationNameList < <(ssh "${deployNodeAlias}" "grep \"\-\-backup_operation_name ${backupOperationName}\" /var/log/${shName}/exec/run-${operationCronName}")
            # 信息汇总
            _success "已收集所需信息，请检查以下汇总信息:"
            _success "部署节点 ${deployNodeAlias} 中存在方案组文件 /var/log/${shName}/exec/run-${operationCronName}"
            if [ "${markSyncOperationName}" -eq 1 ]; then
                _warning "在以上方案组文件中发现同名同步执行功能，请自行辨认，如果功能重复或只是希望更新信息，则请手动删除无用的执行功能"
                _warning "如果确认部署的话将追加而非替换，以下是全部同名同步执行功能:"
                for i in "${sameSyncOperationNameList[@]}"; do
                    echo "$i"
                done
                echo ""
            fi
            if [ "${markBackupOperationName}" -eq 1 ]; then
                _warning "在以上方案组文件中发现同名备份执行功能，请自行辨认，如果功能重复或只是希望更新信息，则请手动删除无用的执行功能"
                _warning "如果确认部署的话将追加而非替换，以下是全部同名备份执行功能:"
                for i in "${sameBackupOperationNameList[@]}"; do
                    echo "$i"
                done
                echo ""
            fi
            _warning "将向部署节点 ${deployNodeAlias} 中创建的 ${operationCronName} 方案组加入以下执行功能:"
            if [ -n "${syncOperationName}" ]; then
                echo "bash <(cat /var/log/${shName}/exec/${shName}) --days \"${allowDays}\" --sync_source_path \"${syncSourcePath}\" --sync_dest_path \"${syncDestPath}\" --sync_source_alias \"${syncSourceAlias}\" --sync_dest_alias \"${syncDestAlias}\" --sync_group \"${syncGroupInfo}\" --sync_type \"${syncType}\" --sync_date_type \"${syncDateType}\" --sync_operation_name \"${syncOperationName}\" -y"
                echo ""
            fi
            if [ -n "${backupOperationName}" ]; then
                echo "bash <(cat /var/log/${shName}/exec/${shName}) --days \"${allowDays}\" --backup_source_path \"${backupSourcePath}\" --backup_dest_path \"${backupDestPath}\" --backup_source_alias \"${backupSourceAlias}\" --backup_dest_alias \"${backupDestAlias}\" --backup_group \"${backupGroupInfo}\" --backup_type \"${backupType}\" --backup_date_type \"${backupDateType}\" --backup_operation_name \"${backupOperationName}\" -y"
                echo ""
            fi
        else
            # 信息汇总
            _success "已收集所需信息，请检查以下汇总信息:"
            _warning "部署节点 ${deployNodeAlias} 中未找到方案组 /var/log/${shName}/exec/run-${operationCronName}，即将创建该文件"
            _warning "将向部署节点 ${deployNodeAlias} 中创建的 ${operationCronName} 方案组加入以下执行功能:"
            if [ -n "${syncOperationName}" ]; then
                echo "bash <(cat /var/log/${shName}/exec/${shName}) --days \"${allowDays}\" --sync_source_path \"${syncSourcePath}\" --sync_dest_path \"${syncDestPath}\" --sync_source_alias \"${syncSourceAlias}\" --sync_dest_alias \"${syncDestAlias}\" --sync_group \"${syncGroupInfo}\" --sync_type \"${syncType}\" --sync_date_type \"${syncDateType}\" --sync_operation_name \"${syncOperationName}\" -y"
            fi
            if [ -n "${backupOperationName}" ]; then
                echo "bash <(cat /var/log/${shName}/exec/${shName}) --days \"${allowDays}\" --backup_source_path \"${backupSourcePath}\" --backup_dest_path \"${backupDestPath}\" --backup_source_alias \"${backupSourceAlias}\" --backup_dest_alias \"${backupDestAlias}\" --backup_group \"${backupGroupInfo}\" --backup_type \"${backupType}\" --backup_date_type \"${backupDateType}\" --backup_operation_name \"${backupOperationName}\" -y"
            fi
        fi

        # 部署流程末尾，无论是否确认，各自功能都会运行完成后退出
        if [ "${confirmContinue}" -eq 1 ]; then
            Deploy
            exit 0
        else
            _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行部署"
            exit 0
        fi
    else
        if [ -n "${operationCron}" ] || [ -n "${operationCronName}" ] || [ -n "${logCron}" ] || [ -n "${deployGroupInfo}" ]; then
            _warning "以下四个选项均为部署时的独占功能，如果只是运行备份或同步功能的话不要加上这些选项中的任意一个或多个"
            _errorNoBlank "
            -O | --operation_cron 设置方案组启动定时规则
            -o | --operation_cron_name 设置方案组名
            -l | --deploy_group_info 指定部署节点所在的免密节点组名
            -E | --log_cron 设置删除过期日志定时规则"|column -t
            _errorNoBlank "以上选项必须和指定部署脚本的节点别名选项同时被指定: -L | --deploy"
            exit 1
        fi
    fi
}

CheckRemoveOption(){
    if [ -n "${removeNodeAlias}" ]; then
        _info "开始检查传递的卸载选项和参数"
        if [ -n "${removeGroupInfo}" ] && [ -n "${removeOperationFile}" ]; then
            :
        else
            _error "卸载时用户层面只有一种输入选项参数的组合方式，需同时指定:"
            _error "1. 需要卸载同步及备份脚本所在的节点"
            _error "2. 节点所在的免密节点组（操作远程卸载的节点必须和需要卸载的节点处于同一节点组）"
            _error "3. 卸载的具体的方案"
            _error "请仔细对比帮助信息并检查缺失的选项和参数"
            _warning "需设置的三种通用有参选项: "
            _errorNoBlank "
            -R | --remove 指定卸载脚本的节点别名
            -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
            -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t
            _warning "以上任何选项写在同一行均没有次序要求"
            exit 1
        fi

        mapfile -t groupNameInFile < <(awk -F '[ /]' '{print $2}' /root/.ssh/config)
        for i in "${groupNameInFile[@]}"; do
            MARK=0
            if [ "$i" = "${removeGroupInfo}" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "请输入正确的同步免密节点组名称"
            _error "可用节点组如下:"
            for i in "${groupNameInFile[@]}"; do
                echo "${i}"
            done
            exit 1
        fi
        mapfile -t hostAlias < <(cat /root/.ssh/"${removeGroupInfo}"/config-"${removeGroupInfo}"-*|awk '/Host / {print $2}')
        for i in "${hostAlias[@]}"; do
            MARK=0
            [ "${i}" = "${removeNodeAlias}" ] && MARK=1 && break
        done
        if [ "${MARK}" -eq 0 ]; then
            _error "部署节点别名错误，请检查指定的免密节点组名中可用的部署节点别名:"
            for i in "${hostAlias[@]}"; do
                echo "${i}"
            done
            exit 114
        fi
        if ssh -o BatchMode=yes "${removeNodeAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "卸载节点 ${removeNodeAlias} 连接正常"
        else
            _error "卸载节点 ${removeNodeAlias} 无法连接，请检查源部署节点硬件是否损坏"
            MARK=1
        fi

        if [ -n "${removeOperationFile}" ]; then
            if [[ ! "${removeOperationFile}" =~ ^[0-9a-zA-Z_-]*$ ]]; then
                _error "需移除的方案组别名写法有错，只支持大小写字母、数字、下划线和连字符，请检查"
                exit 1
            fi
        fi
        local isRemoveAll
        isRemoveAll=0
        local operationNameFile
        mapfile -t operationNameFile < <(ssh "${removeNodeAlias}" "find /var/log/${shName}/exec -maxdepth 1 -type f -name "run-*"|awk -F '/' '{print \$NF}'"|sed 's/run-//g')
        if [ "${removeOperationFile}" = "all" ]; then
            isRemoveAll=1
        else
            MARK=0
            for i in "${operationNameFile[@]}"; do
                [ "$i" = "${removeOperationFile}" ] && MARK=1 && break
            done
            if [ "${#operationNameFile[@]}" -gt 0 ]; then
                if [ "${MARK}" -eq 0 ]; then
                    _error "请输入正确的方案组名称"
                    _error "可选的方案组名称如下:"
                    for i in "${operationNameFile[@]}"; do
                        echo "${i}"
                    done
                    exit 1
                fi
            fi
        fi

        # 信息汇总
        if [ "${isRemoveAll}" -eq 1 ]; then
            if [ "${#operationNameFile[@]}" -eq 0 ]; then
                _warning "指定节点中不存在任何同步或备份方案组，继续执行将检查并清理系统中其余残留信息"
            else
                _warning "即将卸载指定节点中所有的同步或备份方案组，以下为需卸载节点中保存的所有方案细节:"
                ssh "${removeNodeAlias}" "sed '/\/bin\/bash/d' /var/log/${shName}/exec/run-*"
            fi
        else
            if [ "${#operationNameFile[@]}" -eq 0 ]; then
                _error "指定节点中不存在任何同步或备份方案组，如果不是人为因素导致此问题，请在卸载时直接将选项 --remove_operation_file 或 -F 的参数设置成 all 以完成全部卸载，再重新部署"
                exit 1
            else
                _warning "即将卸载指定节点中名为 ${removeOperationFile} 的同步或备份方案组，以下为需卸载节点中该方案细节:"
                ssh "${removeNodeAlias}" "sed '/\/bin\/bash/d' /var/log/${shName}/exec/run-${removeOperationFile}"
            fi
        fi

        if [ "${confirmContinue}" -eq 1 ]; then
            Remove
            exit 0
        else
            _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行卸载"
            exit 0
        fi
    else
        if [ -n "${removeGroupInfo}" ] || [ -n "${removeOperationFile}" ]; then
            _warning "以下三个选项均为卸载时的专用功能，必须同时指定或同时不指定"
            _warning "如果只是运行或部署备份/同步功能的话不要加上这些选项中的任意一个或多个"
            _errorNoBlank "
            -R | --remove 指定卸载脚本的节点别名
            -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
            -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t
            exit 1
        fi
    fi
}

CheckTransmissionStatus(){
    _info "测试节点连通性"
    MARK=0
    if [ -n "${syncSourceAlias}" ]; then
        if ssh -o BatchMode=yes "${syncSourceAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "源同步节点 ${syncSourceAlias} 连接正常"
        else
            _error "源同步节点 ${syncSourceAlias} 无法连接，请检查源同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${syncDestAlias}" ]; then
        if ssh -o BatchMode=yes "${syncDestAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "目的同步节点 ${syncDestAlias} 连接正常"
        else
            _error "目的同步节点 ${syncDestAlias} 无法连接，请检查目的同步节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${backupSourceAlias}" ]; then
        if ssh -o BatchMode=yes "${backupSourceAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "源备份节点 ${backupSourceAlias} 连接正常"
        else
            _error "源备份节点 ${backupSourceAlias} 无法连接，请检查源备份节点硬件是否损坏"
            MARK=1
        fi
    fi

    if [ -n "${backupDestAlias}" ]; then
        if ssh -o BatchMode=yes "${backupDestAlias}" "echo \"\">/dev/null 2>&1" >/dev/null 2>&1; then
            _success "目的备份节点 ${backupDestAlias} 连接正常"
        else
            _error "目的备份节点 ${backupDestAlias} 无法连接，请检查目的备份节点硬件是否损坏"
            MARK=1
        fi
    fi

    [ "${MARK}" -eq 1 ] && _error "节点连通性存在问题，请先检查节点硬件是否损坏" && exit 1
    _success "节点连通性检测通过"

    _info "开始同步/备份节点路径检查和处理"
    # 源同步节点指定的路径可以不存在，但源备份节点指定的路径必须存在否则没意义了
    # 备份一下，忘了为什么之前会用这个写法，当时应该是能正常工作的，但现在无法工作： sed -e "s/'/'\\\\''/g"
    if [ -n "${syncSourcePath}" ] && [ -n "${syncDestPath}" ]; then
        # 源同步节点路径修正
        syncSourcePath=$(echo "${syncSourcePath}" | sed -e "s/\/$//g")
        local fatherPathNotExist
        fatherPathNotExist=$(ssh "${syncSourceAlias}" "
        if [ ! -d \"${syncSourcePath}\" ]; then
            folderCount=\$(awk -F '/' '{print NF}' <<< \"${syncSourcePath}\");
            needDetectPath=\"\";
            needDetectPathList=();
            for ((i=2;i<=folderCount;i++)); do
                pathElement=\$(awk -F '/' -v i=\"\$i\" '{print \$i}' <<< \"${syncSourcePath}\");
                needDetectPath=\"\${needDetectPath}/\${pathElement}\";
                mapfile -t -O \"\${#needDetectPathList[@]}\" needDetectPathList < <(echo \"\${needDetectPath}\");
            done;
            for i in \"\${needDetectPathList[@]}\";do
                if [ ! -d \"\$i\" ]; then
                    echo \"\$i\";
                    break;
                fi;
            done;
        fi")
        if [ -n "${fatherPathNotExist}" ]; then
            _warning "源同步节点路径不存在，正在创建路径: ${syncSourcePath}"
            ssh "${syncSourceAlias}" "
                mkdir -p \"${syncSourcePath}\""
            createdTempSyncSourceFolder="${fatherPathNotExist}"
        fi
        _info "修正后的源同步节点路径: ${syncSourcePath}"

        # 目的同步节点路径修正
        syncDestPath=$(echo "${syncDestPath}" | sed -e "s/\/$//g")
        fatherPathNotExist=$(ssh "${syncDestAlias}" "
        if [ ! -d \"${syncDestPath}\" ]; then
            folderCount=\$(awk -F '/' '{print NF}' <<< \"${syncDestPath}\");
            needDetectPath=\"\";
            needDetectPathList=();
            for ((i=2;i<=folderCount;i++)); do
                pathElement=\$(awk -F '/' -v i=\"\$i\" '{print \$i}' <<< \"${syncDestPath}\");
                needDetectPath=\"\${needDetectPath}/\${pathElement}\";
                mapfile -t -O \"\${#needDetectPathList[@]}\" needDetectPathList < <(echo \"\${needDetectPath}\");
            done;
            for i in \"\${needDetectPathList[@]}\";do
                if [ ! -d \"\$i\" ]; then
                    echo \"\$i\";
                    break;
                fi;
            done;
        fi")
        if [ -n "${fatherPathNotExist}" ]; then
            _warning "目的同步节点路径不存在，正在创建路径: ${syncDestPath}"
            ssh "${syncDestAlias}" "
                mkdir -p \"${syncDestPath}\""
            createdTempSyncDestFolder="${fatherPathNotExist}"
        fi
        _info "修正后的目的同步节点路径: ${syncDestPath}"
    fi

    if [ -n "${backupSourcePath}" ] && [ -n "${backupDestPath}" ]; then
        # 源备份节点路径修正
        backupSourcePath=$(echo "${backupSourcePath}" | sed -e "s/\/$//g")
        if ssh "${backupSourceAlias}" "[ -d \"${backupSourcePath}\" ]"; then
            _info "修正后的源备份节点路径: ${backupSourcePath}"
        else
            _error "源备份节点路径不存在，请检查，退出中"
            exit 1
        fi

        # 目的备份节点路径修正
        backupDestPath=$(echo "${backupDestPath}" | sed -e "s/\/$//g")
        fatherPathNotExist=$(ssh "${backupDestAlias}" "
        if [ ! -d \"${backupDestPath}\" ]; then
            folderCount=\$(awk -F '/' '{print NF}' <<< \"${backupDestPath}\");
            needDetectPath=\"\";
            needDetectPathList=();
            for ((i=2;i<=folderCount;i++)); do
                pathElement=\$(awk -F '/' -v i=\"\$i\" '{print \$i}' <<< \"${backupDestPath}\");
                needDetectPath=\"\${needDetectPath}/\${pathElement}\";
                mapfile -t -O \"\${#needDetectPathList[@]}\" needDetectPathList < <(echo \"\${needDetectPath}\");
            done;
            for i in \"\${needDetectPathList[@]}\";do
                if [ ! -d \"\$i\" ]; then
                    echo \"\$i\";
                    break;
                fi;
            done;
        fi")
        if [ -n "${fatherPathNotExist}" ]; then
            _warning "目的备份节点路径不存在，正在创建路径: ${backupDestPath}"
            ssh "${backupDestAlias}" "
                mkdir -p \"${backupDestPath}\""
            createdTempBackupDestFolder="${fatherPathNotExist}"
        fi
        _info "修正后的目的备份节点路径: ${backupDestPath}"
    fi
    _success "节点路径检查和处理完毕"
}

SearchCondition(){
    export LANG=en_US.UTF-8
    local oldestDate
    local todayDate
    oldestDate=$(date -d -"${allowDays}"days +%Y年%m月%d日)
    todayDate=$(date +%Y年%m月%d日)
    if [ -n "${syncSourcePath}" ] && [ -n "${syncDestPath}" ] && [ -n "${syncSourceAlias}" ] && [ -n "${syncDestAlias}" ] && [ -n "${syncGroupInfo}" ] && [ -n "${syncType}" ] && [ -n "${syncDateType}" ] && [ -n "${allowDays}" ]; then
        if [ "${syncType}" = "dir" ]; then
            _info "已指定同步文件夹，开始在[${oldestDate} - ${todayDate}]的时间段内检索包含最新指定格式日期的文件夹"
            SyncLocateFolders
        elif [ "${syncType}" = "file" ]; then
            _info "已指定同步文件，开始在[${oldestDate} - ${todayDate}]的时间段内检索包含最新指定格式日期的文件"
            SyncLocateFiles
        fi
    fi
    
    if [ -n "${backupSourcePath}" ] && [ -n "${backupDestPath}" ] && [ -n "${backupSourceAlias}" ] && [ -n "${backupDestAlias}" ] && [ -n "${backupGroupInfo}" ] && [ -n "${backupType}" ] && [ -n "${backupDateType}" ] && [ -n "${allowDays}" ]; then
        if [ "${backupType}" = "dir" ]; then
            _info "已指定备份文件夹，开始在[${oldestDate} - ${todayDate}]的时间段内检索包含最新指定格式日期的文件夹"
            BackupLocateFolders
        elif [ "${backupType}" = "file" ]; then
            _info "已指定备份文件，开始在[${oldestDate} - ${todayDate}]的时间段内检索包含最新指定格式日期的文件"
            BackupLocateFiles
        fi
    fi

    if [ "${confirmContinue}" -eq 1 ]; then
        OperationCondition
    else
        _info "如确认汇总的检测信息无误，请重新运行命令并添加选项 -y 或 --yes 以实现检测完成后自动执行工作"
        if [[ -n "${createdTempSyncSourceFolder}" ]]; then
            _info "正在删除临时创建的源同步节点文件夹"
            if ssh "${syncSourceAlias}" "rm -rf \"${createdTempSyncSourceFolder}\""; then
                _success "已删除"
            else
                _error "删除失败，请手动检查"
                exit 1
            fi
        fi
        if [[ -n "${createdTempSyncDestFolder}" ]]; then
            _info "正在删除临时创建的目的同步节点文件夹"
            if ssh "${syncDestAlias}" "rm -rf \"${createdTempSyncDestFolder}\""; then
                _success "已删除"
            else
                _error "删除失败，请手动检查"
                exit 1
            fi
        fi
        if [[ -n "${createdTempBackupDestFolder}" ]]; then
            _info "正在删除临时创建的目的备份节点文件夹"
            if ssh "${backupDestAlias}" "rm -rf \"${createdTempBackupDestFolder}\""; then
                _success "已删除"
            else
                _error "删除失败，请手动检查"
                exit 1
            fi
        fi
        exit 0
    fi
}

OperationCondition(){
    if [ -n "${syncSourcePath}" ] && [ -n "${syncDestPath}" ] && [ -n "${syncSourceAlias}" ] && [ -n "${syncDestAlias}" ] && [ -n "${syncGroupInfo}" ] && [ -n "${syncType}" ] && [ -n "${syncDateType}" ] && [ -n "${allowDays}" ]; then
        _info "开始执行同步操作"
        if SyncOperation; then
            _success "同步完成"
        else
            _error "同步异常，请检查问题来源"
            exit 1
        fi
    fi
    
    if [ -n "${backupSourcePath}" ] && [ -n "${backupDestPath}" ] && [ -n "${backupSourceAlias}" ] && [ -n "${backupDestAlias}" ] && [ -n "${backupGroupInfo}" ] && [ -n "${backupType}" ] && [ -n "${backupDateType}" ] && [ -n "${allowDays}" ]; then
        _info "开始执行备份操作"
        if BackupOperation; then
            _success "备份完成"
        else
            _error "备份异常，请检查问题来源"
            exit 1
        fi
    fi
}

SyncLocateFolders(){
    local markSyncSourceFindPath
    local markSyncDestFindPath
    markSyncSourceFindPath=0
    markSyncDestFindPath=0
    JUMP=0
    for((LOOP=0;LOOP<"${allowDays}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        yearValue=$(date -d -"${LOOP}"days +%Y)
        monthValue=$(date -d -"${LOOP}"days +%m)
        dayValue=$(date -d -"${LOOP}"days +%d)
        syncDate=$(echo "${syncDateTypeConverted}"|sed -e "s/YYYY/${yearValue}/g; s/MMMM/${monthValue}/g; s/DDDD/${dayValue}/g")
        local syncSourceFindFolderName1
        local syncDestFindFolderName1
        mapfile -t syncSourceFindFolderName1 < <(ssh "${syncSourceAlias}" "cd \"${syncSourcePath}\";find . -maxdepth 1 -type d -name \"*${syncDate}*\"|grep -v \"\.$\"|sed 's/^\.\///g'")
        mapfile -t syncDestFindFolderName1 < <(ssh "${syncDestAlias}" "cd \"${syncDestPath}\";find . -maxdepth 1 -type d -name \"*${syncDate}*\"|grep -v \"\.$\"|sed 's/^\.\///g'")

        local syncSourceFindPath
        syncSourceFindPath=()
        for i in "${syncSourceFindFolderName1[@]}"; do
            mapfile -t -O "${#syncSourceFindPath[@]}" syncSourceFindPath < <(ssh "${syncSourceAlias}" "cd \"${syncSourcePath}\";find . -type d|grep \"\./$i\"|sed 's/^\.\///g'")
        done

        local syncDestFindPath
        syncDestFindPath=()
        for i in "${syncDestFindFolderName1[@]}"; do
            mapfile -t -O "${#syncDestFindPath[@]}" syncDestFindPath < <(ssh "${syncDestAlias}" "cd \"${syncDestPath}\";find . -type d|grep \"\./$i\"|sed 's/^\.\///g'")
        done

        local syncSourceFindFile
        syncSourceFindFile=()
        for i in "${syncSourceFindFolderName1[@]}"; do
            mapfile -t -O "${#syncSourceFindFile[@]}" syncSourceFindFile < <(ssh "${syncSourceAlias}" "cd \"${syncSourcePath}\";find . -type f|grep \"\./$i\"|sed 's/^\.\///g'")
        done

        local syncDestFindFile
        syncDestFindFile=()
        for i in "${syncDestFindFolderName1[@]}"; do
            mapfile -t -O "${#syncDestFindFile[@]}" syncDestFindFile < <(ssh "${syncDestAlias}" "cd \"${syncDestPath}\";find . -type f|grep \"\./$i\"|sed 's/^\.\///g'")
        done
        
        [ "${#syncSourceFindPath[@]}" -gt 0 ] && markSyncSourceFindPath=1 && JUMP=1
        [ "${#syncDestFindPath[@]}" -gt 0 ] && markSyncDestFindPath=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
    done

    if [ "${markSyncSourceFindPath}" -eq 1 ] && [ "${markSyncDestFindPath}" -eq 0 ]; then
        _warning "目的同步节点${syncDestAlias}不存在指定日期格式${syncDateType}的文件夹"
        ErrorWarningSyncLog
        echo "目的同步节点${syncDestAlias}不存在指定日期格式${syncDateType}的文件夹" >> "${execErrorWarningSyncLogFile}"
    elif [ "${markSyncSourceFindPath}" -eq 0 ] && [ "${markSyncDestFindPath}" -eq 1 ]; then
        _warning "源同步节点${syncSourceAlias}不存在指定日期格式${syncDateType}的文件夹"
        ErrorWarningSyncLog
        echo "源同步节点${syncSourceAlias}不存在指定日期格式${syncDateType}的文件夹" >> "${execErrorWarningSyncLogFile}"
    elif [ "${markSyncSourceFindPath}" -eq 1 ] && [ "${markSyncDestFindPath}" -eq 1 ]; then
        _success "源与目的同步节点均找到指定日期格式${syncDateType}的文件夹"
    elif [ "${markSyncSourceFindPath}" -eq 0 ] && [ "${markSyncDestFindPath}" -eq 0 ]; then
        _error "源与目的同步节点均不存在指定日期格式${syncDateType}的文件夹，退出中"
        ErrorWarningSyncLog
        echo "源与目的同步节点均不存在指定日期格式${syncDateType}的文件夹，退出中" >> "${execErrorWarningSyncLogFile}"
        exit 1
    fi

    # 锁定目的节点需创建的文件夹的相对路径并转换成绝对路径存进数组
    locateDestNeedFolder=()
    for i in "${syncSourceFindPath[@]}"; do
        MARK=0
        for j in "${syncDestFindPath[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#locateDestNeedFolder[@]}" locateDestNeedFolder < <(echo "\"${syncDestPath}/$i\"")
        fi
    done
    
    # 锁定源节点需创建的文件夹的相对路径并转换成绝对路径存进数组
    locateSourceNeedFolder=()
    for i in "${syncDestFindPath[@]}"; do
        MARK=0
        for j in "${syncSourceFindPath[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#locateSourceNeedFolder[@]}" locateSourceNeedFolder < <(echo "\"${syncSourcePath}/$i\"")
        fi
    done
    
    # 锁定始到末需传送的文件的绝对路径
    conflictFile=()
    for i in "${syncSourceFindFile[@]}"; do
        MARK=0
        for j in "${syncDestFindFile[@]}"; do
            if [ "$i" = "$j" ]; then
                if [[ ! $(ssh "${syncSourceAlias}" "sha256sum \"${syncSourcePath}/$i\"|awk '{print \$1}'") = $(ssh "${syncDestAlias}" "sha256sum \"${syncDestPath}/$j\"|awk '{print \$1}'") ]]; then
                    _warning "源节点: \"${syncSourcePath}/$i\"，目的节点:\"${syncDestPath}/$j\" 文件校验值不同，请检查日志，同步时将跳过此文件"
                    conflictFile+=("源节点: \"${syncSourcePath}/$i\"，目的节点: \"${syncDestPath}/$j\"")
                else
                    _success "源节点: \"${syncSourcePath}/$i\"，目的节点: \"${syncDestPath}/$j\" 文件校验值一致"
                fi
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            locateSourceOutgoingFile+=("\"${syncSourcePath}/$i\"")
            locateDestIncomingFile+=("\"${syncDestPath}/$i\"")
        fi
    done
    
    # 将同名不同内容的冲突文件列表写入日志
    ErrorWarningSyncLog
    echo "始末节点中的同名文件存在冲突，请检查" >> "${execErrorWarningSyncLogFile}"
    for i in "${conflictFile[@]}"; do
        echo "$i" >> "${execErrorWarningSyncLogFile}"
    done

    # 锁定末到始需传送的文件的绝对路径
    for i in "${syncDestFindFile[@]}"; do
        MARK=0
        for j in "${syncSourceFindFile[@]}"; do
            if [ "$i" = "$j" ]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            locateDestOutgoingFile+=("\"${syncDestPath}/$i\"")
            locateSourceIncomingFile+=("\"${syncSourcePath}/$i\"")
        fi
    done
    
    # 信息汇总
    _success "已锁定需传送信息，以下将显示各类已锁定信息，请检查"
    _warning "源节点 —— 待创建文件夹绝对路径列表:"
    for i in "${locateSourceNeedFolder[@]}"; do
        echo "$i"
    done
    echo ""
    _warning "目的节点 —— 待创建文件夹绝对路径列表:"
    for i in "${locateDestNeedFolder[@]}"; do
        echo "$i"
    done
    echo ""
    _warning "传输方向: 源节点 -> 目的节点 —— 源节点待传出-目的节点待传入文件绝对路径列表:"
    for i in "${!locateSourceOutgoingFile[@]}"; do
        echo "${locateSourceOutgoingFile[$i]} -> ${locateDestIncomingFile[$i]}"
    done
    echo ""
    _warning "传输方向: 目的节点 -> 源节点 —— 目的节点待传出-源节点待传入文件绝对路径列表:"
    for i in "${!locateDestOutgoingFile[@]}"; do
        echo "${locateDestOutgoingFile[$i]} -> ${locateSourceIncomingFile[$i]}"
    done
    echo ""
    _warning "基于指定路径的始末节点存在冲突的文件绝对路径列表:"
    for i in "${conflictFile[@]}"; do
        echo "$i"
    done
    echo ""
}

SyncLocateFiles(){
    local markSyncSourceFindFile1
    local markSyncDestFindFile1
    markSyncSourceFindFile1=0
    markSyncDestFindFile1=0

    # 以下用printf会比find更快，但一万个文件只有 7ms 差距暂时不改了
    # time echo x|printf '%s\n' /root/108/ttt/*20221120*
    _info "开始检索源节点并计算每个文件的校验值"
    local syncSourceFindFile1
    mapfile -t syncSourceFindFile1 < <(ssh "${syncSourceAlias}" "for ((LOOP=0;LOOP<\"${allowDays}\";LOOP++));do
        yearValue=\$(date -d -\"\${LOOP}\"days +%Y);
        monthValue=\$(date -d -\"\${LOOP}\"days +%m);
        dayValue=\$(date -d -\"\${LOOP}\"days +%d);
        syncDate=\$(echo \"${syncDateTypeConverted}\"|sed -e \"s/YYYY/\${yearValue}/g; s/MMMM/\${monthValue}/g; s/DDDD/\${dayValue}/g\");
        mapfile -t syncSourceFindFile1 < <(find \"${syncSourcePath}\" -maxdepth 1 -type f -name \"*\${syncDate}*\"|awk -F '/' '{print \$NF}');
        if [ \"\${#syncSourceFindFile1[@]}\" -gt 0 ]; then
            for i in \"\${syncSourceFindFile1[@]}\";do
                shaValue=\$(sha256sum \"${syncSourcePath}/\$i\"|awk '{print \$1}');
                echo \"\${i}_-_\${shaValue}\";
            done;
        fi;
    done")
    _success "源节点检索并计算完成"

    _info "开始检索目的节点并计算每个文件的校验值"
    local syncDestFindFile1
    mapfile -t syncDestFindFile1 < <(ssh "${syncDestAlias}" "for ((LOOP=0;LOOP<\"${allowDays}\";LOOP++));do
        yearValue=\$(date -d -\"\${LOOP}\"days +%Y);
        monthValue=\$(date -d -\"\${LOOP}\"days +%m);
        dayValue=\$(date -d -\"\${LOOP}\"days +%d);
        syncDate=\$(echo \"${syncDateTypeConverted}\"|sed -e \"s/YYYY/\${yearValue}/g; s/MMMM/\${monthValue}/g; s/DDDD/\${dayValue}/g\");
        mapfile -t syncDestFindFile1 < <(find \"${syncDestPath}\" -maxdepth 1 -type f -name \"*\${syncDate}*\"|awk -F '/' '{print \$NF}');
        if [ \"\${#syncDestFindFile1[@]}\" -gt 0 ]; then
            for i in \"\${syncDestFindFile1[@]}\";do
                shaValue=\$(sha256sum \"${syncDestPath}/\$i\"|awk '{print \$1}');
                echo \"\${i}_-_\${shaValue}\";
            done;
        fi;
    done")
    _success "目的节点检索并计算完成"
#    echo "================================="
#    echo "源路径文件"
#    for i in "${syncSourceFindFile1[@]}"; do
#        echo "$i"
#    done
#    echo "================================="
#    echo "目的路径文件"
#    for i in "${syncDestFindFile1[@]}"; do
#        echo "$i"
#    done
#    echo "================================="

    [ "${#syncSourceFindFile1[@]}" -gt 0 ] && markSyncSourceFindFile1=1
    [ "${#syncDestFindFile1[@]}" -gt 0 ] && markSyncDestFindFile1=1
    if [ "${markSyncSourceFindFile1}" -eq 1 ] && [ "${markSyncDestFindFile1}" -eq 0 ]; then
        _warning "目的同步节点${syncDestAlias}不存在指定日期格式${syncDate}的文件"
        ErrorWarningSyncLog
        echo "目的同步节点${syncDestAlias}不存在指定日期格式${syncDate}的文件" >> "${execErrorWarningSyncLogFile}"
    elif [ "${markSyncSourceFindFile1}" -eq 0 ] && [ "${markSyncDestFindFile1}" -eq 1 ]; then
        _warning "源同步节点${syncSourceAlias}不存在指定日期格式${syncDate}的文件"
        ErrorWarningSyncLog
        echo "源同步节点${syncSourceAlias}不存在指定日期格式${syncDate}的文件" >> "${execErrorWarningSyncLogFile}"
    elif [ "${markSyncSourceFindFile1}" -eq 1 ] && [ "${markSyncDestFindFile1}" -eq 1 ]; then
        _success "源与目的同步节点均找到指定日期格式${syncDate}的文件"
    elif [ "${markSyncSourceFindFile1}" -eq 0 ] && [ "${markSyncDestFindFile1}" -eq 0 ]; then
        _error "源与目的同步节点均不存在指定日期格式${syncDate}的文件，退出中"
        ErrorWarningSyncLog
        echo "源与目的同步节点均不存在指定日期格式${syncDate}的文件，退出中" >> "${execErrorWarningSyncLogFile}"
        exit 1
    fi

    # 锁定始到末需传送的文件的绝对路径
    _info "开始比对索引中源与目的节点每个文件的校验值"
    conflictFile=()
    local fileNameI
    local shaValueI
    local fileNameJ
    local shaValueJ
    for i in "${syncSourceFindFile1[@]}"; do
        MARK=0
        fileNameI=$(awk -F '_-_' '{print $1}' <<< "$i")
        shaValueI=$(awk -F '_-_' '{print $2}' <<< "$i")
        for j in "${syncDestFindFile1[@]}"; do
            fileNameJ=$(awk -F '_-_' '{print $1}' <<< "$j")
            shaValueJ=$(awk -F '_-_' '{print $2}' <<< "$j")
            if [[ "${fileNameI}" == "${fileNameJ}" ]]; then
                if [[ ! "${shaValueI}" = "${shaValueJ}" ]]; then
                    _warning "源节点${syncSourceAlias}: \"${syncSourcePath}/${fileNameI}\"，目的节点${syncDestAlias}:\"${syncDestPath}/${fileNameJ}\" 文件校验值不同，请检查日志，同步时将跳过此文件"
                    conflictFile+=("源节点: \"${syncSourcePath}/${fileNameI}\"，目的节点: \"${syncDestPath}/${fileNameJ}\"")
                else
                    _success "源节点: \"${syncSourcePath}/${fileNameI}\"，目的节点: \"${syncDestPath}/${fileNameJ}\" 文件校验值一致"
                fi
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#locateSourceOutgoingFile[@]}" locateSourceOutgoingFile < <(echo "\"${syncSourcePath}/${fileNameI}\"")
            mapfile -t -O "${#locateDestIncomingFile[@]}" locateDestIncomingFile < <(echo "\"${syncDestPath}/${fileNameI}\"")
        fi
    done
#    echo "================================="
#    echo "源路径发出文件"
#    for i in "${locateSourceOutgoingFile[@]}"; do
#        echo "$i"
#    done
#    echo "================================="
#    echo "================================="
#    echo "目的路径传入文件"
#    for i in "${locateDestIncomingFile[@]}"; do
#        echo "$i"
#    done
#    echo "================================="
    
    # 将同名不同内容的冲突文件列表写入日志
    if [[ "${#conflictFile[@]}" -gt 0 ]]; then
        _warning "检测到存在冲突文件，开始写入日志"
        ErrorWarningSyncLog
        echo "始末节点中的同名文件存在冲突，请检查" >> "${execErrorWarningSyncLogFile}"
        for i in "${conflictFile[@]}"; do
            echo "$i" >> "${execErrorWarningSyncLogFile}"
        done
        _success "冲突文件记录完成"
    fi
    _success "文件检索完成，已定位从源节点到目的节点待同步的文件"

    # 锁定末到始需传送的文件的绝对路径
    _info "开始比对索引中目的与源节点每个文件的校验值"
    for i in "${syncDestFindFile1[@]}"; do
        MARK=0
        fileNameI=$(awk -F '_-_' '{print $1}' <<< "$i")
        for j in "${syncSourceFindFile1[@]}"; do
            fileNameJ=$(awk -F '_-_' '{print $1}' <<< "$j")
            if [[ "${fileNameI}" == "${fileNameJ}" ]]; then
                MARK=1
                break
            fi
        done
        if [ "${MARK}" -eq 0 ]; then
            mapfile -t -O "${#locateDestOutgoingFile[@]}" locateDestOutgoingFile < <(echo "\"${syncDestPath}/${fileNameI}\"")
            mapfile -t -O "${#locateSourceIncomingFile[@]}" locateSourceIncomingFile < <(echo "\"${syncSourcePath}/${fileNameI}\"")
        fi
    done
    _success "文件检索完成，已定位从目的节点到源节点待同步的文件"
    echo ""

    # 信息汇总
    _success "已锁定需传送信息，以下将显示各类已锁定信息，请检查"
    _warning "传输方向: 源节点 -> 目的节点 —— 源节点待传出-目的节点待传入文件绝对路径列表:"
    for i in "${!locateSourceOutgoingFile[@]}"; do
        echo "${locateSourceOutgoingFile[$i]} -> ${locateDestIncomingFile[$i]}"
    done
    echo ""
    _warning "传输方向: 目的节点 -> 源节点 —— 目的节点待传出-源节点待传入文件绝对路径列表:"
    for i in "${!locateDestOutgoingFile[@]}"; do
        echo "${locateDestOutgoingFile[$i]} -> ${locateSourceIncomingFile[$i]}"
    done
    echo ""
    _warning "基于指定路径的始末节点存在冲突的文件绝对路径列表:"
    for i in "${conflictFile[@]}"; do
        echo "$i"
    done
    echo ""
}

BackupLocateFolders(){
    local markBackupSourceFindFolderFullPath
    markBackupSourceFindFolderFullPath=0
    JUMP=0
    for((LOOP=0;LOOP<"${allowDays}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        yearValue=$(date -d -"${LOOP}"days +%Y)
        monthValue=$(date -d -"${LOOP}"days +%m)
        dayValue=$(date -d -"${LOOP}"days +%d)
        backupDate=$(echo "${backupDateTypeConverted}"|sed -e "s/YYYY/${yearValue}/g; s/MMMM/${monthValue}/g; s/DDDD/${dayValue}/g")
        mapfile -t backupSourceFindFolderFullPath < <(ssh "${backupSourceAlias}" "find \"${backupSourcePath}\" -maxdepth 1 -type d -name \"*${backupDate}*\"|grep -v \"\.$\"")
        
        [ "${#backupSourceFindFolderFullPath[@]}" -gt 0 ] && markBackupSourceFindFolderFullPath=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
    done

    if [ "${markBackupSourceFindFolderFullPath}" -eq 1 ]; then
        _success "源备份节点存在指定日期格式${backupDate}的文件夹"
    elif [ "${markBackupSourceFindFolderFullPath}" -eq 0 ]; then
        _error "源备份节点不存在指定日期格式${backupDate}的文件夹，退出中"
        ErrorWarningBackupLog
        echo "源备份节点不存在指定日期格式${backupDate}的文件夹，退出中" >> "${execErrorWarningBackupLogFile}"
        exit 1
    fi
    
    # 信息汇总
    _success "已锁定需传送信息，以下将显示已锁定信息，请检查"
    _warning "源节点待备份文件夹绝对路径列表:"
    for i in "${!backupSourceFindFolderFullPath[@]}"; do
        echo "${backupSourceFindFolderFullPath[$i]}"
    done
    echo ""
}

BackupLocateFiles(){
    local markBackupSourceFindFile1
    markBackupSourceFindFile1=0
    JUMP=0
    for ((LOOP=0;LOOP<"${allowDays}";LOOP++));do
        # 将文件夹允许的格式字符串替换成真实日期
        yearValue=$(date -d -"${LOOP}"days +%Y)
        monthValue=$(date -d -"${LOOP}"days +%m)
        dayValue=$(date -d -"${LOOP}"days +%d)
        backupDate=$(echo "${backupDateTypeConverted}"|sed -e "s/YYYY/${yearValue}/g; s/MMMM/${monthValue}/g; s/DDDD/${dayValue}/g")
        mapfile -t backupSourceFindFile1 < <(ssh "${backupSourceAlias}" "find \"${backupSourcePath}\" -maxdepth 1 -type f -name \"*${backupDate}*\"")

        [ "${#backupSourceFindFile1[@]}" -gt 0 ] && markBackupSourceFindFile1=1 && JUMP=1
        [ "${JUMP}" -eq 1 ] && break
    done
        
    if [ "${markBackupSourceFindFile1}" -eq 1 ]; then
        _success "源备份节点已找到指定日期格式${backupDate}的文件"
    elif [ "${markBackupSourceFindFile1}" -eq 0 ]; then
        _error "源节点不存在指定日期格式${backupDate}的文件，退出中"
        ErrorWarningBackupLog
        echo "源与目的同步节点均不存在指定日期格式${backupDate}的文件，退出中" >> "${execErrorWarningBackupLogFile}"
        exit 1
    fi

    # 信息汇总
    _success "已锁定需传送信息，以下将显示已锁定信息，请检查"
    _warning "源节点待备份文件绝对路径列表:"
    for i in "${!backupSourceFindFile1[@]}"; do
        echo "${backupSourceFindFile1[$i]}"
    done
    echo ""
}

SyncOperation(){
    if [ "${syncType}" = "dir" ]; then
        # 源节点需创建的文件夹
        if [ "${#locateSourceNeedFolder[@]}" -gt 0 ]; then
            _info "开始创建源同步节点所需文件夹"
            # ssh "${syncSourceAlias}" "for i in \"${locateSourceNeedFolder[@]}\";do echo \"$i\";mkdir -p \"$i\";done"  # 这行可能会调用 conflictFile 数组导致出错
            for i in "${locateSourceNeedFolder[@]}";do
                echo "正在创建文件夹: $i"
                ssh "${syncSourceAlias}" "mkdir -p \"$i\""
            done
            _info "源同步节点所需文件夹已创建成功"
        fi
        
        # 目的节点需创建的文件夹
        if [ "${#locateDestNeedFolder[@]}" -gt 0 ]; then
            _info "开始创建目的同步节点所需文件夹"
            # ssh "${syncDestAlias}" "for i in \"${locateDestNeedFolder[@]}\";do echo \"$i\";mkdir -p \"$i\";done"
            for i in "${locateDestNeedFolder[@]}";do
                echo "正在创建文件夹: $i"
                ssh "${syncDestAlias}" "mkdir -p \"$i\""
            done
            _info "目的同步节点所需文件夹已创建成功"
        fi
        
        # 传输方向: 源节点 -> 目的节点 —— 源节点待传出文件
        if [ "${#locateSourceOutgoingFile[@]}" -gt 0 ]; then
            _info "源节点 -> 目的节点 开始传输"
            sourceToDestFailed=()
            for i in "${!locateSourceOutgoingFile[@]}"; do
                if ! scp -r "${syncSourceAlias}":"${locateSourceOutgoingFile[$i]}" "${syncDestAlias}":"${locateDestIncomingFile[$i]}"; then
                    sourceToDestFailed+=("${locateSourceOutgoingFile[$i]} -> ${locateDestIncomingFile[$i]}")
                fi
            done
            if [ "${#sourceToDestFailed[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 源节点 -> 目的节点 存在部分文件同步失败，请检查" >> "${execErrorWarningSyncLogFile}"
                for i in "${sourceToDestFailed[@]}"; do
                    echo "$i" >> "${execErrorWarningSyncLogFile}"
                done
            fi
        fi
        
        # 传输方向: 目的节点 -> 源节点 —— 目的节点待传出文件
        if [ "${#locateDestOutgoingFile[@]}" -gt 0 ]; then
            _info "目的节点 -> 源节点 开始传输"
            local destToSourceFailed
            destToSourceFailed=()
            for i in "${!locateDestOutgoingFile[@]}"; do
                if ! scp -r "${syncDestAlias}":"${locateDestOutgoingFile[$i]}" "${syncSourceAlias}":"${locateSourceIncomingFile[$i]}"; then
                    destToSourceFailed+=("${locateDestOutgoingFile[$i]} -> ${locateSourceIncomingFile[$i]}")
                fi
            done
            if [ "${#destToSourceFailed[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 目的节点 -> 源节点 存在部分文件同步失败，请检查" >> "${execErrorWarningSyncLogFile}"
                for i in "${destToSourceFailed[@]}"; do
                    echo "$i" >> "${execErrorWarningSyncLogFile}"
                done
            fi
        fi
        
    elif [ "${syncType}" = "file" ]; then
        # 传输方向: 源节点 -> 目的节点 —— 源节点待传出文件
        if [ "${#locateSourceOutgoingFile[@]}" -gt 0 ]; then
            _info "源节点 -> 目的节点 开始传输"
            sourceToDestFailed=()
            for i in "${!locateSourceOutgoingFile[@]}"; do
                if ! scp -r "${syncSourceAlias}":"${locateSourceOutgoingFile[$i]}" "${syncDestAlias}":"${locateDestIncomingFile[$i]}"; then
                    sourceToDestFailed+=("${locateSourceOutgoingFile[$i]} -> ${locateDestIncomingFile[$i]}")
                fi
            done
            if [ "${#sourceToDestFailed[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 源节点 -> 目的节点 存在部分文件同步失败，请检查" >> "${execErrorWarningSyncLogFile}"
                for i in "${sourceToDestFailed[@]}"; do
                    echo "$i" >> "${execErrorWarningSyncLogFile}"
                done
            fi
        fi
        
        # 传输方向: 目的节点 -> 源节点 —— 目的节点待传出文件
        if [ "${#locateDestOutgoingFile[@]}" -gt 0 ]; then
            _info "目的节点 -> 源节点 开始传输"
            destToSourceFailed=()
            for i in "${!locateDestOutgoingFile[@]}"; do
                if ! scp -r "${syncDestAlias}":"${locateDestOutgoingFile[$i]}" "${syncSourceAlias}":"${locateSourceIncomingFile[$i]}"; then
                    destToSourceFailed+=("${locateDestOutgoingFile[$i]} -> ${locateSourceIncomingFile[$i]}")
                fi
            done
            if [ "${#destToSourceFailed[@]}" -gt 0 ]; then
                _warning "部分文件传输失败，请查看报错日志"
                ErrorWarningSyncLog
                echo "传输方向: 目的节点 -> 源节点 存在部分文件同步失败，请检查" >> "${execErrorWarningSyncLogFile}"
                for i in "${destToSourceFailed[@]}"; do
                    echo "$i" >> "${execErrorWarningSyncLogFile}"
                done
            fi
        fi
    fi
}

BackupOperation(){
    if [ "${backupType}" = "dir" ]; then
        _info "源节点文件夹备份开始"
        sourceToDestFailed=()
        for i in "${!backupSourceFindFolderFullPath[@]}"; do
            if ! scp -r "${backupSourceAlias}":"${backupSourceFindFolderFullPath[$i]}" "${backupDestAlias}":"${backupDestPath}"; then
                sourceToDestFailed+=("${backupSourceFindFolderFullPath[$i]} -> ${backupDestPath}")
            fi
        done
        if [ "${#sourceToDestFailed[@]}" -gt 0 ]; then
            _warning "部分文件夹传输失败，请查看报错日志"
            ErrorWarningBackupLog
            echo "源节点部分文件夹备份失败，请检查" >> "${execErrorWarningBackupLogFile}"
            for i in "${sourceToDestFailed[@]}"; do
                echo "$i" >> "${execErrorWarningBackupLogFile}"
            done
        fi
    elif [ "${backupType}" = "file" ]; then
        _info "源节点文件备份开始"
        sourceToDestFailed=()
        for i in "${!backupSourceFindFile1[@]}"; do
            if ! scp -r "${backupSourceAlias}":"${backupSourceFindFile1[$i]}" "${backupDestAlias}":"${backupDestPath}"; then
                sourceToDestFailed+=("${backupSourceFindFile1[$i]} -> ${backupDestPath}")
            fi
        done
        if [ "${#sourceToDestFailed[@]}" -gt 0 ]; then
            _warning "部分文件传输失败，请查看报错日志"
            ErrorWarningBackupLog
            echo "源节点部分文件备份失败，请检查" >> "${execErrorWarningBackupLogFile}"
            for i in "${sourceToDestFailed[@]}"; do
                echo "$i" >> "${execErrorWarningBackupLogFile}"
            done
        fi
    fi
}

ErrorWarningSyncLog(){
    [ ! -d /var/log/${shName}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${shName}/{exec,log}
    cat >> /var/log/${shName}/log/exec-error-warning-sync-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

ErrorWarningBackupLog(){
    [ ! -d /var/log/${shName}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${shName}/{exec,log}
    cat >> /var/log/${shName}/log/exec-error-warning-backup-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

CommonLog(){
    [ ! -d /var/log/${shName}/log ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${shName}/{exec,log}
    cat >> /var/log/${shName}/log/exec-"$(date +"%Y-%m-%d")".log <<EOF

------------------------------------------------
时间：$(date +"%H:%M:%S")
执行情况：
EOF
}

DeleteExpiredLog(){
    _info "开始清理陈旧日志文件"
    local logFile
    logFile=$(find /var/log/${shName}/log -name "exec*.log" -mtime +10)
    for a in $logFile
    do
        rm -f "${a}"
    done
    _success "日志清理完成"
}

Deploy(){
    _info "开始部署..."
    ssh "${deployNodeAlias}" "mkdir -p /var/log/${shName}/{exec,log}"
    scp "$(pwd)"/"${shName}".sh "${deployNodeAlias}":/var/log/${shName}/exec/${shName}
    ssh "${deployNodeAlias}" "chmod +x /var/log/${shName}/exec/${shName}"
    ssh "${deployNodeAlias}" "sed -i \"/${shName}/d\" /etc/bashrc"
    ssh "${deployNodeAlias}" "echo \"alias msb='/usr/bin/bash <(cat /var/log/${shName}/exec/${shName})'\" >> /etc/bashrc"
    ssh "${deployNodeAlias}" "sed -i \"/${shName})\ -e/d\" /etc/crontab"
    ssh "${deployNodeAlias}" "echo \"${logCron} root /usr/bin/bash -c 'bash <(cat /var/log/${shName}/exec/${shName}) -e'\" >> /etc/crontab"

    # 集合定时任务，里面将存放各种同步或备份的执行功能(if判断如果写在ssh命令会出现判断功能失效的毛病)
    ssh "${deployNodeAlias}" "[ ! -f /var/log/${shName}/exec/run-\"${operationCronName}\" ] && echo \"#!/bin/bash\" >/var/log/${shName}/exec/run-\"${operationCronName}\" && chmod +x /var/log/${shName}/exec/run-\"${operationCronName}\""
    if [ "$(ssh "${deployNodeAlias}" "grep -c \"${operationCronName}\" /etc/crontab")" -eq 0 ]; then
        ssh "${deployNodeAlias}" "echo \"${operationCron} root /usr/bin/bash -c 'bash <(cat /var/log/${shName}/exec/run-${operationCronName})'\" >> /etc/crontab"
    fi
    # 向集合定时任务添加具体执行功能
    if [ -n "${syncOperationName}" ]; then
        ssh "${deployNodeAlias}" "echo \"bash <(cat /var/log/${shName}/exec/${shName}) --days \"\"${allowDays}\"\" --sync_source_path \"\"${syncSourcePath}\"\" --sync_dest_path \"\"${syncDestPath}\"\" --sync_source_alias \"\"${syncSourceAlias}\"\" --sync_dest_alias \"\"${syncDestAlias}\"\" --sync_group \"\"${syncGroupInfo}\"\" --sync_type \"\"${syncType}\"\" --sync_date_type \"\"${syncDateType}\"\" --sync_operation_name \"\"${syncOperationName}\"\" -y\" >> /var/log/${shName}/exec/run-\"${operationCronName}\""
    fi
    if [ -n "${backupOperationName}" ]; then
        ssh "${deployNodeAlias}" "echo \"bash <(cat /var/log/${shName}/exec/${shName}) --days \"\"${allowDays}\"\" --backup_source_path \"\"${backupSourcePath}\"\" --backup_dest_path \"\"${backupDestPath}\"\" --backup_source_alias \"\"${backupSourceAlias}\"\" --backup_dest_alias \"\"${backupDestAlias}\"\" --backup_group \"\"${backupGroupInfo}\"\" --backup_type \"\"${backupType}\"\" --backup_date_type \"\"${backupDateType}\"\" --backup_operation_name \"\"${backupOperationName}\"\" -y\" >> /var/log/${shName}/exec/run-\"${operationCronName}\""
    fi
    _success "部署成功"
}

Remove(){
    if [ "${removeOperationFile}" = "all" ]; then
        _info "开始卸载工具本身和生成的日志，不会对同步或备份文件产生任何影响"
        ssh "${removeNodeAlias}" "rm -rf /var/log/${shName}"
        ssh "${removeNodeAlias}" "sed -i \"/${shName}/d\" /etc/bashrc"
        ssh "${removeNodeAlias}" "sed -i \"/${shName}/d\" /etc/crontab"
    else
        _info "开始卸载指定的方案组，不会对其他方案组、同步或备份文件产生任何影响"
        ssh "${removeNodeAlias}" "rm -rf /var/log/${shName}/exec/run-${removeOperationFile}"
        ssh "${removeNodeAlias}" "sed -i \"/${removeOperationFile}/d\" /etc/crontab"
    fi
    _success "卸载成功"
}

Clean(){
    if [ -d "/var/log/${shName}" ]; then
        _warning "发现脚本运行残留，正在清理"
        rm -rf /var/log/${shName}
        _success "清理完成"
    else
        _success "未发现脚本运行残留"
    fi
}

Help(){
    _successNoBlank "
    本脚本依赖SCP传输
    所有内置选项及传参格式如下，有参选项必须加具体参数，否则脚本会自动检测并阻断运行:"| column -t

    _warningNoBlank "
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
    
    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -s | --check_dep_sep 只检测并打印脚本运行必备依赖情况的详细信息并退出
    -e | --delete_expired_log 即时删除超期历史日志文件并退出
    -c | --clean 清理脚本在本地测试运行或部署功能时的残留(不含指定错误路径导致的文件夹被新建情况)
    -y | --yes 确认执行所有检测结果后的实际操作
    -h | --help 打印此帮助信息并退出" | column -t
    echo ""
    echo "----------------------------------------------------------------"
    _warningNoBlank "以下为根据脚本内置5种可重复功能归类各自选项(存在选项复用情况)"
    echo ""
    _successNoBlank "|------------|"
    _successNoBlank "|部署同步功能|"
    _successNoBlank "|------------|"
    _warningNoBlank "
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

    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""


    _successNoBlank "|------------|"
    _successNoBlank "|部署备份功能|"
    _successNoBlank "|------------|"
    _warningNoBlank "
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

    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successNoBlank "|------------|"
    _successNoBlank "|执行同步功能|"
    _successNoBlank "|------------|"
    _warningNoBlank "
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

    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successNoBlank "|------------|"
    _successNoBlank "|执行备份功能|"
    _successNoBlank "|------------|"
    _warningNoBlank "
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

    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""

    _successNoBlank "|--------------------|"
    _successNoBlank "|卸载方案组或全部功能|"
    _successNoBlank "|--------------------|"
    _warningNoBlank "
    以下为有参选项，必须带上相应参数"| column -t
    echo "
    -R | --remove 指定卸载脚本的节点别名
    -r | --remove_group_info 指定卸载脚本的节点所属免密节点组名
    -F | --remove_operation_file 指定卸载脚本的节点中的方案组名(all代表全部卸载)" | column -t

    _warningNoBlank "
    以下为无参选项:"| column -t
    echo "
    -y | --yes 确认执行所有检测结果后的实际操作" | column -t
    echo ""
}

Main(){
    EnvCheck
    # 卸载检测和执行
    CheckRemoveOption  # 这里有一个检测退出和确认执行完成后退出的功能，只要进入此模块后成功进入卸载分支，无论卸载成功与否都会退出
    CheckExecOption
    CheckDeployOption  # 这里有一个检测退出和确认执行完成后退出的功能，只要进入此模块后成功进入部署分支，无论部署成功与否都会退出
    CheckTransmissionStatus
    SearchCondition
}

# 只执行完就直接退出
[ "${needHelp}" -eq 1 ] && Help && exit 0
[ "${deleteExpiredLog}" -eq 1 ] && DeleteExpiredLog && exit 0
[ "${needClean}" -eq 1 ] && Clean && exit 0

[ ! -d /var/log/${shName} ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${shName}/{exec,log}
Main | tee -a "${execCommonLogFile}"
