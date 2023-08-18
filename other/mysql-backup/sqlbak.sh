#!/bin/bash
# 前置全局检测参数初始化和收集
# 规定sqlbak只通过安装包的形式安装，而非通过包内文件直接放置的方式实现部署
# 只有非涉密系统且联网时才允许更新和[卸载(仅限root)]，其他情况一律禁用更新和卸载
# 且更新也仅仅是联网下载安装包，卸载也是本地卸载安装包。
# 即 isClassified=0 && networkValid=1
isClassified=0
networkValid=0

IsClassifiedSystem(){
    # 0 = 否
    # 1 = 是
    # 2 = 暂未见过的涉密系统
    echo "date" > /tmp/test_classified.sh
    if ! bash /tmp/test_classified.sh >/dev/null 2>&1; then
        if bash <(cat /tmp/test_classified.sh) >/dev/null 2>&1; then
            isClassified=1
        else
            isClassified=2
        fi
    else
        isClassified=0
    fi
    rm -rf /tmp/test_classified.sh
}

IsNetworkValid(){
    # 0 = 无网络
    # 1 = 网络正常
    if timeout 5s ping -c2 -W1 www.baidu.com > /dev/null 2>&1; then
        networkValid=1
    else
        networkValid=0
    fi
}

IsClassifiedSystem

# 全局颜色(适配涉密机)

if ! which tput >/dev/null 2>&1 || [ "${isClassified}" -eq 1 ]; then
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
    printf "${_red} %s${_norm}\n" "$@"
}


todayDate=
isNonRootUser=
binPath=
etcPath=
cronPath=
yqFile=
yamlFile=
yamlFile1=
yamlFile2=
sqlBakFile=
otherCronFile=

firstOption=

mysqlIP=
mysqlPort=
mysqlUser=
mysqlPass=
backupPath=
expiresDays=
cronFormat=
dbType=
excludeDatabaseList=()
databaseList=()

mysqldumpPath=
specifiedTaskList=
timingSegmentList=

taskList=()
loseControlTask=()
installedTask=()
notInstalledTask=()
repairSegmentTimerList=()
taskListNotExistList=()
needRebuildSystemTimer=0

SetConstantAndVariableByCurrentUser(){
    # 当前日期时间
    todayDate=$(date +%Y-%m-%d_%H:%M:%S)

    case "$(arch)" in
    "aarch64")
        yqFile="/usr/bin/yq_linux_arm64"
        ;;
    "x86_64")
        yqFile="/usr/bin/yq_linux_amd64"
        ;;
    esac

    binPath="/usr/bin"
    sqlBakFile="/usr/bin/sqlbak"
    if [ $EUID -eq 0 ] && [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) -eq 0 ]]; then
        isNonRootUser=0
        etcPath="/etc"
        cronPath="/etc/cron.d"
        yamlFile1="/etc/sqlbak.yml"
        yamlFile2="/etc/sqlbak.yaml"
    else
        isNonRootUser=1
        etcPath="/home/$(whoami)/.local/etc"
        cronPath="/home/$(whoami)/.local/sqlbakcron"
        yamlFile1="/home/$(whoami)/.local/etc/sqlbak.yml"
        yamlFile2="/home/$(whoami)/.local/etc/sqlbak.yaml"
        otherCronFile="/home/$(whoami)/.local/sqlbakcron/other-cron"
    fi
    if [ -f "${yamlFile1}" ] && [ -f "${yamlFile2}" ]; then
        yamlFile=$(echo -e "
${yamlFile1}
${yamlFile2}")
    elif [ ! -f "${yamlFile1}" ] && [ ! -f "${yamlFile2}" ]; then
        yamlFile=""
    elif [ -f "${yamlFile1}" ];then
        yamlFile="${yamlFile1}"
    elif [ -f "${yamlFile2}" ];then
        yamlFile="${yamlFile2}"
    fi
    _success "全局变量初始化完成"
}

CheckDependence(){
    _info "开始检查环境依赖"
    # 对备份工具进行定位，如果找不到则退出
    if which mysqldump >/dev/null 2>&1; then
        mysqldumpPath=$(which mysqldump)
    else
        _error "找不到mysqldump，退出中"
        exit 1
    fi

	# 检查配置文件解析工具工作是否正常，如果不正常或丢失则退出
    if [ ! -f "${yqFile}" ]; then
        _error "配置文件解析工具丢失，请重新安装此软件，退出中"
        exit 1
    elif ! "${yqFile}" -V|awk '{print $NF}' >/dev/null 2>&1; then
        _error "配置文件解析工具损坏，无法解析，请重新安装此软件，退出中"
        exit 1
    fi

    if [ -f "${yamlFile1}" ] && [ -f "${yamlFile2}" ]; then
        _error "发现两种配置文件，请手动检查并只保留一个配置文件，退出中"
        echo "${yamlFile1}"
        echo "${yamlFile2}"
        exit 1
    elif [ ! -f "${yamlFile1}" ] && [ ! -f "${yamlFile2}" ]; then
        _warning "未发现配置文件，开始生成模板，请修改后重新运行"
        yamlFile="${yamlFile1}"
        GenerateProfile
        exit 0
    elif [ -f "${yamlFile1}" ];then
        yamlFile="${yamlFile1}"
    elif [ -f "${yamlFile2}" ];then
        yamlFile="${yamlFile2}"
    fi

    # 为非root用户创建工具正常工作所需的必要路径
	if [ "${isNonRootUser}" -eq 1 ]; then
	    [[ ! -d "${etcPath}" ]] && mkdir -p "${etcPath}"
	    [[ ! -d "${cronPath}" ]] && mkdir -p "${cronPath}"
	fi
	_success "环境依赖检查完成"
}

CheckInstallStatus(){
    # 以下echo的内容就是注释，ide中颜色明亮点方便调试
echo "
1: 配置存在
0: 配置不存在
root用户: 系统定时=定时分段

系统定时	定时分段	配置文件	结果
非root：
1		1		1		已安装
0		0		1		未安装
1		1		0		失控
1		0		0		失控
0		1		0		失控
1		0		1		自修复（添加定时分段）
0		1		1		自修复（重建系统定时）
0		0		0		-

root：
		1		1		已安装
		1		0		失控
		0		1		未安装
		0		0		-
" > /dev/null
    local i
    # timingSegmentList: 定时分段
    # taskList: 配置文件
    # yamlStreamTaskList: 系统定时
    if ! ${yqFile} '.*|key' "${yamlFile}" >/dev/null; then
        _error "配置文件出现异常，已输出报错信息，退出中"
        exit 1
    fi
    # 重置数组防止被事先存入了元素
    taskList=()
    loseControlTask=()
    installedTask=()
    notInstalledTask=()
    mapfile -t taskList < <(${yqFile} '.*|key' "${yamlFile}")
    mapfile -t timingSegmentList < <(find "${cronPath}" -name "mysql-backup-task@_*"|awk -F '@_' '{print $NF}')
    if [ "${isNonRootUser}" -eq 0 ]; then
        # 配置文件中任务名对比系统已有定时的任务名，对比相同的名称组成：已安装任务数组
        for i in "${taskList[@]}" ; do
            if printf '%s\0' "${timingSegmentList[@]}" | grep -Fxqz -- "${i}"; then
                mapfile -t -O "${#installedTask[@]}" installedTask < <(echo "${i}")
            fi
        done

        # 配置文件中任务去掉已安装任务组成：未安装任务数组
        for i in "${taskList[@]}" ; do
            if ! printf '%s\0' "${installedTask[@]}" | grep -Fxqz -- "${i}"; then
                mapfile -t -O "${#notInstalledTask[@]}" notInstalledTask < <(echo "${i}")
            fi
        done

        # 系统已有定时的任务列表去掉已安装任务组成：失去控制的任务数组
        for i in "${timingSegmentList[@]}" ; do
            if ! printf '%s\0' "${installedTask[@]}" | grep -Fxqz -- "${i}"; then
                mapfile -t -O "${#loseControlTask[@]}" loseControlTask < <(echo "${i}")
            fi
        done
    else
        local systemCronToYamlStream yamlStreamTaskList temp1Task temp0Task
        if crontab -l >/dev/null 2>&1; then
            systemCronToYamlStream=$(crontab -l|grep "^#%"|sed 's/^#%//g')
            mapfile -t -O "${#yamlStreamTaskList[@]}" yamlStreamTaskList < <(echo "${systemCronToYamlStream}"|yq '.*|key')
        else
            yamlStreamTaskList=()
        fi

        # 配置文件中任务名对比定时分段任务名，对比相同的名称组成：temp1Task，定时分段不存在的话组成：temp0Task
        temp0Task=()
        temp1Task=()
        for i in "${taskList[@]}" ; do
            if printf '%s\0' "${timingSegmentList[@]}" | grep -Fxqz -- "${i}"; then
                mapfile -t -O "${#temp1Task[@]}" temp1Task < <(echo "${i}")
            else
                mapfile -t -O "${#temp0Task[@]}" temp0Task < <(echo "${i}")
            fi
        done

        # 配置文件1-定时分段1-系统定时1->installedTask: 已安装
        # 配置文件1-定时分段1-系统定时0->repairSystemTimerList: 自修复（重建系统定时）
        if [ "${#temp1Task[@]}" -gt 0 ]; then
            for i in "${temp1Task[@]}" ; do
                if printf '%s\0' "${yamlStreamTaskList[@]}" | grep -Fxqz -- "${i}"; then
                    mapfile -t -O "${#installedTask[@]}" installedTask < <(echo "${i}")
                else
                    needRebuildSystemTimer=1
                fi
            done
        fi

        # 配置文件1-定时分段0-系统定时1->repairSegmentTimerList: 自修复（添加定时分段）
        # 配置文件1-定时分段0-系统定时0->notInstalledTask: 未安装
        if [ "${#temp0Task[@]}" -gt 0 ]; then
            for i in "${temp0Task[@]}" ; do
                if printf '%s\0' "${yamlStreamTaskList[@]}" | grep -Fxqz -- "${i}"; then
                    mapfile -t -O "${#repairSegmentTimerList[@]}" repairSegmentTimerList < <(echo "${i}")
                else
                    mapfile -t -O "${#notInstalledTask[@]}" notInstalledTask < <(echo "${i}")
                fi
            done
        fi

        # 定时分段任务名对比配置文件中任务名，配置文件中不存在的任务名组成：taskListNotExistList（删除残留定时分段）
        # 配置文件0-定时分段1-系统定时随意，均删除多余分段后重建系统定时
        for i in "${timingSegmentList[@]}" ; do
            if ! printf '%s\0' "${taskList[@]}" | grep -Fxqz -- "${i}"; then
                mapfile -t -O "${#taskListNotExistList[@]}" taskListNotExistList < <(echo "${i}")
            fi
        done

        # 配置文件0-定时分段0-系统定时1，直接重建系统定时
        if [ "${#taskListNotExistList[@]}" -eq 0 ]; then
            for i in "${yamlStreamTaskList[@]}" ; do
                if ! printf '%s\0' "${taskList[@]}" | grep -Fxqz -- "${i}"; then
                    needRebuildSystemTimer=1
                    break
                fi
            done
        # 配置文件0-定时分段1-系统定时随意，均删除多余分段后重建系统定时
        elif [ "${#taskListNotExistList[@]}" -gt 0 ]; then
            : # 删除该数组中的所有定时分段，然后重建系统定时
        fi
    fi
}

AutoRepair(){
    local i flag
    flag=0
    if [ "${isNonRootUser}" -eq 0 ]; then
        if [ "${#loseControlTask[@]}" -gt 0 ]; then
            for i in "${loseControlTask[@]}" ; do
                rm -rf  "${cronPath}"/mysql-backup-task@_"${i}"
            done
            _warning "发现系统中存在本工具配置文件中不存在的备份任务！已清理"
            flag=1
        fi
    elif [ "${isNonRootUser}" -eq 1 ]; then
        [ -f "${cronPath}"/final-cron-install-file ] && rm -rf "${cronPath}"/final-cron-install-file
        # 删除残留定时分段
        if [ "${#taskListNotExistList[@]}" -gt 0 ]; then
            for i in "${taskListNotExistList[@]}" ; do
                rm -rf "${cronPath}"/mysql-backup-task@_"${i}"
            done
            needRebuildSystemTimer=1
            _warning "发现系统中存在本工具配置文件中不存在的备份任务！已清理"
            flag=1
        fi

        # 添加定时分段
        if [ "${#repairSegmentTimerList[@]}" -gt 0 ]; then
            for i in "${repairSegmentTimerList[@]}" ; do
                ParseYaml "${i}"
                InstallTask "${i}"
            done
            _warning "发现系统中存在部分配置丢失的备份任务！已修复"
            flag=2
        fi

        # 重建系统定时
        if [ "${needRebuildSystemTimer}" -eq 1 ]; then
            timingSegmentList=()
            mapfile -t timingSegmentList < <(find "${cronPath}" -name "mysql-backup-task@_*"|awk -F '@_' '{print $NF}')
            for i in "${timingSegmentList[@]}" ; do
                cat "${cronPath}"/mysql-backup-task@_"${i}" >> "${cronPath}"/final-cron-install-file
            done
            if [ -f "${cronPath}"/final-cron-install-file ]; then
                crontab "${cronPath}"/final-cron-install-file
                rm -rf "${cronPath}"/final-cron-install-file
                _warning "已根据已安装的备份任务重建系统备份计划"
            fi
            flag=3
        fi
    fi
    if [ "${flag}" -gt 0 ]; then
        CheckInstallStatus
        _success "已重新读取修正后的任务安装环境"
    else
        _success "比对完成，未发现异常"
    fi
}

CheckInputTasks(){
    _info "正在解析输入信息"
    specifiedTaskList=("$@")
    local wrongTaskName i
    if [ "${#specifiedTaskList[@]}" -eq 0 ] ||
    [ "${specifiedTaskList[0]}" == "help" ] ||
    [ "${specifiedTaskList[0]}" == "all" ] ||
    { [ "${specifiedTaskList[0]}" == "rest" ] && [ "${firstOption}" == "install" ]; }; then
        return
    fi
    wrongTaskName=()
    for i in "${specifiedTaskList[@]}" ; do
        if ! printf '%s\0' "${taskList[@]}" | grep -Fxqz -- "${i}"; then
            mapfile -t -O "${#wrongTaskName[@]}" wrongTaskName < <(echo "${i}")
        fi
    done

    if [ "${#wrongTaskName[@]}" -gt 0 ]; then
        _error "配置文件中不存在以下指定的任务名，请修正并重新运行: "
        for i in "${wrongTaskName[@]}" ; do
            _warningnoblank "${i}"
        done
        exit 1
    fi
    _success "输入信息解析完成"
}

GenerateProfile() {
    cat >"${yamlFile}" <<EOF
name1:
  ip: localhost
  port: 3306
  user: root
  password: 1234
  database:
    - aaa
    - bbb
    - ccc
  backup-path: /backup
  expires-days: 15
  cron-format: "0 1 * * *"

#name2: # namexxx是为当前任务自定义的别名
#  ip: 2.2.2.2 # 数据库所在服务器的 ip，本地备份支持 localhost 或 127.0.0.1 写法
#  port: 3307 # 数据库连接端口号
#  user: root # 数据库连接用户名
#  password: 5678 # 数据库连接密码
#  database: aaa # 如果只有一个数据库就不用写成列表样式
#  backup-path: /opt/test # 要备份到执行当前工具所在节点下的路径
#  expires-days: 10 # 自动清理生成多少天后的过期备份文件，0为关闭自动删除功能
#  cron-format: "0 1 * * *" # 此值在本工具中没有合法性判断流程，可自行查阅配置教程或搜索crontab在线生成工具来生成可用的五段式定时写法，必须用双引号将写法括起来否则会报错

#name3:
#  ip: localhost
#  port: 3306
#  user: root
#  password: 1234
#  exclude-database: # 排除多个数据库
#    - aaa
#    - bbb
#    - ccc
#  backup-path: /mnt/test3
#  expires-days: 15
#  cron-format: "0 1 * * *"

#name4:
#  ip: 2.2.2.2
#  port: 3307
#  user: root
#  password: 5678
#  exclude-database: aaa # 如果只排除一个数据库就不用写成列表样式
#  backup-path: /opt/test4
#  expires-days: 10
#  cron-format: "0 1 * * *"
EOF
}

ParseYaml() {
    local paramList specifiedTaskParamList paramName
    paramList=(
        "ip"
        "port"
        "user"
        "password"
        "backup-path"
        "expires-days"
        "cron-format"
        "database"
        "exclude-database"
    )

    # 首先确认yml文件可以被正常解析
    if ! ${yqFile} '.' "${yamlFile}" >/dev/null; then
        _error "配置文件出现异常，已输出报错信息，退出中"
        exit 1
    fi

    # 检测程序工作所需键在配置文件中是否存在
    # 检测键database和exclude-database是否同时存在，二者只能必须且仅能留一个
    mapfile -t specifiedTaskParamList < <(${yqFile} '.'"${1}"'.*|key' "${yamlFile}")
    local dbCount edbCount
    dbCount=0
    edbCount=0

    for paramName in "${paramList[@]}" ; do
        if [ "${paramName}" != "database" ] && [ "${paramName}" != "exclude-database" ]; then
            if ! printf '%s\n' "${specifiedTaskParamList[@]}" | grep -qF "${paramName}"; then
                _error "缺少配置选项: ${paramName}，退出中"
                exit 1
            else
                continue
            fi
        fi
        if printf '%s\n' "${specifiedTaskParamList[@]}" | grep -q "^database$"; then
            dbCount+=1
            dbType="include"
        fi
        if printf '%s\n' "${specifiedTaskParamList[@]}" | grep -q "^exclude-database$"; then
            edbCount+=1
            dbType="exclude"
        fi
    done

    if [ "${dbCount}" -gt 0 ] && [ "${edbCount}" -gt 0 ]; then
        _error "database和exclude-database只能设置其一，不能同时存在或同时不存在，退出中"
        exit 1
    fi
    if [ "${edbCount}" -gt 0 ]; then
        if ! ${mysqldumpPath} --help | grep -qF "ignore-database" >/dev/null 2>&1; then
            _error "此版本mysqldump没有排除数据库名的功能，请使用database键以手动指定每一个需要备份的数据库名，退出中"
            exit 1
        fi
    fi

    # 解析赋值变量
    mysqlIP=$(${yqFile} '.'"${1}"'.ip' "${yamlFile}")
    mysqlPort=$(${yqFile} '.'"${1}"'.port' "${yamlFile}")
    mysqlUser=$(${yqFile} '.'"${1}"'.user' "${yamlFile}")
    mysqlPass=$(${yqFile} '.'"${1}"'.password' "${yamlFile}")
    backupPath=$(${yqFile} '.'"${1}"'.backup-path' "${yamlFile}")
    expiresDays=$(${yqFile} '.'"${1}"'.expires-days' "${yamlFile}")
    cronFormat=$(${yqFile} '.'"${1}"'.cron-format' "${yamlFile}")

    # 根据dbType的值选分支，判断数据库是单库名还是列表库名，最终均收纳到databaseList或excludeDatabaseList数组中
    databaseList=()
    excludeDatabaseList=()
    case "${dbType}" in
    "include")

        mapfile -t -O "${#databaseList[@]}" databaseList < <(${yqFile} '.'"${1}"'.database.[]' "${yamlFile}")
        if [ "${#databaseList[@]}" -eq 0 ]; then
            if [ -n "$(${yqFile} '.'"${1}"'.database' "${yamlFile}")" ]; then
                databaseList[0]=$(${yqFile} '.'"${1}"'.database' "${yamlFile}")
            fi
        fi
        ;;
    "exclude")
        mapfile -t -O "${#excludeDatabaseList[@]}" excludeDatabaseList < <(${yqFile} '.'"${1}"'.exclude-database.[]' "${yamlFile}")
        if [ "${#excludeDatabaseList[@]}" -eq 0 ]; then
            if [ -n "$(${yqFile} '.'"${1}"'.exclude-database' "${yamlFile}")" ]; then
                excludeDatabaseList[0]=$(${yqFile} '.'"${1}"'.exclude-database' "${yamlFile}")
            fi
        fi
    esac

    # 对变量值进行调整和筛选判断
    # 配置文件所有键值必须有值
    if [ -z "${mysqlIP}" ] ||
    [ -z "${mysqlPort}" ] ||
    [ -z "${mysqlUser}" ] ||
    [ -z "${mysqlPass}" ] ||
    [ -z "${backupPath}" ] ||
    [ -z "${expiresDays}" ] ||
    [ -z "${cronFormat}" ]; then
        _error "存在部分键值为空，请检查，退出中"
        exit 1
    fi

    case "${dbType}" in
    "include")
        if [ "${#databaseList[@]}" -eq 0 ]; then
            _error "待备份数据库键值为空，请检查，退出中"
            exit 1
        fi
        ;;
    "exclude")
        if [ "${#excludeDatabaseList[@]}" -eq 0 ]; then
            _error "待排除数据库键值为空，请检查，退出中"
            exit 1
        fi
        ;;
    esac
    # 非根目录且路径末尾有/则去掉路径末尾/
    if [[ ${backupPath} =~ ^/$ ]]; then
        :
    elif [[ ${backupPath} =~ /$ ]]; then
        backupPath="${backupPath%/}"
#        echo "${backupPath}"
    fi

    # 非root用户必须对备份路径进行每一层级目录的权限排查，以避免无法写入备份文件的问题。
    # 已知只要非其他系统已存在用户的家目录，路径末端文件夹属主是当前用户，则内部无限层级均可由当前用户创建，因此判断条件有三个:
    # 1. 备份路径文件夹不是其他用户的家目录下的子文件夹
    # 2. 如果需要写入文件的路径存在且不是根目录，则写入文件的文件夹属主必须是当前用户
    # 3. 如果需要写入文件的文件夹不存在，则向上递归直到有文件夹存在，之后进入第二个判断
    #
    # root用户绝大部分路径均可访问写入，但个别路径是系统限制无法写入，因此需要猜测是否可写，所以流程分两步：
    # 1. 如果路径存在，则尝试直接写入文件检查是否可写
    # 2. 如果路径不存在，则向上递归直到有文件夹存在，之后进入第一个判断
    local parentPath invalidPath i lastBakFolder
    parentPath="${backupPath}"
    if [ "${isNonRootUser}" -eq 1 ]; then
        mapfile -t invalidPath < <(awk -F ':' '{print $6}' /etc/passwd|grep -v "/$")
        for i in "${invalidPath[@]}"; do
            if [[ "${parentPath}" =~ ^${i} ]]; then
                _error "指定的备份路径禁止设置为系统已存在用户的家目录(${i})中的子目录！退出中"
                exit 1
            fi
        done
        while true; do
            if [ -d "${parentPath}" ]; then
                if [ "${parentPath}" == "/" ]; then
                        _error "非root用户禁止在系统根目录存放备份的数据库存档，请重新指定路径"
                        _error "退出中"
                        exit 1
                elif [ ! -O "${parentPath}" ]; then
                    lastBakFolder=$(awk -F '/' '{print $NF}' <<< "${parentPath}")
                    _error "当前用户没有权限将数据库备份到设置的备份路径下"
                    _error "请在root用户下将备份文件存放的文件夹的权限(${lastBakFolder})设置为当前用户($(whoami))可完全访问，退出中"
                    exit 1
                else
                    break
                fi
            else
                parentPath=$(dirname "${parentPath}")
            fi
        done
    elif [ "${isNonRootUser}" -eq 0 ]; then
        while true; do
            if [ -d "${parentPath}" ]; then
                if ! touch "${parentPath}"/testfile >/dev/null 2>&1; then
                    _error "此路径在涉密或限制性系统中无法作为备份路径: ${parentPath}"
                    _error "退出中"
                    exit 1
                else
                    rm -rf "${parentPath}"/testfile
                    break
                fi
            else
                parentPath=$(dirname "${parentPath}")
            fi
        done
    fi

    # 检查过期天数合法性
    case ${expiresDays} in
        ''|*[!0-9]*)
            _error "过期天数只能是非负整数（禁止+-符号），退出中"
            exit 1
        ;;
    esac

    # 检查数据库连接性
    if ! mysql -h"${mysqlIP}" -P"${mysqlPort}" -u"${mysqlUser}" -p"${mysqlPass}" -e "exit" >/dev/null 2>&1; then
        _error "数据库无法连接，请检查 IP、端口号、用户名、密码是否有错，退出中"
        exit 1
    fi

    # 检查配置文件中指定备份的数据库名是否存在
    # 注意这循环中的 i 必须安排局部变量否则会覆盖主循环中的 i 值
    local databaseString flag wrongDatabaseName i
    databaseString="$(mysql -sr -h"${mysqlIP}" -P"${mysqlPort}" -u"${mysqlUser}" -p"${mysqlPass}" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA" 2>/dev/null)"
    wrongDatabaseName=()
    for i in "${databaseList[@]}"; do
        flag=0
        if ! tr ' ' '\n' <<< "${databaseString}"|grep "^${i}$" >/dev/null 2>&1; then
            flag=1
        fi
        if [ "${flag}" -eq 1 ]; then
            mapfile -t -O "${#wrongDatabaseName[@]}" wrongDatabaseName < <(echo "${i}")
        fi
    done
    if [ "${#wrongDatabaseName[@]}" -gt 0 ]; then
        _error "源 MySQL 中不存在以下配置文件中指定的数据库名，请修正并重新运行: "
        for i in "${wrongDatabaseName[@]}" ; do
            _warningnoblank "${i}"
        done
        exit 1
    fi
}

# 安装策略：
# 无论一次安装多少个任务，总是一个任务设置一个任务记录文件，里面有已注释的该任务的详细配置和实际可用的定时写法，同任务被多次安装的话会完全覆盖而非追加，以下是root和非root用户安装区别
# 1. root：每个任务记录文件都是一个定时功能，无需后续操作
# 2. 非root：任何任务记录文件均不会执行，而是生成一个或多个任务记录文件后，将指定的任务记录文件内的内容组合成一个最终文件，然后将最终文件安装进系统定时任务后删除，非root用户安装不同定时任务文件会覆盖而非追加故用此方法实现
InstallTask(){
    # 为每一个任务拼装一个定时文件
    cat > "${cronPath}"/mysql-backup-task@_"${1}" << EOF
#%${1}:
#%  ip: ${mysqlIP}
#%  port: ${mysqlPort}
#%  user: ${mysqlUser}
#%  password: ${mysqlPass}
#%  backup-path: ${backupPath}
#%  expires-days: ${expiresDays}
#%  cron-format: "${cronFormat}"
EOF
    case "${dbType}" in
    "include")
        if [ "${#databaseList[@]}" -eq 1 ]; then
            echo "#  database: ${databaseList[0]}" >> "${cronPath}"/mysql-backup-task@_"${1}"
        elif [ "${#databaseList[@]}" -gt 1 ]; then
            echo "#  database: " >> "${cronPath}"/mysql-backup-task@_"${1}"

            local i
            for i in "${databaseList[@]}" ; do
                echo "#    - ${i}" >> "${cronPath}"/mysql-backup-task@_"${1}"
            done
        fi

        ;;
    "exclude")
        if [ "${#excludeDatabaseList[@]}" -eq 1 ]; then
            echo "#  exclude-database: ${excludeDatabaseList[0]}" >> "${cronPath}"/mysql-backup-task@_"${1}"
        elif [ "${#excludeDatabaseList[@]}" -gt 1 ]; then
            echo "#  exclude-database: " >> "${cronPath}"/mysql-backup-task@_"${1}"

            local i
            for i in "${excludeDatabaseList[@]}" ; do
                echo "#    - ${i}" >> "${cronPath}"/mysql-backup-task@_"${1}"
            done
        fi
    ;;
    esac

    if [ "${isNonRootUser}" -eq 0 ]; then
        cat >> "${cronPath}"/mysql-backup-task@_"${1}" << EOF
${cronFormat} $(whoami) ${sqlBakFile} run ${1}
EOF
    elif [ "${isNonRootUser}" -eq 1 ]; then
        cat >> "${cronPath}"/mysql-backup-task@_"${1}" << EOF
${cronFormat} ${sqlBakFile} run ${1}
EOF
    fi
}

RemoveTask(){
    rm -rf "${cronPath}"/mysql-backup-task@_"${1}"
}

RunTask() {
    # 如果文件夹不存在则创建
    if [ ! -d "${backupPath}" ]; then
        mkdir -p "${backupPath}"
    fi

    # 备份并转写为压缩包，格式：任务名_-_表名_-_日期.sql.gz
    local i execCommand
    case "${dbType}" in
    "include")
        execCommand="${mysqldumpPath} -h ${mysqlIP} -P ${mysqlPort} -u ${mysqlUser} -p${mysqlPass} --default-character-set=utf8mb4 -B ${databaseList[@]} | gzip >"${backupPath}"/"${1}"_-_"${todayDate}".sql.gz 2>/tmp/sqlbak.tmp"
        if ! eval "${execCommand}";then
            WriteLog "${1}"
        fi
        ;;
    "exclude")
        local i
        for ((i=0; i<${#excludeDatabaseList[@]}; i++))
        do
            excludeDatabaseList[$i]=" --ignore-database=${excludeDatabaseList[$i]}"
        done
        execCommand="${mysqldumpPath} -h ${mysqlIP} -P ${mysqlPort} -u ${mysqlUser} -p${mysqlPass} --default-character-set=utf8mb4 -A ${excludeDatabaseList[@]} | gzip >${backupPath}/${1}_-_${todayDate}.sql.gz 2>/tmp/sqlbak.tmp"
        if ! eval "${execCommand}";then
            WriteLog "${1}"
        fi
        ;;
    esac
    rm -rf /tmp/sqlbak.tmp
}

WriteLog(){
    if [ ! -d /var/log/sqlbak ]; then
        mkdir -p /var/log/sqlbak
    fi
    cat >> /var/log/sqlbak/error-"${todayDate}".log <<EOF
=======================================
时间: ${todayDate}
任务名: ${1}

EOF
    cat /tmp/sqlbak.tmp >> /var/log/sqlbak/error-"${todayDate}".log
}

DeleteExpiresArchive() {
    if [ "${expiresDays}" -eq 0 ]; then
        _success "任务 ${1} 设置为不删除过期备份，跳过"
        return
    fi
    #找出需要删除的备份
    _info "开始清理任务 ${1} 的过期备份"
    local expiredBackupList k a
    for k in "${databaseList[@]}"; do
        mapfile -t -O "${#expiredBackupList}" expiredBackupList < <(find "${backupPath}" -name "${1}_-_${k}_-_*.sql.gz" -mtime +"${expiresDays}")
    done
    for a in "${expiredBackupList[@]}"; do
        rm -f "${a}"
    done
    _success "过期备份清理完成"
}

CheckTask(){
    printf "================\n"
    # 判断备份路径是否存在
    if [ ! -d "${backupPath}" ]; then
        _warning "备份路径不存在，实际执行时将创建此路径: ${backupPath}"
    fi
    echo -e "${_cyan}
任务名: ${_tan}$1${_cyan}
数据库IP: ${_tan}${mysqlIP}${_cyan}
数据库端口号: ${_tan}${mysqlPort}${_cyan}
数据库用户名: ${_tan}${mysqlUser}${_cyan}
数据库登录密码: ${_tan}${mysqlPass}${_cyan}
备份路径: ${_tan}${backupPath}${_cyan}
过期天数: ${_tan}${expiresDays}${_norm}"|column -t

    case "${dbType}" in
    "include")
        echo -e "${_cyan}需备份数据库: "
        local k
        for k in "${databaseList[@]}"; do
            echo -e "${_tan}${k}${_norm}"
        done
        ;;
    "exclude")
        echo -e "${_cyan}需排除数据库: "
        local j
        for j in "${excludeDatabaseList[@]}"; do
            echo -e "${_tan}${j}${_norm}"
        done
        ;;
    esac

    echo
}

RebuildCron(){
    _info "开始重建系统定时任务"
    [ -f "${cronPath}"/final-cron-install-file ] && rm -rf "${cronPath}"/final-cron-install-file
    if [ -n "$(find "${cronPath}" -name "mysql-backup-task@_*")" ]; then
        cat "${cronPath}"/mysql-backup-task@_* >> "${cronPath}"/final-cron-install-file
    else
        crontab -r >/dev/null 2>&1
    fi
    if [ ! -f "${otherCronFile}" ]; then
        if ! crontab -l >/dev/null 2>&1; then
            touch "${otherCronFile}"
        else
            crontab -l > "${otherCronFile}"
        fi
    else
        cat "${otherCronFile}" >> "${cronPath}"/final-cron-install-file
    fi
    crontab "${cronPath}"/final-cron-install-file >/dev/null 2>&1
    rm -rf "${cronPath}"/final-cron-install-file
    _success "系统定时任务重建完成"
}

Destroy(){
    _info "开始卸载sqlbak"
    if [ "${isNonRootUser}" -eq 0 ]; then
        rm -rf "${cronPath}"/mysql-backup-task@_*
        rm -rf "${yamlFile}" "${sqlBakFile}" "${yqFile}"
    elif [ "${isNonRootUser}" -eq 1 ]; then
        if [ -f "${otherCronFile}" ]; then
            crontab "${otherCronFile}" >/dev/null 2>&1
            _success "已恢复非本工具生成的用户自定义系统定时计划"
        else
            crontab -r >/dev/null 2>&1
        fi
        rm -rf "${yqFile}" "${sqlBakFile}" "${yamlFile}" "${cronPath}"
        rmdir "${binPath}" 2>/dev/null
        rmdir "${etcPath}" 2>/dev/null
        rmdir /home/"$(whoami)"/.local 2>/dev/null
    fi
    _success "sqlbak已卸载，再见"
}

Help(){
    echo -e "
sqlbak  -- mysql/mariadb数据库备份工具

设计思路: 以确定的数据库连接为一个基本单元
通过yaml文件来配置若干基本单元各自的详细信息
一个基本单元被运行时可以备份其中一个或多个数据库
也可以通过安装/卸载以向系统中添加/取消/更新定时备份计划
运行时不限制是否是root用户，工具会自动检测用户并执行对应的功能
"
    if [ "${isClassified}" -eq 0 ]; then
        echo -e "${_cyan}当前系统类型: ${_green}常规系统${_norm}
        "
        if [[ $(readlink -f "$0") == "${sqlBakFile}" ]]; then
            _warning "注意:
1. 本工具首次带[操作]名称运行即自动将自身和必要依赖和配置文件安装进系统(不包括help/--help/-h选项)，后续直接输入sqlbak即可运行
2. 对于非root用户使用本工具且系统中已有或未来需要新增其他定时任务的需求，必须执行此命令以完成当前用户系统定时重建:
$(readlink -f "$0") rebuild-cron
3. 未来本工具如有更新，只需手动执行以下命令即可完成功能更新:
$(readlink -f "$0")
4. 若本工具并未安装过，绝对不要运行以下命令，否则非root已有的系统定时任务将被清空:
$(readlink -f "$0") destroy
"
        else
            _warning "注意:
1. 本工具首次带[操作]名称运行即自动将自身和必要依赖和配置文件安装进系统(不包括help/--help/-h选项)，后续直接输入sqlbak即可运行
2. 本工具首次运行后如果无报错生成则可以删除此文件: $(readlink -f "$0")
3. 对于非root用户使用本工具且系统中已有或未来需要新增其他定时任务的需求，必须执行此命令以完成当前用户系统定时重建:
bash $(readlink -f "$0") rebuild-cron
4. 未来本工具如有更新，只需手动执行以下命令即可完成功能更新(bash后的绝对路径是根据本工具当前所处路径而自动检测后打印的):
bash $(readlink -f "$0")
5. 若本工具并未安装过，绝对不要运行以下命令，否则非root已有的系统定时任务将被清空:
bash $(readlink -f "$0") destroy
"
        fi
    elif [ "${isClassified}" -eq 1 ]; then
        echo -e "${_cyan}当前系统类型: ${_red}涉密或限制性系统${_norm}
        "
        _warning "注意:
1. 对于非root用户使用本工具且系统中已有或未来需要新增其他定时任务的需求，必须执行此命令以完成当前用户系统定时重建:
$(readlink -f "$0") rebuild-cron
2. 在涉密或其他限制性系统上，此工具的这些选项无法使用(使用时会被主动阻断): update/destroy
"
    fi
_infonoblank "用法:
"
_warningnoblank "单任务: sqlbak [操作] [任务]
多任务: sqlbak [操作] [任务1] [任务2] [任务3] ..."
_infonoblank "
明确操作种类但不知道任务名(相同功能，二选一):"
_warningnoblank "
sqlbak [操作] help
sqlbak [操作]
"

_infonoblank "操作种类(选项):"
_warningnoblank "
rebuild-cron 非root用户修改自定义定时任务后手动与已安装数据库备份计划组合重建
update 自动更新本工具正常工作所需依赖
install 指定配置文件中存在的一/多个任务名，安装为系统定时备份计划
remove 指定配置文件中存在的一/多个任务名，删除其已设置的定时备份计划
run 指定配置文件中存在的一/多个任务名，运行其备份操作
check 检查并打印配置文件中的指定一/多个任务的详细配置信息
destroy 彻底卸载本工具并还原非root用户自定义的系统定时
help 打印此帮助菜单并退出
" | column -t
_infonoblank "检测结果:"
if [ "${isNonRootUser}" -eq 1 ]; then
    _warningnoblank "
当前用户名: $(whoami)
配置文件绝对路径: ${yamlFile}
定时内容路径: ${cronPath}
非root用户增减其他定时任务文件: ${otherCronFile}" | column -t
else
    _warningnoblank "
当前用户名: $(whoami)
定时内容路径: ${cronPath}
配置文件绝对路径: ${yamlFile}"| column -t
fi
}

# 主程序入口
if [ "${isClassified}" -eq 2 ]; then
    _error "未知的限制性或涉密系统，请联系作者检查并适配！本工具将不进行任何操作，退出中..."
    exit 1
fi
SetConstantAndVariableByCurrentUser

# 判断工具后跟的首个参数名以分配不同功能
firstOption="${1}"
specifiedTaskList=("${@:2}")
if [[ "${firstOption}" =~ "help"|"-h"|"--help" ]] && [ -n "${2}" ]; then
    _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:2}"
    exit 1
elif [ "${firstOption}" == "update" ] && [ -n "${2}" ]; then
    _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:2}"
    exit 1
elif [ "${firstOption}" == "rebuild-cron" ] && [ -n "${2}" ]; then
    _error "rebuild-cron 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:2}"
    exit 1
elif [ "${firstOption}" == "destroy" ] && [ -n "${2}" ]; then
    _error "destroy 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:2}"
    exit 1
elif [ -z "${firstOption}" ]; then
    Help
    exit 0
fi

case "${firstOption}" in
    "update")
        IsNetworkValid
        if [ "${isClassified}" -eq 0 ] && [ "${networkValid}" -eq 1 ]; then
            _error "更新功能暂未开放，请等待版本更新，退出中"
#            CheckUpdate
            exit 0
        else
            _error "检测到此工具安装在限制性/涉密系统中或无网络连接，更新功能无法使用，退出中"
            exit 1
        fi
        ;;
    "rebuild-cron")
        if [ "${isNonRootUser}" -eq 1 ]; then
            RebuildCron
            exit 0
        elif [ "${isNonRootUser}" -eq 0 ]; then
            _error "此操作只有非root用户才可以使用，退出中"
            exit 1
        fi
        ;;
    "destroy")
        if [ "${isClassified}" -eq 0 ]; then
            _error "卸载功能暂未开放，请等待版本更新，退出中"
#            Destroy
            exit 0
        else
            _error "检测到此工具安装在限制性/涉密系统中，无法实现自我卸载功能，退出中"
            exit 1
        fi
        ;;
    "help"|"-h"|"--help")
        Help
        exit 0
        ;;
esac

CheckDependence
_info "开始比对本工具生成的系统定时任务和配置文件中指定的定时任务"
CheckInstallStatus
AutoRepair
CheckInputTasks "${@:2}"
#echo "specifiedTaskList:"
#echo "${specifiedTaskList[@]}"
#echo "taskList:"
#echo "${taskList[@]}"

case "${firstOption}" in
    "install")
        if [ "${#specifiedTaskList[@]}" -eq 0 ] || { [ "${2}" == "help" ] && [ -z "${3}" ]; }; then
            echo
            _infonoblank "Tips: 支持单个任务安装或多个任务名同时安装，任务名之间用空格隔开
            例1: $0 install aa
            例2: $0 install aa bb cc dd ...
            "
            _infonoblank "特殊任务名:
            all: 全部安装(包括覆盖安装已安装的任务)，后面不能有任何其他任务名
            rest: 仅安装全部未安装的任务，后面不能有任何其他任务名"|column -t
            echo
            _infonoblank "已安装备份任务如下："
            for i in "${installedTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

            _infonoblank "未安装备份任务如下："
            for i in "${notInstalledTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

        elif [ "${2}" == "help" ] && [ -n "${3}" ]; then
            _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -n "${3}" ]; then
            _error "all 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "rest" ] && [ -n "${3}" ]; then
            _error "rest 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -z "${3}" ]; then
            _info "开始安装任务"
            for taskName in "${notInstalledTask[@]}"; do
                ParseYaml "${taskName}"
                InstallTask "${taskName}"
                _success "已安装任务名: ${taskName}"
            done
            for taskName in "${installedTask[@]}"; do
                ParseYaml "${taskName}"
                InstallTask "${taskName}"
                _success "已更新配置的任务名: ${taskName}"
            done
            _success "任务安装完成"
        elif [ "${2}" == "rest" ] && [ -z "${3}" ]; then
            _info "开始安装任务"
            if [ "${#notInstalledTask[@]}" -gt 0 ]; then
                for taskName in "${notInstalledTask[@]}"; do
                    ParseYaml "${taskName}"
                    InstallTask "${taskName}"
                    _success "已安装任务名: ${taskName}"
                done
            elif [ "${#notInstalledTask[@]}" -eq 0 ]; then
                _warning "系统中不存在未安装的任务，跳过安装"
                exit 0
            fi
            _success "任务安装完成"
        else
            _info "开始安装任务"
            needInstallTaskList=()
            alreadyInstallTaskList=()
            for i in "${specifiedTaskList[@]}" ; do
                if printf '%s\0' "${installedTask[@]}" | grep -Fxqz -- "${i}"; then
                    mapfile -t -O "${#alreadyInstallTaskList[@]}" alreadyInstallTaskList < <(echo "${i}")
                else
                    mapfile -t -O "${#needInstallTaskList[@]}" needInstallTaskList < <(echo "${i}")
                fi
            done
            for taskName in "${needInstallTaskList[@]}"; do
                ParseYaml "${taskName}"
                InstallTask "${taskName}"
                _success "已安装任务名: ${taskName}"
            done
            for taskName in "${alreadyInstallTaskList[@]}"; do
                ParseYaml "${taskName}"
                InstallTask "${taskName}"
                _success "已更新配置的任务名: ${taskName}"
            done
            _success "任务安装完成"
        fi
        # 以下是非root用户专用的将最终定时任务安装进系统定时
        if { [ -n "${2}" ] && [ "${2}" != "help" ]; } && [ "${isNonRootUser}" -eq 1 ]; then
            RebuildCron
        fi
    ;;
    "remove")
        if [ "${#specifiedTaskList[@]}" -eq 0 ] || { [ "${2}" == "help" ] && [ -z "${3}" ]; }; then
            echo
            _infonoblank "Tips: 支持单个任务移除或多个任务名同时移除，任务名之间用空格隔开
            例1: $0 remove aa
            例2: $0 remove aa bb cc dd ...
            "
            _infonoblank "特殊任务名:
            all: 全部卸载，后面不能有任何其他任务名"|column -t
            echo
            _infonoblank "已安装备份任务如下："
            for i in "${installedTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

            _infonoblank "未安装备份任务如下："
            for i in "${notInstalledTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

        elif [ "${2}" == "help" ] && [ -n "${3}" ]; then
            _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -n "${3}" ]; then
            _error "all 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -z "${3}" ]; then
            _info "开始卸载任务"
            if [ "${#installedTask[@]}" -gt 0 ]; then
                for taskName in "${installedTask[@]}"; do
                    ParseYaml "${taskName}"
                    RemoveTask "${taskName}"
                    _success "已卸载任务名: ${taskName}"
                done
                _success "任务卸载完成"
            elif [ "${#installedTask[@]}" -eq 0 ]; then
                _warning "系统中不存在已安装的任务，跳过卸载"
                exit 1
            fi
        else
            needRemoveTaskList=()
            alreadyRemovedTaskList=()
            for i in "${specifiedTaskList[@]}" ; do
                if printf '%s\0' "${installedTask[@]}" | grep -Fxqz -- "${i}"; then
                    mapfile -t -O "${#needRemoveTaskList[@]}" needRemoveTaskList < <(echo "${i}")
                else
                    mapfile -t -O "${#alreadyRemovedTaskList[@]}" alreadyRemovedTaskList < <(echo "${i}")
                fi
            done
            if [ "${#needRemoveTaskList[@]}" -gt 0 ]; then
                _info "开始卸载任务"
                for taskName in "${needRemoveTaskList[@]}"; do
                    ParseYaml "${taskName}"
                    RemoveTask "${taskName}"
                    _success "已卸载任务名: ${taskName}"
                done
                if [ "${#alreadyRemovedTaskList[@]}" -gt 0 ]; then
                    _warning "以下任务当前并未安装，无需在卸载时指定，卸载时将跳过:"
                    for i in "${alreadyRemovedTaskList[@]}" ; do
                        _warningnoblank "${i}"
                    done
                fi
                _success "任务卸载完成"
            else
                _warning "所有指定的任务均未安装，跳过卸载"
                exit 1
            fi
        fi
        # 以下是非root用户专用的将最终定时任务安装进系统定时
        if { [ -n "${2}" ] && [ "${2}" != "help" ]; } && [ "${isNonRootUser}" -eq 1 ]; then
            RebuildCron
        fi
    ;;
    "run")
        if [ "${#specifiedTaskList[@]}" -eq 0 ] || { [ "${2}" == "help" ] && [ -z "${3}" ]; }; then
            echo
            _infonoblank "Tips: 支持单个任务备份或多个任务名同时备份，任务名之间用空格隔开
            例1: $0 run aa
            例2: $0 run aa bb cc dd ...

            备份出来的压缩包格式: [任务名]_-_[表名]_-_[日期].sql.gz
            只要是配置文件中有填写完整信息的任务，无论是否已安装均可执行备份
            "
            _infonoblank "特殊任务名:
            all: 全部运行(所有在配置文件中设置的任务)，后面不能有任何其他任务名"|column -t
            echo
            _infonoblank "已安装备份任务如下："
            for i in "${installedTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

            _infonoblank "未安装备份任务如下："
            for i in "${notInstalledTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

        elif [ "${2}" == "help" ] && [ -n "${3}" ]; then
            _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -n "${3}" ]; then
            _error "all 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -z "${3}" ]; then
            _info "开始执行任务"
            for taskName in "${taskList[@]}"; do
                ParseYaml "${taskName}"
                RunTask "${taskName}"
                DeleteExpiresArchive "${taskName}"
                _success "已执行备份的任务名: ${taskName}"
            done
            _success "任务执行成功"
        else
            _info "开始执行任务"
            for taskName in "${specifiedTaskList[@]}"; do
                ParseYaml "${taskName}"
                RunTask "${taskName}"
                DeleteExpiresArchive "${taskName}"
                _success "已执行备份的任务名: ${taskName}"
            done
            _success "任务执行成功"
        fi
    ;;
    "check")
        if [ "${#specifiedTaskList[@]}" -eq 0 ] || { [ "${2}" == "help" ] && [ -z "${3}" ]; }; then
            echo
            _infonoblank "Tips: 支持单个任务查询配置或多个任务名同时查询配置，任务名之间用空格隔开
            例1: $0 check aa
            例2: $0 check aa bb cc dd ...
            "
            _infonoblank "特殊任务名:
            all: 查询全部任务的配置细节，后面不能有任何其他任务名"|column -t
            echo
            _infonoblank "已安装备份任务如下："
            for i in "${installedTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

            _infonoblank "未安装备份任务如下："
            for i in "${notInstalledTask[@]}" ; do
                _warningnoblank "${i}"
            done
            echo

        elif [ "${2}" == "help" ] && [ -n "${3}" ]; then
            _error "help 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -n "${3}" ]; then
            _error "all 后面禁止添加其他字段，请删除多余字段后重新运行: ${*:3}"
            exit 1
        elif [ "${2}" == "all" ] && [ -z "${3}" ]; then
            _info "开始展示全部任务配置"
            for taskName in "${taskList[@]}"; do
                ParseYaml "${taskName}"
                CheckTask "${taskName}"
            done
        else
            _info "开始依次展示任务配置"
            for taskName in "${specifiedTaskList[@]}"; do
                ParseYaml "${taskName}"
                CheckTask "${taskName}"
            done
        fi
    ;;
    *)
        _error "选项不存在，请查看以下帮助菜单"
        Help
        exit 1
esac



##############################################################################################################################
# 以下是暂时未启用的功能对应的功能模块或暂时弃用的逻辑代码

# 变量初始化
#remoteYQLatestHTML=
#
#dirPath=
#localYQ=


CheckRateLimitDeprecated(){
    :
#    # github有调用API的频率限制，必须先检测
#    # https://docs.github.com/en/rest/overview/resources-in-the-rest-api?apiVersion=2022-11-28#rate-limiting
#    _info "正在检查外网连接情况"
#    if timeout 5s ping -c2 -W1 www.baidu.com > /dev/null 2>&1; then
#        _info "正在检查 github API 调用限制信息"
#        local githubGetRateInfo postLimit postRemaining
#        githubGetRateInfo=$(curl -s https://api.github.com/rate_limit|xargs|grep -o "rate: {.*.}"|sed 's/,/\n/g; s/{/\n/g; s/}/\n/g; s/ \+//g')
#        postLimit=$(echo "${githubGetRateInfo}" | awk -F ':' /^limit/'{print $2}')
#        postRemaining=$(echo "${githubGetRateInfo}" | awk -F ':' /^remaining/'{print $2}')
#        _successnoblank "GitHub 调用速率为 ${postLimit} 次/小时"
#        if [ "${postRemaining}" -eq 0 ]; then
#            _error "$(date +%Y年%m月%d日%k:00) 至 $(date +%Y年%m月%d日%k:00 -d "+1 hour") 时间段内剩余可可查询升级的次数为 ${postRemaining}，请过一小时再尝试升级，退出中"
#            exit 1
#        elif [ "${postRemaining}" -lt 10 ]; then
#            _errornoblank "$(date +%Y年%m月%d日%k:00) 至 $(date +%Y年%m月%d日%k:00 -d "+1 hour") 时间段内剩余可查询升级的次数还剩 ${postRemaining} 次"
#        else
#            _infonoblank "$(date +%Y年%m月%d日%k:00) 至 $(date +%Y年%m月%d日%k:00 -d "+1 hour") 时间段内剩余可可查询升级的次数还剩 ${postRemaining} 次"
#        fi
#        remoteYQLatestHTML="$(curl -s --max-time 15 https://api.github.com/repos/mikefarah/yq/releases/latest)"
#        if [ -z "${remoteYQLatestHTML}" ]; then
#            _error "获取 GitHub API 失败，与 GitHub 连接可能存在问题，请过一会再尝试"
#            exit 1
#        fi
#    else
#	    _error "网络不通，请检查网络，退出中"
#	    exit 1
#    fi
}

CheckUpdateDeprecated(){
    :
#    # 未来更新到网络上再在此模块中添加远程更新sqlbak的方法
#    CheckRateLimit
#    _info "开始解析yq最新版本号并比对本地yq版本(如果存在)"
#    local remoteYQVersion localYQVersion
#    remoteYQVersion=$(echo "${remoteYQLatestHTML}"|grep -o "tag_name.*.\""|awk -F '"' '{print $(NF-1)}')
#    if [ -f "${yqFile}" ]; then
#        if [ ! -x "${yqFile}" ]; then
#            chmod +x "${yqFile}"
#        fi
#        localYQVersion=$(${yqFile} -V|awk '{print $NF}')
#        if [[ ! "${remoteYQVersion}" == "${localYQVersion}" ]]; then
#            _warning "发现新版本yq，开始更新"
#            DownloadYQ
#        else
#            _success "yq已是最新版本，无需更新，跳过"
#        fi
#    else
#        _warning "系统不存在必要解析工具，将检查依赖并试图修复工作环境，修复后请重新运行本工具"
#        CheckDependence "skip"
#        exit 0
#    fi
}

DownloadYQDeprecated() {
    :
#    local yqDownloadLink yqRemoteSize yqLocalSize
#	yqDownloadLink=$(echo "${remoteYQLatestHTML}" | grep "browser_download_url.*.yq_linux_amd64\"" | awk -F '[" ]' '{print $(NF-1)}')
#	yqRemoteSize=$(echo "${remoteYQLatestHTML}" | grep -B 10 "browser_download_url.*.yq_linux_amd64\"" | grep size | awk -F '[ ,]' '{print $(NF-1)}')
#	if [ -z "${yqDownloadLink}" ]; then
#	    _error "无法获取下载链接，请检查网络，退出中"
#	    exit 1
#	else
#	    _info "开始下载并放置yq到系统中"
#	    _warningnoblank "下载链接: ${yqDownloadLink}"
#	    if [ -f "${yqFile}.tmp" ]; then
#	        _warning "发现上次运行时的下载残留，正在清理"
#	        rm -rf "${yqFile}.tmp"
#	    fi
#
#	    if ! curl -L -o "${yqFile}.tmp" "${yqDownloadLink}"; then
#	        _error "下载失败，请重新运行脚本尝试下载"
#	        _error "清理下载残留，退出中"
#	        rm -rf "${yqFile}.tmp"
#	        exit 1
#	    else
#	        _info "开始校验完整性"
#	        yqLocalSize=$(stat --printf="%s" "${yqFile}.tmp")
#	        if [ "${yqLocalSize}" == "${yqRemoteSize}" ]; then
#	            mv -f "${yqFile}.tmp" "${yqFile}"
#	            chmod +x "${yqFile}"
#	            _success "完整性校验通过，下载并更新完成"
#	        else
#	            _error "下载版本和远程版本大小不一致，请重新运行脚本以尝试修正此问题，退出中"
#	            rm -rf "${yqFile}.tmp"
#	            exit 1
#	        fi
#	    fi
#	fi
}

SetConstantAndVariableByCurrentUserBackupDeprecated(){
    :
#    # 这里面是部分弃用代码，别直接用
#    # 找到本工具所在的绝对路径
#    dirPath=$(dirname "$(readlink -f "$0")")
#    localYQ="${dirPath}/yq"
}

CheckDependenceDeprecated(){
    :
#    # 这是模块内的部分代码，暂时弃用，不要直接取消注释，部分变量已经被删
#    if [ ! -f "${yqFile}" ]; then
#	    if [ "${isClassified}" -eq 0 ]; then
#            if [ "${1}" == "skip" ]; then
#                :
#            else
#                CheckRateLimit
#            fi
#            if [ -f "${localYQ}" ]; then
#                [ ! -x "${localYQ}" ] && chmod +x "${localYQ}"
#                if "${localYQ}" -V|awk '{print $NF}' >/dev/null 2>&1; then
#                    _success "系统不存在必要解析工具但本地存在，已处理并安装进系统"
#                    cp -a "${localYQ}" "${binPath}"
#                else
#                    _warning "系统不存在必要解析工具，本地存在的工具已损坏，开始下载yq，若下载过慢可通过组合键CTRL+C中断工具运行"
#                    _warning "之后手动下载并改名成yq放在此处(${dirPath})，系统会自动检测可用性，确认无误将自动安装进系统以跳过下载过程"
#                    rm -rf "${localYQ}"
#                    DownloadYQ
#                fi
#            else
#                _warning "系统和本工具同目录均不存在yq，开始下载yq，若下载过慢可通过组合键CTRL+C中断工具运行"
#                _warning "之后手动下载并改名成yq放在此处(${dirPath})，系统会自动检测可用性，确认无误将自动安装进系统以跳过下载过程"
#                DownloadYQ
#            fi
#        else
#            _error "解析工具yq不存在，程序不会进行任何操作，退出中"
#            exit 1
#        fi
#    fi
#	if [ "${isClassified}" -eq 0 ]; then
#    # 这里这个本地自动覆盖的方式继续保留，未来更新到网络上再在update模块中添加远程更新的方法
#        if [ "${sqlBakFile}" != "$(readlink -f "$0")" ]; then
#            _info "正在更新 sqlbak"
#            cp -af "$(readlink -f "$0")" "${sqlBakFile}"
#            chmod +x "${sqlBakFile}"
#            _success "sqlbak 更新成功"
#        fi
#    fi
#
}