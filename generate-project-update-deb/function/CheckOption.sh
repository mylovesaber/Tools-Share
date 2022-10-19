#!/bin/bash
GetValue(){
    awk /^"$1"/'{print $0}' generate-deb.conf|cut -d'=' -f 2-|sed -e 's/^"//g;s/"$//g'
}

packageDeployPath=$(GetValue "package-deploy-path")
packageSkip=$(GetValue "package-skip")
packageSection=$(GetValue "package-section")
packagePriority=$(GetValue "package-priority")
packageMaintainer=$(GetValue "package-maintainer")
packageHomepage=$(GetValue "package-homepage")
packageName=$(GetValue "package-name")
packageArchitecture=$(GetValue "package-architecture")
packageDepends=$(GetValue "package-depends")
packageDescription=$(GetValue "package-description")
packageMoreDescription=$(GetValue "package-more-description")
packageVersion=$(GetValue "package-version")
packageSource=$(GetValue "package-source")
tomcatSkip=$(GetValue "tomcat-skip")
tomcatIntegrityCheckSkip=$(GetValue "tomcat-integrity-check-skip")
tomcatVersion=$(GetValue "tomcat-version")
excludeJar=$(GetValue "exclude-jar")
catalinaOption=$(GetValue "catalina-option")
mysqlSkip=$(GetValue "mysql-skip")
mysqlUsername=$(GetValue "mysql-username")
mysqlPassword=$(GetValue "mysql-password")
mysqlBinPath=$(GetValue "mysql-bin-path")
sqlFileName=$(GetValue "sql-file-name")
dependenciesInstalled=$(GetValue "dependencies-installed")
commonDate=$(GetValue "common-date")
needClean=$(GetValue "need-clean")
databaseBaseName=$(GetValue "database-base-name")
databaseOldName=$(GetValue "database-old-name")
tomcatNewPort=$(GetValue "tomcat-new-port")
tomcatPreviousPort=$(GetValue "tomcat-previous-port")

# [General]
# package-deploy-path
if [ -z "$packageDeployPath" ]; then
    _error "部署到的项目所在家目录不存在，请指定"
    exit 1
else
    packageDeployPath=$(sed 's/\/$//g' <<< "$packageDeployPath")
fi

# common-date
if ! date -d "$commonDate" +%Y%m%d >/dev/null 2>&1; then
    _error "日期格式错误，请重新输入，例: 20220101"
    exit 1
fi

# need-clean
if [ "$needClean" != 0 ] && [ "$needClean" != 1 ] && [ "$needClean" != 2 ]; then
    _error "是否清空打包环境参数填写错误，请根据以下介绍重新填写:"
    _warningnoblank "
    0 不清空
    1 清空所有
    2 保留下载的Tomcat压缩包和解压包"|column -t
    exit 1
fi

# [Package]
# package-skip
if [ "$packageSkip" -eq 0 ]; then
    if
    [ -z "$packageSection" ] ||
    [ -z "$packagePriority" ] ||
    [ -z "$packageMaintainer" ] ||
    [ -z "$packageHomepage" ] ||
    [ -z "$packageName" ] ||
    [ -z "$packageDescription" ] ||
    [ -z "$packageMoreDescription" ] ||
    [ -z "$packageVersion" ] ||
    [ -z "$packageSource" ]; then
        _error "启用打包功能后，以下选项必须填写对应参数："
        _warningnoblank "
        package-section debian包的分类名
        package-priority 软件包的优先级名称
        package-maintainer 维护者和对应邮箱
        package-homepage 打包者的网址
        package-name 安装后的系统包名
        package-description 对安装包的介绍信息
        package-more-description 对安装包的更多介绍信息
        package-version 安装包的版本号
        package-source 源代码包名"|column -t
        _error "退出中"
        exit 1
    fi

    # package-section
    # 预设值参考: https://www.debian.org/doc/debian-policy/ch-archive.html#s-subsections
    isContained=0
    sectionList=("admin" "cli-mono" "comm" "database" "debug" "devel" "doc" "editors" "education" "electronics" "embedded" "fonts" "games" "gnome" "gnu-r" "gnustep" "graphics" "hamradio" "haskell" "httpd" "interpreters" "introspection" "java" "javascript" "kde" "kernel" "libdevel" "libs" "lisp" "localization" "mail" "math" "metapackages" "misc" "net" "news" "ocaml" "oldlibs" "otherosfs" "perl" "php" "python" "ruby" "rust" "science" "shells" "sound" "tasks" "tex" "text" "utils" "vcs" "video" "web" "x11" "xfce" "zope")
    for i in "${sectionList[@]}"; do
        if [ "$i" != "$packageSection" ]; then
            continue
        else
            isContained=1
            break
        fi
    done
    if [ "$isContained" -eq 0 ]; then
        _error "debian 分类名不在可用列表中，以下是可用的所有分类名:"
        _warning "admin cli-mono comm database debug devel doc editors education electronics embedded fonts games gnome gnu-r gnustep graphics hamradio haskell httpd interpreters introspection java javascript kde kernel libdevel libs lisp localization mail math metapackages misc net news ocaml oldlibs otherosfs perl php python ruby rust science shells sound tasks tex text utils vcs video web x11 xfce zope"
        exit 1
    fi

    # package-priority
    isContained=0
    priorityList=("required" "important" "standard" "optional")
    for i in "${priorityList[@]}"; do
        if [ "$i" != "$packagePriority" ]; then
            continue
        else
            isContained=1
            break
        fi
    done
    if [ "$isContained" -eq 0 ]; then
        _error "软件包的优先级名称不在可用列表中，以下是可用的所有分类名:"
        _warning "required important standard optional"
        exit 1
    fi

    # package-maintainer
    # package-homepage
    # package-name
    # package-description
    # package-more-description
    # package-source
    # 以上这些选项参数好像没什么合适的检查规则


    # package-version
    if [[ ! "$packageVersion" =~ ^[0-9.]*\.[0-9]$ ]]; then
        _error "版本号格式出错，只允许数字和英文点组合"
        exit 1
    fi

    # package-depends
    if [ -z "$packageDepends" ]; then
        packageDepends="\${shlibs:Depends}, \${misc:Depends}"
    else
        packageDepends=$(sed 's/^/\\\${shlibs:Depends}, \\\${misc:Depends}, /g' <<< "$packageDepends")
    fi

    # package-architecture
    # 可供参考: https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-architecture
    if [ -z "$packageArchitecture" ]; then
        packageArchitecture=$CPUArchitecture
    elif [ "$packageArchitecture" = "all" ] || [ "$packageArchitecture" = "any" ] || [ "$packageArchitecture" = "$CPUArchitecture" ]; then
        :
    else
        _error "适应的架构填写错误，可填写的值为:"
        _warningnoblank "
        本机($CPUArchitecture)
        debian 支持的所有硬件架构(any)
        与体系结构无关的包(all)
        源码包(source)
        debian 支持的具体硬件架构名(命令: dpkg-architecture -L)
        "
        exit 1
    fi
fi

# [Tomcat]
# tomcat-skip
if [ "$tomcatSkip" -eq 0 ]; then
    if
    [ -z "$tomcatVersion" ] ||
    [ -z "$excludeJar" ] ||
    [ -z "$catalinaOption" ] ||
    [ -z "$tomcatNewPort" ] ||
    [ -z "$tomcatPreviousPort" ] ||
    [ -z "$tomcatIntegrityCheckSkip" ]; then
        _error "启用配置 Tomcat 功能后，以下选项必须填写对应参数："
        _warningnoblank "
        tomcat-version 需要配置或下载的Tomcat的版本号
        exclude-jar 需要添加的jar包排除项
        catalina-option 其他catalina调试选项
        tomcat-new-port 需要新建的Tomcat端口号
        tomcat-previous-port 上一版本的Tomcat端口号
        tomcat-integrity-check-skip 联网校验Tomcat压缩包的完整性"|column -t
        _error "退出中"
        exit 1
    fi
    # tomcat-version
    # tomcat-integrity-check-skip
    tomcatFirstVersionNumber=$(awk -F '.' '{print $1}' <<< "$tomcatVersion")
    if [ "$tomcatIntegrityCheckSkip" != 0 ] && [ "$tomcatIntegrityCheckSkip" != 1 ]; then
        _error "联网校验 Tomcat 压缩包完整性选项的参数设置错误，0 为校验，1 为不校验"
        exit 1
    fi
    if [ -f build/apache-tomcat-"$tomcatVersion".tar.gz ]; then
        _success "已找到 $tomcatVersion 版本的 Tomcat 压缩包"
        if [ "$tomcatIntegrityCheckSkip" == 0 ]; then
            _info "开始检查与 Tomcat 官网的连接性"
            if ! timeout 10s ping -c2 -W1 archive.apache.org > /dev/null 2>&1; then
                _error "无法连接 Tomcat 官网，请检查网络连接，退出中"
                exit 1
            else
                if [ "$(curl -LIs -o /dev/null -w "%{http_code}" https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz.sha512)" == 200 ]; then
                    _success "指定版本的 Tomcat 可供校验完整性"
                    remoteSHA512Sum=$(curl https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz.sha512|cut -d' ' -f1)
                    localSHA512Sum=$(sha512sum build/apache-tomcat-"$tomcatVersion".tar.gz|cut -d' ' -f1)
                    if [ "$remoteSHA512Sum" = "$localSHA512Sum" ]; then
                        _success "本地存在的 $tomcatVersion 版本 Tomcat 压缩包完整性校验通过"
                    else
                        _error "本地存在的 $tomcatVersion 版本 Tomcat 压缩包完整性校验失败，将删除本地压缩包并在下次确认打包时重新下载校验，退出中"
                        exit 1
                    fi
                else
                    _error "无法获取指定版本 Tomcat 的校验值，请检查版本号是否指定错误"
                    exit 1
                fi
            fi
        fi
    fi
    if [ ! -f build/apache-tomcat-"$tomcatVersion".tar.gz ]; then
        _warning "未下载此版本的 Tomcat 压缩包，将从网络中获取"
        _info "开始检查与 Tomcat 官网的连接性"
        if ! timeout 10s ping -c2 -W1 archive.apache.org > /dev/null 2>&1; then
            _error "无法连接 Tomcat 官网，请检查网络连接，退出中"
            exit 1
        else
            if [ "$(curl -LIs -o /dev/null -w "%{http_code}" https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz)" == 200 ]; then
                _success "指定版本的 Tomcat 可供下载"
            else
                _error "无法获取指定版本的 Tomcat，请检查版本号是否指定错误"
                exit 1
            fi
        fi
    fi

    # exclude-jar(整形成 sed 可以直接用的写法)
    excludeJar=$(sed -e 's/^/\\n/g; s/$/,\\\\/g; s/ /,\\\\ \\n/g' <<< "$excludeJar")

    # catalina-option
    catalinaOption=$(sed -e "s/^\'//g; s/\'$//g;" <<< "$catalinaOption")

    # tomcat-new-port
    if [[ ! "$tomcatNewPort" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
        _error "需要新建的 Tomcat 端口号超出范围"
        exit 1
    fi
    # tomcat-previous-port
    if [[ ! "$tomcatPreviousPort" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
        _error "上一个版本更新包的 Tomcat 端口号超出范围"
        exit 1
    fi
    if [ "$tomcatNewPort" = "$tomcatPreviousPort" ]; then
        _error "需要新建的 Tomcat 端口号不能和上一个版本更新包的端口号相同"
        exit 1
    fi
fi

# [Mysql]
# mysql-skip
if [ "$mysqlSkip" -eq 0 ]; then
    if
    [ -z "$dependenciesInstalled" ] ||
    [ -z "$sqlFileName" ]; then
        _error "启用配置 Mysql 功能后，以下选项必须填写对应参数："
        _warningnoblank "
        dependencies-installed 更新包所依赖的基础包是否安装
        sql-file-name 要导入的sql文件名"|column -t
        _error "退出中"
        exit 1
    fi

    # sql-file-name
    if [ ! -f source/"$sqlFileName" ]; then
        _error "SQL 文件不存在，请将 SQL 文件放到 source 文件夹下"
        exit 1
    fi

    # dependencies-installed
    if [ "$dependenciesInstalled" -eq 1 ]; then
        if
        [ -z "$mysqlUsername" ] ||
        [ -z "$mysqlPassword" ] ||
        [ -z "$databaseOldName" ] ||
        [ -z "$databaseBaseName" ]; then
            _error "根据依赖包安装后的环境，启用检测数据库导入导出功能后，以下选项必须填写对应参数："
            _warningnoblank "
            mysql-username 本地连接mysql有权限操作数据库的用户名
            mysql-password 本地连接mysql有权限操作数据库的账户的密码
            mysql-bin-path mysql整个程序总目录的绝对路径
            database-base-name 准备创建的新数据库的基本名称
            database-old-name 准备备份的数据库名称"|column -t
            _error "退出中"
            exit 1
        fi
        # mysql-bin-path
        if [ -n "$mysqlBinPath" ]; then
            if [ ! -f "$mysqlBinPath"/bin/mysql ]; then
                _error "MySQL 不存在，请确认更新包工具依赖的基础包已安装或 MySQL 软件的绝对路径设置正确"
                exit 1
            fi
        elif [ -z "$mysqlBinPath" ]; then
            if ! which mysql >/dev/null 2>&1; then
                _error "系统环境变量中不存在 MySQL 程序，请确认依赖的基础包已安装或基础包中已将 MySQL 添加进环境变量"
                exit 1
            fi
        fi

        # mysql-username
        # mysql-password
        if [ -n "$mysqlBinPath" ]; then
            mysqlRealCommand="$mysqlBinPath/bin/mysql"
        elif [ -z "$mysqlBinPath" ]; then
            mysqlRealCommand=$(which mysql)
        fi
        if ! "$mysqlRealCommand" -u"$mysqlUsername" -p"$mysqlPassword" <<< "exit" >/dev/null 2>&1; then
            _error "无法连接已安装的 MySQL，提供的账号密码错误，请重新确认"
            exit 1
        fi

        # database-old-name
        if ! "$mysqlRealCommand" -u"$mysqlUsername" -p"$mysqlPassword" <<< "use $databaseOldName;" >/dev/null 2>&1; then
            _error "MySQL 不存在此名称的老版本数据库，请重新确认"
            exit 1
        fi

        # database-base-name
        databaseNewName="$databaseBaseName$commonDate"
        if "$mysqlRealCommand" -u"$mysqlUsername" -p"$mysqlPassword" <<< "use $databaseNewName;" >/dev/null 2>&1; then
            _error "MySQL 存在同名新版本数据库，请指定不同名称的新数据库用于创建(名称格式: [新数据库基本名称][日期])"
            exit 1
        fi
    fi
fi
