#!/bin/bash
# 注意：
# 此脚本中定时的情况是魔法值，在第 174、187、188 行上下，可能后续更新有改动行数，但应该变动不大
# 187 行的默认转移功能是每天晚上 11:30 执行一次
# 188 行是每10天删除一次脚本本身的陈旧日志文件，按需调整再部署，定时怎么写请自行上网查
# 174 行是每次只删除生成超过10天的日志文件，因为一天一次所有体积相当小，默认10天一次够用，服务器硬盘空间紧张的可调整
# 默认设置只对于按照特定格式筛选出来的文件夹进行传输，有需求自己修改下文件夹名的形式：xxxFULL_年_月_日_xxx 或 xxxINCREMENT_年_月_日_xxx

# 全局颜色
_norm=$(tput sgr0)
_red=$(tput setaf 1)
_green=$(tput setaf 2)
_tan=$(tput setaf 3)
_cyan=$(tput setaf 6)

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

# 变量名
SH_NAME="dmbackup"
BACKUP_CRON="30 23 * * *"
LOG_CRON="* * */10 * *"
SOURCE_PATH=
DEST_PATH=
REMOTE_USER=
REMOTE_ADDRESS=
DEPLOY=0
REMOVE=0
TIMEOUT=
HELP=0
FULL_DIR_NAME=
INCREMENT_DIR_NAME=
RELATIME_LOG_NAME=
RMLOG=0
EXEC_LOGFILE=/var/log/${SH_NAME}/exec-"$(date +"%Y-%m-%d")".log
CHECK_DEP_SEP=0

# 功能模块
CheckOption(){
    _info "检查脚本使用的有关软件安装情况"
    appList="timeout tput scp sftp pwd basename sort tail tee"
    for i in ${appList}; do
        if which "$i" >/dev/null 2>&1; then
            _success "$i 已安装"
        else
            _error "$i 未安装"
        fi
    done
    [ "${HELP}" -eq 1 ] && Help && exit 0
    _info "开始检查传递的选项和参数"
    case ${PLAN_NAME} in
        "dm")
            PLAN_NAME="dm-backup";
            ;;
        "bmj")
            PLAN_NAME="bmj-backup";
            ;;
        *)
            _error "必须指定功能名称以实现不同功能效果，可选项: dm/bmj"
            exit 110
    esac
    if [ "${REMOVE}" -eq 0 ]; then
        if [ "${RMLOG}" -eq 0 ]; then
            [ ! -d "${SOURCE_PATH}" ] && _error "设置的源路径本身不存在，请检查" && exit 111
            [ -z "${DEST_PATH}" ] && _error "未设置目标路径，请检查" && exit 112
            [[ ! "${DEST_PATH}" =~ ^/ ]] && _error "设置的目标路径必须为绝对路径，请检查" && exit 113
            [ -z "${REMOTE_USER}" ] && _error "未设置远程节点登录用户名，请检查" && exit 114
            [ -z "${REMOTE_ADDRESS}" ] && _error "未设置目标 IP 地址或域名，请检查" && exit 115
            [ -z "${TIMEOUT}" ] && _error "未设置超时时间，请检查" && exit 116
            if ! timeout 5s ping -c2 -W1 "${REMOTE_ADDRESS}" > /dev/null 2>&1; then
                _error "此 IP 地址或域名无法 ping 通，请检查"
                exit 117
            fi
        fi
    fi
}

LocateFile(){
    _info "正在设置语言环境..."
    export LANG=en_US.UTF-8

    SOURCE_PATH=$(echo "${SOURCE_PATH}" | sed 's/\/$//')
    _info "修正源路径: ${SOURCE_PATH}"
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

CheckRemoteDir(){
    ssh "${REMOTE_USER}"@"${REMOTE_ADDRESS}" "[ ! -d ${DEST_PATH} ] && echo \"目标路径不存在，将创建路径: ${DEST_PATH}\" && mkdir -p ${DEST_PATH}"
    _info "自修复变量 DEST_PATH = ${DEST_PATH}"
}

CloneOperation(){
    LogInfo
    _info "开始传输..."
    if [ -n "${FULL_DIR_NAME}" ]; then
        _info "开始传输全量备份文件夹"
        _info "FULL_DIR_NAME=${FULL_DIR_NAME}"
        if ! timeout "${TIMEOUT}" scp -r "${SOURCE_PATH}"/"${FULL_DIR_NAME}" "${REMOTE_USER}"@"${REMOTE_ADDRESS}":"${DEST_PATH}" 2>&1; then
            _error "连接断开，请手动检查未完成的残留全量备份文件夹"
        fi
    fi
    if [ -n "${INCREMENT_DIR_NAME}" ]; then
        _info "开始传输增量备份文件夹"
        _info "INCREMENT_DIR_NAME=${INCREMENT_DIR_NAME}"
        if ! timeout "${TIMEOUT}" scp -r "${SOURCE_PATH}"/"${INCREMENT_DIR_NAME}" "${REMOTE_USER}"@"${REMOTE_ADDRESS}":"${DEST_PATH}" 2>&1; then
            _error "连接断开，请手动检查未完成的残留增量备份文件夹"
        fi
    fi
    if [ -n "${RELATIME_LOG_NAME}" ]; then
        _info "开始传输数据库日志文件"
        _info "RELATIME_LOG_NAME=${RELATIME_LOG_NAME}"
        if ! timeout "${TIMEOUT}" scp "${SOURCE_PATH}"/"${RELATIME_LOG_NAME}" "${REMOTE_USER}"@"${REMOTE_ADDRESS}":"${DEST_PATH}" 2>&1; then
            _error "连接断开，请手动检查未完成的残留日志文件"
        fi
    fi
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
    echo "${BACKUP_CRON} root /usr/bin/bash -c 'bash <(cat /${SH_NAME}) -P ${SOURCE_PATH} -p ${DEST_PATH} -u ${REMOTE_USER} -d ${REMOTE_ADDRESS} -t ${TIMEOUT}'" >> /etc/crontab
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

-u | --remote_user <远程节点的登录用户名>           有参选项，脚本无法检测是否正确，但如果填写错误的话，
                                                    在已经配置了密钥公钥的两台服务器之间使用 scp 会提示要输入密码

-d | --remote_address <远程节点的 IP 地址或域名>    有参选项，脚本无法检测是否正确，但如果填写错误的话，
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
1.1 测试部署(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP 或域名 + 节点中备份的目标路径 + 超时阈值)
bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s -B \"*/2 * * * *\" -l \"* * */10 * *\" -L

1.2 生产部署(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP 或域名 + 节点中备份的目标路径 + 超时阈值)
bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s -B \"30 23 * * *\" -l \"* * */10 * *\" -L

2. 立即同步(需同时指定本地备份所在路径 + 远程节点已配置过密钥对登录的用户名 + 节点 IP 或域名 + 节点中备份的目标路径 + 超时阈值)
bash <(cat ${SH_NAME}.sh) -P /root/test108 -p /root/test119 -u root -d 1.2.3.4 -t 10s

3. 删除陈旧日志(默认10天)
bash <(cat ${SH_NAME}.sh) -r

4. 卸载
bash <(cat ${SH_NAME}.sh) -R
"
}

if ! ARGS=$(getopt -a -o P:,p:,u:,d:,t:,r,L,R,h,B:,l:,C -l source_path:,dest_path:,remote_user:,remote_address:,deploy,remove,timeout:,rmlog,help,backup_cron:,log_cron:,check_dep_sep -- "$@")
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
    -P | --source_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            SOURCE_PATH=$(echo "$2"|sed 's/\/$//g')
        fi
        shift
        ;;
    -p | --dest_path)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 2
        else
            DEST_PATH=$(echo "$2"|sed 's/\/$//g')
        fi
        shift
        ;;
    -u | --remote_user)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 3
        else
            REMOTE_USER="$2"
        fi
        shift
        ;;
    -d | --remote_address)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 4
        else
            REMOTE_ADDRESS="$2"
        fi
        shift
        ;;
    -t | --timeout)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            TIMEOUT="$2"
        fi
        shift
        ;;
    -B | --backup_cron)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 5
        else
            BACKUP_CRON="$2"
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
    -C | --check_dep_sep)
        CHECK_DEP_SEP=1
        ;;
    -r | --rmlog)
        RMLOG=1
        ;;
    -L | --deploy)
        DEPLOY=1
        ;;
    -R | --remove)
        REMOVE=1
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

Main(){
    if [ "${REMOVE}" -eq 1 ]; then
        Remove
        exit 0
    fi
    [ ! -d /var/log/${SH_NAME} ] && _warning "未创建日志文件夹，开始创建" && mkdir -p /var/log/${SH_NAME}
    if [ "${DEPLOY}" -eq 1 ]; then
        Deploy
        exit 0
    fi
    if [ "${RMLOG}" -eq 0 ]; then
        LocateFile
        CheckRemoteDir
        CloneOperation
    elif [ "${RMLOG}" -eq 1 ]; then
        RMLog
    fi
}

CheckOption
if [ "${CHECK_DEP_SEP}" == 1 ]; then
    exit 0
else
    :
fi
Main | tee "${EXEC_LOGFILE}"