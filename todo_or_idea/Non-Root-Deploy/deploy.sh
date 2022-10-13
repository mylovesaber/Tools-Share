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

# 声明变量及部分初始化

userName=$(whoami)
basePath="$(pwd -P "$0")"
CPUArchitecture=""
globalRemove=0

javaOperation=""
jdkVersion=""
jdkEnabledVersion=""

tomcatOperation=""
tomcatBackupPath=""
tomcatVersion=""
tomcatPort=""

redisOperation=""
redisVersion=""
redisPort=""

mariadbOperation=""
mariadbVersion=""
mariadbPort=""
mariadbUser=""
mariadbPass=""

mysqlOperation=""
mysqlVersion=""
mysqlPort=""
mysqlUser=""
mysqlPass=""

projectOperation=""
projectFrontendName=""
projectBackendName=""
projectName=""
projectChineseName=""
projectDatabaseName=""
projectTomcatVersion=""
projectTomcatPort=""
projectRedisVersion=""
projectRedisPort=""
projectSqlVersion=""
projectSqlPort=""
projectSqlType=""
projectSqlUserName=""
projectSqlUserPassword=""

#################################################################################################
# 配置文件中的参数赋值给变量(检测到用户为root，包括sudo提权的用户也是root，则询问需要安装到哪个用户家目录下，否则默认安装到当前用户家目录下，此版本暂未实装，只适配了非特权用户)

CheckRoot() {
	if [ $EUID = 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) = 0 ]]; then
        _error "暂时不支持 root 用户部署"
        exit 1
	fi
}

ArchitectureDetect(){
    case $(uname -p) in
        "mips64") CPUArchitecture="mips64el";;
        "x86_64") CPUArchitecture="x86_64";;
        *) _error "未知 CPU 架构，请检查"; exit 1
    esac
}

ConfigFileParse(){
    _info "开始检查配置文件参数设置情况"
    if [ ! -f "${basePath}"/deploy.conf ]; then
        _error "配置文件未找到，退出中..."
        exit 1
    fi
    globalRemove=$(awk -F '=' /^global-remove/'{print $2}' deploy.conf)
    if [ "${globalRemove}" != 1 ] && [ "${globalRemove}" != 0 ]; then
        _error "全局卸载参数设置错误，退出中"
        exit 1
    elif [ "${globalRemove}" == 0 ]; then
        # 检查配置文件中组件的工作选项是否有冲突(安装/卸载/重置/升级)
        envKeyWord=("java" "tomcat" "redis" "mariadb" "mysql" "project")
        operationKeyWord=("install" "remove" "update" "reset")
        for i in "${envKeyWord[@]}"; do
            FLAG=0
            finalOperation=""
            for j in "${operationKeyWord[@]}"; do
                returnValue=$(awk -F '=' /^"${i}-${j}"/'{print $2}' deploy.conf)
                if [ "${returnValue}" == 1 ]; then
                    FLAG=$(( FLAG + 1 ))
                    finalOperation=${j}
                elif [ "${returnValue}" == 0 ]; then
                    :
                elif awk -F '=' /^"${i}-${j}"/'{print $2}' deploy.conf; then
                    :
                else
                    echo "组件工作选项只能是 0(不执行) 或 1(执行)"
                   exit 1
                fi
            done
            if [ "${FLAG}" -gt 1 ]; then
                echo "配置文件出错，$i 组件的可选操作: 安装/卸载/重置/升级，只能有一种操作被启用，请检查"
                exit 1
            elif [ "${FLAG}" -eq 1 ]; then
                case $i in
                    "java")javaOperation="$finalOperation";;
                    "tomcat")tomcatOperation="$finalOperation";;
                    "redis")redisOperation="$finalOperation";;
                    "mariadb")mariadbOperation="$finalOperation";;
                    "mysql")mysqlOperation="$finalOperation";;
                    "project")projectOperation="$finalOperation";;
                    *)
                esac
            fi
        done

        # 获取每一个组件的非空工作选项中的每个配置参数
        if [ -n "${javaOperation}" ]; then
            jdkVersion=$(awk -F '=' /^java-version/'{print $2}' deploy.conf)
            jdkEnabledVersion=$(awk -F '=' /^java-enabled-version/'{print $2}' deploy.conf)
        fi
        if [ -n "${tomcatOperation}" ]; then
            tomcatBackupPath=$(awk -F '=' /^tomcat-backup/'{print $2}' deploy.conf)
            tomcatVersion=$(awk -F '=' /^tomcat-version/'{print $2}' deploy.conf)
            tomcatPort=$(awk -F '=' /^tomcat-port/'{print $2}' deploy.conf)
        fi
        if [ -n "${redisOperation}" ]; then
            redisVersion=$(awk -F '=' /^redis-version/'{print $2}' deploy.conf)
            redisPort=$(awk -F '=' /^redis-port/'{print $2}' deploy.conf)
        fi
        if [ -n "${mariadbOperation}" ]; then
            mariadbVersion=$(awk -F '=' /^mariadb-version/'{print $2}' deploy.conf)
            mariadbPort=$(awk -F '=' /^mariadb-port/'{print $2}' deploy.conf)
            mariadbUser=$(awk -F '=' /^mariadb-user/'{print $2}' deploy.conf)
            mariadbPass=$(awk -F '=' /^mariadb-password/'{print $2}' deploy.conf)
        fi
        # if [ -n "${mysqlOperation}" ]; then
        #     mysqlVersion=$(awk -F '=' /^mysql-version/'{print $2}' deploy.conf)
        #     mysqlPort=$(awk -F '=' /^mysql-port/'{print $2}' deploy.conf)
        #     mysqlUser=$(awk -F '=' /^mysql-user/'{print $2}' deploy.conf)
        #     mysqlPass=$(awk -F '=' /^mysql-password/'{print $2}' deploy.conf)
        # fi
        if [ -n "${projectOperation}" ]; then
            projectFrontendName=$(awk -F '=' /^project-frontend-name/'{print $2}' deploy.conf)
            projectBackendName=$(awk -F '=' /^project-backend-name/'{print $2}' deploy.conf)
            projectName=$(awk -F '=' /^project-name/'{print $2}' deploy.conf)
            projectChineseName=$(awk -F '=' /^project-chinese-name/'{print $2}' deploy.conf)
            projectDatabaseName=$(awk -F '=' /^project-database-name/'{print $2}' deploy.conf)
            projectTomcatVersion=$(awk -F '=' /^project-tomcat-version/'{print $2}' deploy.conf)
            projectTomcatPort=$(awk -F '=' /^project-tomcat-port/'{print $2}' deploy.conf)
            projectRedisVersion=$(awk -F '=' /^project-redis-version/'{print $2}' deploy.conf)
            projectRedisPort=$(awk -F '=' /^project-redis-port/'{print $2}' deploy.conf)
            projectSqlVersion=$(awk -F '=' /^project-sql-version/'{print $2}' deploy.conf)
            projectSqlPort=$(awk -F '=' /^project-sql-port/'{print $2}' deploy.conf)
            projectSqlType=$(awk -F '=' /^project-sql-type/'{print $2}' deploy.conf)
            projectSqlUserName=$(awk -F '=' /^project-sql-user-name/'{print $2}' deploy.conf)
            projectSqlUserPassword=$(awk -F '=' /^project-sql-user-password/'{print $2}' deploy.conf)
        fi
        # errorPortNumber=()
        # for i in "${PORT_NUMBER[@]}"; do
        #     if [[ ! "${i}" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
        #         errorPortNumber+=("$i")
        #     fi
        # done
        # if [ "${#errorPortNumber[@]}" -gt 0 ]; then
        #     _error "需部署的端口号写法有错，"
        #     _error "以下是全部错误端口号，请检查:"
        #     for i in "${errorPortNumber[@]}"; do
        #         echo "$i"
        #     done
        #     exit 1
        # fi
    fi
}



#################################################################################################
# 各模块安装和配置
Non-RootPrepare(){
    _info "开始环境准备工作"
    if ! grep ". ~/.env/\*_enabled$" ~/.bashrc >/dev/null; then
        echo ". ~/.env/*_enabled" >> ~/.bashrc
    fi
    [ ! -d /home/"${userName}"/.local/share ] && mkdir -p /home/"${userName}"/.local/share
    [ ! -d /home/"${userName}"/.config/systemd/user ] && mkdir -p /home/"${userName}"/.config/systemd/user
    [ ! -d /home/"${userName}"/.cache/run ] && mkdir -p /home/"${userName}"/.cache/run
    [ ! -d /home/"${userName}"/.env ] && mkdir -p /home/"${userName}"/.env
    sed -i '/XDG_RUNTIME_DIR/d' /home/"${userName}"/.bashrc
    echo "export XDG_RUNTIME_DIR=/run/user/\$(id -ru)" >> /home/"${userName}"/.bashrc
    source /home/"${userName}"/.bashrc
    _success "环境准备工作完成"
}

Non-RootJavaDeploy(){
    _info "正在部署 Java"
    [ ! -d /home/"${userName}"/.local/share/java ] && mkdir -p /home/"${userName}"/.local/share/java
    cp -a "${basePath}"/program/java/${CPUArchitecture}/jdk-"${jdkVersion}" /home/"${userName}"/.local/share/java/
    rm -rf /home/"${userName}"/.local/share/java/jdk
    ln -s /home/"${userName}"/.local/share/java/jdk-"${jdkEnabledVersion}" /home/"${userName}"/.local/share/java/jdk
}

Non-RootJavaConfigure(){
    cat << EOF > /home/"${userName}"/.env/java_enabled
export JAVA_HOME=/home/${userName}/.local/share/java/jdk
export JRE_HOME=/home/${userName}/.local/share/java/jdk/jre
export CLASSPATH=.:\$CLASSPATH:\$JAVA_HOME/lib:\$JRE_HOME/lib
export PATH=\$PATH:\$JAVA_HOME/bin:\$JRE_HOME/bin
EOF
    source /home/"${userName}"/.bashrc
    if /home/"${userName}"/.local/share/java/jdk/bin/java -version >/dev/null 2>&1; then
        _success "Java 部署完成"
    else
        _error "Java 部署失败"
        exit 1
    fi
}

# Tomcat
Non-RootTomcatDeploy(){
    _info "正在部署 Tomcat"
    [ ! -d /home/"${userName}"/.local/share/tomcat/ ] && mkdir -p /home/"${userName}"/.local/share/tomcat
    cp -a "${basePath}"/program/tomcat/"${CPUArchitecture}"/tomcat-"${tomcatVersion}" /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"
}

Non-RootTomcatConfigure(){
    cp -a /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/conf/server.xml.default /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/conf/server.xml
    sed -i "s/TOMCATPORT/${tomcatPort}/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/conf/server.xml
    cat << EOF > /home/"${userName}"/.config/systemd/user/tomcat-"${tomcatVersion}"-"${tomcatPort}".service 
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}
Environment="JAVA_HOME=/home/${userName}/.local/share/java/jdk"
Environment="CATALINA_PID=/home/${userName}/.cache/run/tomcat-${tomcatVersion}-${tomcatPort}.pid"
ExecStart=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}/bin/startup.sh
ExecStop=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}/bin/shutdown.sh
Restart=always

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    tomcatIsActive=$(systemctl --user is-active tomcat-"${tomcatVersion}"-"${tomcatPort}".service)
    if [ "${tomcatIsActive}" = "active" ]; then
        systemctl --user stop tomcat-"${tomcatVersion}"-"${tomcatPort}".service
        systemctl --user disable tomcat-"${tomcatVersion}"-"${tomcatPort}".service
    elif [ -f /home/"${userName}"/.cache/run/tomcat-"${tomcatVersion}"-"${tomcatPort}".pid ]; then
        pkill -F /home/"${userName}"/.cache/run/tomcat-"${tomcatVersion}"-"${tomcatPort}".pid
    elif pgrep -f tomcat-"${tomcatVersion}"-"${tomcatPort}" >/dev/null 2>&1; then
        kill "$(pgrep -f tomcat-"${tomcatVersion}"-"${tomcatPort}")"
    fi
    systemctl --user start tomcat-"${tomcatVersion}"-"${tomcatPort}".service 1>& /dev/null
    systemctl --user stop tomcat-"${tomcatVersion}"-"${tomcatPort}".service 1>& /dev/null
    cat << EOF > /home/"${userName}"/.config/systemd/user/tomcat-"${tomcatVersion}"-"${tomcatPort}".service 
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}
Environment="JAVA_HOME=/home/${userName}/.local/share/java/jdk"
Environment="CATALINA_PID=/home/${userName}/.cache/run/tomcat-${tomcatVersion}-${tomcatPort}.pid"
ExecStartPre=/bin/rm -rf /home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}/logs/catalina.out
ExecStart=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}/bin/startup.sh
ExecStop=/home/${userName}/.local/share/tomcat/tomcat-${tomcatVersion}-${tomcatPort}/bin/shutdown.sh
Restart=always

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable tomcat-"${tomcatVersion}"-"${tomcatPort}".service --now 1>& /dev/null
    tomcatIsActive=$(systemctl --user is-active tomcat-"${tomcatVersion}"-"${tomcatPort}".service)
    if [ "${tomcatIsActive}" = "active" ]; then
        _success "Tomcat 部署完成"
    else
        _error "Tomcat 部署失败"
        exit 1
    fi
}

Non-RootTomcatCheckStatus(){
    cat << EOF > /home/"${userName}"/checkstatus
EOF

}

# Redis
Non-RootRedisDeploy(){
    _info "正在部署 Redis"
    [ ! -d /home/"${userName}"/.local/share/redis/ ] && mkdir -p /home/"${userName}"/.local/share/redis
    cp -a "${basePath}"/program/redis/"${CPUArchitecture}"/redis-"${redisVersion}" /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"
}

Non-RootRedisConfigure(){
    cp -a /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"/redis.conf.default /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"/redis.conf
    sed -i "s/REDISPORT/${redisPort}/g" /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"/redis.conf
    sed -i "s/PIDFILEPATH/\/home\/${userName}\/.cache\/run\/redis-${redisVersion}-${redisPort}.pid/g" /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"/redis.conf
    sed -i "s/DUMPRDBPATH/\/home\/${userName}\/.local\/share\/redis\/redis-${redisVersion}-${redisPort}\//g" /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}"/redis.conf
    cat << EOF > /home/"${userName}"/.config/systemd/user/redis-"${redisVersion}"-"${redisPort}".service 
[Unit]
Description=Redis
After=syslog.target network.target

[Service]
Type=notify
TimeoutStartSec=60s
TimeoutStopSec=60s
ExecStart=/home/${userName}/.local/share/redis/redis-${redisVersion}-${redisPort}/redis-server /home/${userName}/.local/share/redis/redis-${redisVersion}-${redisPort}/redis.conf --supervised systemd
ExecStop=/home/${userName}/.local/share/redis/redis-${redisVersion}-${redisPort}/redis-cli shutdown
Restart=always

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    redisIsActive=$(systemctl --user is-active redis-"${redisVersion}"-"${redisPort}".service)
    if [ "${redisIsActive}" = "active" ]; then
        systemctl --user stop redis-"${redisVersion}"-"${redisPort}".service
        systemctl --user disable redis-"${redisVersion}"-"${redisPort}".service
    elif [ -f /home/"${userName}"/.cache/run/redis-"${redisVersion}"-"${redisPort}".pid ]; then
        pkill -F /home/"${userName}"/.cache/run/redis-"${redisVersion}"-"${redisPort}".pid
    elif pgrep -f redis-"${redisVersion}"-"${redisVersion}" >/dev/null 2>&1; then
        kill "$(pgrep -f redis-"${redisVersion}"-"${redisVersion}")"
    fi
    systemctl --user enable redis-"${redisVersion}"-"${redisPort}".service --now 1>& /dev/null
    redisIsActive=$(systemctl --user is-active redis-"${redisVersion}"-"${redisPort}".service)
    if [ "${redisIsActive}" = "active" ]; then
        _success "Redis 部署完成"
    else
        _error "Redis 部署失败"
        exit 1
    fi
}

Non-RootMariadbDeploy(){
    _info "正在部署 Mariadb，文件体积庞大，需耐心等待"
    if pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" >/dev/null 2>&1; then
        _warning "发现残留 Mariadb 进程，开始销毁"
        pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" | xargs kill
        sleep 5s
        _success "销毁完成"
    fi
    _info "开始放置数据库文件"
    [ ! -d /home/"${userName}"/.local/share/mariadb/ ] && mkdir -p /home/"${userName}"/.local/share/mariadb
    cp -a "${basePath}"/program/mariadb/"${CPUArchitecture}"/mariadb-"${mariadbVersion}" /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"
    _success "数据库文件放置完成"
}

Non-RootMariadbConfigure(){
    cp -a /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf.default /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf
    sed -i "s/MARIADBPORT/${mariadbPort}/g" /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf
    sed -i "s/DATADIRPATH/\/home\/${userName}\/.local\/share\/mariadb\/mariadb-${mariadbVersion}-${mariadbPort}\/data/g" /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf
    sed -i "s/PIDFILEPATH/\/home\/${userName}\/.cache\/run\/mariadb-${mariadbVersion}-${mariadbPort}.pid/g" /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf
    sed -i "s/LANGUAGEPATH/\/home\/${userName}\/.local\/share\/mariadb\/mariadb-${mariadbVersion}-${mariadbPort}\/share\/english/g" /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf
    _info "开始初始化数据库"
    /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/scripts/mysql_install_db /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf 1>/dev/null
    _success "数据库初始化完成"
    _info "开始创建临时进程"
    /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/bin/mariadbd --defaults-file=/home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/config/my.cnf --skip-grant-tables &
    sleep 5s
    _success "临时进程创建成功"
    _info "开始创建 root 用户"
    /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}"/bin/mariadb << EOF
flush privileges;
drop user '${mariadbUser}'@'localhost';
create user '${mariadbUser}'@'localhost' identified by '${mariadbPass}';
GRANT ALL PRIVILEGES ON *.* TO '${mariadbUser}'@'localhost' WITH GRANT OPTION;
flush privileges;
EOF
    _success "root 用户创建成功"
    _info "开始销毁临时进程"
    if pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" >/dev/null 2>&1; then
        pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" | xargs kill
        sleep 5s
    fi
    _success "临时进程销毁完成"
    _info "开始装配自启动服务"
    cat << EOF > /home/"${userName}"/.config/systemd/user/mariadb-"${mariadbVersion}"-"${mariadbPort}".service 
[Unit]
Description=Mariadb
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=/home/${userName}/.local/share/mariadb/mariadb-${mariadbVersion}-${mariadbPort}
ExecStart=/bin/bash -c "/home/${userName}/.local/share/mariadb/mariadb-${mariadbVersion}-${mariadbPort}/bin/mysqld --defaults-file=/home/${userName}/.local/share/mariadb/mariadb-${mariadbVersion}-${mariadbPort}/config/my.cnf &"
ExecStop=/home/${userName}/.local/share/mariadb/mariadb-${mariadbVersion}-${mariadbPort}/bin/mariadb-admin shutdown -u ${mariadbUser} -p${mariadbPass}

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    redisIsActive=$(systemctl --user is-active mariadb-"${mariadbVersion}"-"${mariadbPort}".service)
    if [ "${redisIsActive}" = "active" ]; then
        systemctl --user stop mariadb-"${mariadbVersion}"-"${mariadbPort}".service
        systemctl --user disable mariadb-"${mariadbVersion}"-"${mariadbPort}".service
    elif [ -f /home/"${userName}"/.cache/run/mariadb-"${mariadbVersion}"-"${mariadbPort}".pid ]; then
        pkill -F /home/"${userName}"/.cache/run/mariadb-"${mariadbVersion}"-"${mariadbPort}".pid
    elif pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" >/dev/null 2>&1; then
        pgrep -f mariadb-"${mariadbVersion}"-"${mariadbPort}" | xargs kill
    fi
    systemctl --user enable mariadb-"${mariadbVersion}"-"${mariadbPort}".service --now 1>& /dev/null
    redisIsActive=$(systemctl --user is-active mariadb-"${mariadbVersion}"-"${mariadbPort}".service)
    if [ "${redisIsActive}" = "active" ]; then
        _success "Mariadb 部署完成"
    else
        _error "Mariadb 部署失败"
        exit 1
    fi
}

Non-RootMysqlDeploy(){
    date
}

Non-RootMysqlConfigure(){
    date
}

Non-RootProjectDeploy(){
    _info "开始部署项目"
    systemctl --user stop tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}".service
    systemctl --user stop redis-"${projectRedisVersion}"-"${projectRedisPort}".service

    # 复制前后端包和图标桌面快捷方式到指定路径下
    _info "正在放置项目文件"
    [ -d "${basePath}"/program/project/frontend/"${projectFrontendName}" ] && cp -a "${basePath}"/program/project/frontend/"${projectFrontendName}" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/webapps
    [ -d "${basePath}"/program/project/backend/"${projectBackendName}" ] && cp -a "${basePath}"/program/project/backend/"${projectBackendName}" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/webapps
    [ -f "${basePath}"/program/project/"${projectName}".svg ] && cp -a "${basePath}"/program/project/"${projectName}".svg /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf
    [ -f "${basePath}"/program/project/"${projectName}".desktop ] && cp -a "${basePath}"/program/project/"${projectName}".desktop /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf
    _success "项目文件放置完成"
    
    # 桌面图标配置
    _info "开始生成项目桌面快捷方式"
    sed -i "s/PROJECTICONPATH/\/home\/${userName}\/\.local\/share\/tomcat\/tomcat-${projectTomcatVersion}-${projectTomcatPort}\/conf\/${projectName}\.svg/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop
    sed -i "s/TOMCATPORT/${projectTomcatPort}/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop
    sed -i "s/PROJECTFRONTENDNAME/${projectFrontendName}/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop
    sed -i "s/PROJECTCNNAME/${projectChineseName}/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop
    if [ ! -d /home/"${userName}"/桌面 ]; then
        mkdir -p /home/"${userName}"/桌面
    fi
    chmod 755 /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop
    [ -f /home/"${userName}"/桌面/"${projectName}".desktop ] && rm -rf /home/"${userName}"/桌面/"${projectName}".desktop
    ln /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/"${projectName}".desktop /home/"${userName}"/桌面
    _success "项目桌面快捷方式已生成"

    # 导入 SQL 文件
    _info "正在导入数据库，请耐心等待"
    /home/"${userName}"/.local/share/"${projectSqlType}"/"${projectSqlType}"-"${projectSqlVersion}"-"${projectSqlPort}"/bin/"${projectSqlType}" -u"${projectSqlUserName}" -p"${projectSqlUserPassword}" <<EOF
CREATE DATABASE IF NOT EXISTS ${projectDatabaseName};
EOF
    if ! /home/"${userName}"/.local/share/"${projectSqlType}"/"${projectSqlType}"-"${projectSqlVersion}"-"${projectSqlPort}"/bin/"${projectSqlType}" -u"${projectSqlUserName}" -p"${projectSqlUserPassword}" "${projectDatabaseName}" < "${basePath}"/program/project/"${projectName}".sql; then
        _error "数据库导入出现问题，请检查，退出中"
        exit 1
    fi
    _success "数据库导入成功"

    # 针对项目logback-spring.xml中的路径进行修改
    _info "调整项目配置"
    mkdir -p /home/"${userName}"/"${projectBackendName}"/log/{error,info}
    sed -i "s/LOGBACKPATH/\/home\/${userName}\/${projectBackendName}/g" /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/webapps/"${projectBackendName}"/WEB-INF/classes/config/logback-spring.xml
    echo "/home/${userName}/${projectBackendName}" > /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/desktop-path
    systemctl --user start tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}".service
    systemctl --user start redis-"${projectRedisVersion}"-"${projectRedisPort}".service
    _success "项目部署成功"
}

Non-RootGlobalRemove(){
    _info "开始全局卸载"
    if [ -d /home/"${userName}"/.local/share/java ]; then
        rm -rf /home/"${userName}"/.local/share/java
        sed -i '/env\/\*_enabled/d' ~/.bashrc
        rm -rf /home/"${userName}"/.env
    fi
    if [ -d /home/"${userName}"/.config/systemd/user ]; then
        mapfile -t serviceList < <(find /home/"${userName}"/.config/systemd/user -type f -name "*service"|awk -F '/' '{print $NF}')
        if [ "${#serviceList[@]}" -ne 0 ]; then
            for i in "${serviceList[@]}"; do
                systemctl --user stop "$i"
                systemctl --user disable "$i"  1>& /dev/null
            done
            rm -rf /home/"${userName}"/.config/systemd/user/*
            systemctl --user daemon-reload
        fi
    fi
    [ -d /home/"${userName}"/.local/share/tomcat ] && rm -rf /home/"${userName}"/.local/share/tomcat
    [ -d /home/"${userName}"/.local/share/redis ] && rm -rf /home/"${userName}"/.local/share/redis
    [ -d /home/"${userName}"/.local/share/mariadb ] && rm -rf /home/"${userName}"/.local/share/mariadb
    [ -d /home/"${userName}"/.local/share/mysql ] && rm -rf /home/"${userName}"/.local/share/mysql
    cat /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/desktop-path
    rm -ri "$(cat /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/desktop-path)"
    [ -f /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/desktop-path ] && echo "存在残留文件" && rm -rf "$(cat /home/"${userName}"/.local/share/tomcat/tomcat-"${projectTomcatVersion}"-"${projectTomcatPort}"/conf/desktop-path)"
    [ -f /home/"${userName}"/桌面/"${projectName}".desktop ] && rm -rf /home/"${userName}"/桌面/"${projectName}".desktop
    _success "全局卸载完成"
}

Main(){
    # 检测流程
    ArchitectureDetect
    CheckRoot
    ConfigFileParse

    # 配置流程
    if [ "${globalRemove}" == 1 ]; then
        Non-RootGlobalRemove
        exit 0
    fi

    Non-RootPrepare

    case "${javaOperation}" in
        "install")
            if [ ! -d /home/"${userName}"/.local/share/java/jdk-"${jdkVersion}" ]; then
                Non-RootJavaDeploy
                Non-RootJavaConfigure
            else
                _success "Java ${jdkVersion} 已安装，跳过"
            fi
            ;;
        "remove")_warning "卸载暂未适配，跳过";;
        "update")_warning "升级暂未适配，跳过";;
        "reset")_warning "重置暂未适配，跳过";;
        *)
    esac

    case "${tomcatOperation}" in
        "install")
            if [ ! -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}" ]; then
                Non-RootTomcatDeploy
                Non-RootTomcatConfigure
            else
                _success "Tomcat 版本号: ${tomcatVersion},端口号: ${tomcatPort} 已安装，跳过"
            fi
            ;;
        "remove")_warning "卸载暂未适配，跳过";;
        "update")_warning "升级暂未适配，跳过";;
        "reset")_warning "重置暂未适配，跳过";;
        *)
    esac

    case "${redisOperation}" in
        "install")
            if [ ! -d /home/"${userName}"/.local/share/redis/redis-"${redisVersion}"-"${redisPort}" ]; then
                Non-RootRedisDeploy
                Non-RootRedisConfigure
            else
                _success "Redis 版本号: ${redisVersion},端口号: ${redisPort} 已安装，跳过"
            fi
            ;;
        "remove")_warning "卸载暂未适配，跳过";;
        "update")_warning "升级暂未适配，跳过";;
        "reset")_warning "重置暂未适配，跳过";;
        *)
    esac

    case "${mariadbOperation}" in
        "install")
            if [ ! -d /home/"${userName}"/.local/share/mariadb/mariadb-"${mariadbVersion}"-"${mariadbPort}" ]; then
            Non-RootMariadbDeploy
            Non-RootMariadbConfigure
            else
                _success "MariaDB 版本号: ${mariadbVersion},端口号: ${mariadbPort} 已安装，跳过"
            fi
            ;;
        "remove")_warning "卸载暂未适配，跳过";;
        "update")_warning "升级暂未适配，跳过";;
        "reset")_warning "重置暂未适配，跳过";;
        *)
    esac

    # case "${mysqlOperation}" in
    #     "install")_warning "安装暂未适配，跳过";;
    #         # Non-RootMysqlDeploy
    #         # Non-RootMysqlConfigure
    #         # ;;
    #     "remove")_warning "卸载暂未适配，跳过";;
    #     "update")_warning "升级暂未适配，跳过";;
    #     "reset")_warning "重置暂未适配，跳过";;
    #     *)
    # esac

    case "${projectOperation}" in
        "install")
            if [ ! -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectFrontendName}" ] && [ ! -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectBackendName}" ]; then
                Non-RootProjectDeploy
            elif [ -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectFrontendName}" ] && [ -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectBackendName}" ]; then
                _success "项目前后端包已安装，跳过"
            elif [ -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectFrontendName}" ]; then
                _warning "发现残留前端包，即将清理后重新部署"
                rm -rf /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectFrontendName}"
                Non-RootProjectDeploy
            elif [ -d /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectBackendName}" ]; then
                _warning "发现残留后端包，即将清理后重新部署"
                rm -rf /home/"${userName}"/.local/share/tomcat/tomcat-"${tomcatVersion}"-"${tomcatPort}"/webapps/"${projectBackendName}"
                Non-RootProjectDeploy
            fi
            ;;
        "remove")_warning "卸载暂未适配，跳过";;
        "update")_warning "升级暂未适配，跳过";;
        "reset")_warning "重置暂未适配，跳过";;
        *)
    esac
    # 这里测试没问题了再写清理program文件夹的功能
    #rm -rf program* deploy.sh
}

Main


