#!/bin/bash
GetValue(){
    awk /^"$1"/'{print $0}' generate-deb.conf|cut -d'=' -f 2-|sed -e 's/^\"//g;s/\"$//g'
}
# 检测通过的不会有任何提醒，不通过的一律报错退出
_info "开始解析选项，若检测无误将直接打印检测结果以供检查，任何环节检测不通过一律报错退出"
projectName=$(GetValue "project-name")
projectIconName=$(GetValue "project-icon-name")
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
javaHomeName=$(GetValue "java-home-name")
tomcatFrontendName=$(GetValue "tomcat-frontend-name")
tomcatBackendName=$(GetValue "tomcat-backend-name")
tomcatNewPort=$(GetValue "tomcat-new-port")
tomcatPreviousPort=$(GetValue "tomcat-previous-port")
tomcatIntegrityCheckSkip=$(GetValue "tomcat-integrity-check-skip")
tomcatVersion=$(GetValue "tomcat-version")
tomcatLatestRunningVersion=$(GetValue "tomcat-latest-running-version")
excludeJar=$(GetValue "exclude-jar")
catalinaOption=$(GetValue "catalina-option")
mysqlSkip=$(GetValue "mysql-skip")
mysqlUsername=$(GetValue "mysql-username")
mysqlPassword=$(GetValue "mysql-password")
mysqlBinPath=$(GetValue "mysql-bin-path")
sqlFileName=$(GetValue "sql-file-name")
commonDate=$(GetValue "common-date")
needClean=$(GetValue "need-clean")
databaseBaseName=$(GetValue "database-base-name")
databaseOldName=$(GetValue "database-old-name")
dependenciesInstalled=$(GetValue "dependencies-installed")

# [General]
# package-deploy-path
if [ -z "$packageDeployPath" ]; then
    _error "部署到的项目所在家目录不存在，请指定"
    exit 1
else
    packageDeployPath=$(sed 's/\/$//g' <<< "$packageDeployPath")
    if [ "$dependenciesInstalled" -eq 1 ] && [ ! -d "$packageDeployPath" ]; then
        _error "部署到的项目所在家目录不存在，路径可能填写错误或依赖未安装，退出中"
        exit 1
    fi
fi

# common-date
if [ -n "$commonDate" ]; then
    if ! date -d "$commonDate" +%Y%m%d >/dev/null 2>&1; then
        _error "日期格式错误，请重新输入，例: 20220101"
        exit 1
    fi
elif [ -z "$commonDate" ]; then
    _error "必须指定打包或配置日期"
    exit 1
fi

# need-clean
if [ "$needClean" != 0 ] && [ "$needClean" != 1 ] && [ "$needClean" != 2 ]; then
    _error "在打包前是否清空打包环境参数填写错误，请根据以下介绍重新填写:"
    _warningnoblank "
    0 不清空
    1 清空所有
    2 保留下载的Tomcat压缩包"|column -t
    exit 1
fi


# [Package]
# package-skip
case "$packageSkip" in
0)
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
        packageDepends="\\\${shlibs:Depends}, \\\${misc:Depends}"
    else
        packageDepends=$(sed "s/^/\\\\\${shlibs:Depends}, \\\\\${misc:Depends}, /g" <<< "$packageDepends")
        packageDepends="${packageDepends//^/\\\${shlibs:Depends}, \\\${misc:Depends}/}"
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

    # package-more-description
    if [ -n "$packageMoreDescription" ]; then
        packageMoreDescription=$(sed "s/^$packageMoreDescription/ $packageMoreDescription/g" <<< "$packageMoreDescription")
    fi
;;
1)
    :
;;
*)
    _error "package-skip 选项只能是 0(不跳过) 或 1(跳过)，退出中"
    exit 1
esac

# [Tomcat]
# tomcatLatestRunningVersion 变量判断有效性基于依赖包的安装，放在 MySQL 选项中进行处理
# tomcat-skip
case "$tomcatSkip" in
0)
    if
    [ -z "$dependenciesInstalled" ] ||
    [ -z "$javaHomeName" ] ||
    [ -z "$projectName" ] ||
    [ -z "$projectIconName" ] ||
    [ -z "$tomcatVersion" ] ||
    [ -z "$tomcatNewPort" ] ||
    [ -z "$tomcatPreviousPort" ] ||
    [ -z "$tomcatIntegrityCheckSkip" ]; then
        _error "启用配置 Tomcat 功能后，以下选项必须填写对应参数："
        _warningnoblank "
        java-home-name 需要依赖的java环境名称
        project-name 桌面快捷方式会显示的名称(可中文)
        project-icon-name 桌面快捷方式会调用的svg图标名称
        tomcat-version 需要配置或下载的Tomcat的版本号
        tomcat-new-port 需要新建的Tomcat端口号
        tomcat-previous-port 上一版本的Tomcat端口号
        tomcat-integrity-check-skip 联网校验Tomcat压缩包的完整性"|column -t
        _error "退出中"
        exit 1
    fi

    if [ "$dependenciesInstalled" -eq 1 ]; then
        if [ -z "$tomcatLatestRunningVersion" ] || [ -z "$javaHomeName" ]; then
            _error "启用配置 Tomcat 功能并设置项目底包已安装完成后，以下 Tomcat 选项必须填写对应参数："
            _warningnoblank "
            java-home-name 需要依赖的java环境名称
            tomcat-latest-running-version 已在目标系统中运行的最新版本项目所用的Tomcat版本号
            "|column -t
            _error "退出中"
            exit 1
        else
            # tomcat-latest-running-version
            if [ ! -d "$packageDeployPath"/tomcat-"$tomcatLatestRunningVersion"-"$tomcatPreviousPort" ]; then
                _error "环境中不存在已安装的指定版本 Tomcat，请检查"
                exit 1
            fi
            # java-home-name
            if [ ! -d "$packageDeployPath/$javaHomeName" ]; then
                _error "环境中不存在已安装的 Java 环境，请检查"
                exit 1
            fi
        fi
    elif [ "$dependenciesInstalled" -eq 0 ]; then
        _warning "dependencies-installed 选项未设置为已安装，将跳过检查以下选项:"
        _warningnoblank "
        java-home-name 需要依赖的java环境名称
        tomcat-latest-running-version 已在目标系统中运行的最新版本项目所用的Tomcat版本号"|column -t
    else
        _error "dependencies-installed 选项只能是 0(未安装) 或 1(已安装)，退出中"
    fi

    # project-name 暂无检查的需求

    # project-icon-name
    if [ ! -f source/"$projectIconName" ]; then
        _error "source 文件夹下无此名称的图标文件，请确认名称是否写错或忘记放置图标文件"
        exit 1
    fi

    # tomcat-frontend-name
    if [ -n "$tomcatFrontendName" ] && [ ! -d build/"$tomcatFrontendName" ]; then
        _error "指定的前端文件夹不存在，请确认文件夹名填写正确或将前端文件夹放到 source 文件夹下，退出中"
        exit 1
    fi

    # tomcat-backend-name
    if [ -n "$tomcatBackendName" ] && [ ! -d build/"$tomcatBackendName" ]; then
        _error "指定的后端文件夹不存在，请确认文件夹名填写正确或将后端文件夹放到 source 文件夹下，退出中"
        exit 1
    fi

    # 判断前后端双指定/不指定/单指定前端/单指定后端方案并返回方案名给主程序做调用
    if [ -n "$tomcatFrontendName" ] && [ -n "$tomcatBackendName" ]; then
        tomcatPlan="double"
    elif [ -z "$tomcatFrontendName" ] && [ -z "$tomcatBackendName" ]; then
        tomcatPlan="none"
    elif [ -n "$tomcatFrontendName" ]; then
        tomcatPlan="frontend"
    elif [ -n "$tomcatBackendName" ]; then
        tomcatPlan="backend"
    fi

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
    # tomcat 新老端口比较
    if [ "$tomcatNewPort" = "$tomcatPreviousPort" ]; then
        _error "需要新建的 Tomcat 端口号不能和上一个版本更新包的端口号相同"
        exit 1
    fi

    # exclude-jar(整形成 sed 可以直接用的写法，如果没有则跳过)
    if [ -n "$excludeJar" ]; then
        excludeJar=$(sed -e 's/^[ \t]*//g; s/^/\\n/g; s/[ \t]*$//g; s/$/,\\\\/g; s/ /,\\\\ \\n/g' <<< "$excludeJar")
    fi

    # catalina-option 如果没有则跳过
    if [ -n "$catalinaOption" ]; then
        catalinaOptionLine=$(awk -F 'ˇωˇ' '{print NF}' <<< "$catalinaOption")
        catalinaOptionList=()
        for (( i=1; i<="$catalinaOptionLine"; i++ )); do
            cutCatalinaOption=$(awk -F 'ˇωˇ' -v i="$i" '{print $i}' <<< "$catalinaOption")
            cutCatalinaOption=$(sed -e 's/^[ \t]*//g; s/[ \t]*$//g' <<< "$cutCatalinaOption")
            mapfile -t -O "${#catalinaOptionList[@]}" catalinaOptionList < <(echo "$cutCatalinaOption")
#            mapfile -t -O "${#catalinaOptionList[@]}" catalinaOptionList < <(awk -F 'ˇωˇ' "{print \$$i}" <<< "$catalinaOption")  # 两种写法结果相同
        done
    fi

    # tomcat-version
    # tomcat-integrity-check-skip
    tomcatFirstVersionNumber=$(awk -F '.' '{print $1}' <<< "$tomcatVersion")
    if [ "$tomcatIntegrityCheckSkip" -ne 0 ] && [ "$tomcatIntegrityCheckSkip" -ne 1 ]; then
        _error "联网校验 Tomcat 压缩包完整性选项的参数设置错误，0 为校验，1 为不校验"
        exit 1
    fi
    deleteTomcatArchive=0
    if [ -f build/apache-tomcat-"$tomcatVersion".tar.gz ]; then
        _success "已找到 $tomcatVersion 版本的 Tomcat 压缩包"
        if [ "$tomcatIntegrityCheckSkip" -eq 0 ]; then
            _info "已开启 Tomcat 资源包完整性检查"
            _info "开始检查与 Tomcat 官网的连接性"
            if ! timeout 10s ping -c2 -W1 archive.apache.org > /dev/null 2>&1; then
                _error "无法连接 Tomcat 官网，请检查网络连接，退出中"
                exit 1
            else
                _success "可连接 Tomcat 官网"
                _info "开始检查 Tomcat 官网是否存在指定版本的 Tomcat"
                if [ "$(curl -LIs -o /dev/null -w "%{http_code}" https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz.sha512)" -eq 200 ]; then
                    _success "指定版本的 Tomcat 可供校验完整性"
                    _info "正在获取 Tomcat 官网对应版本压缩包的校验值并与本地压缩包对比"
                    remoteSHA512Sum=$(curl -Ls https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz.sha512|cut -d' ' -f1)
                    localSHA512Sum=$(sha512sum build/apache-tomcat-"$tomcatVersion".tar.gz|cut -d' ' -f1)
                    if [ "$remoteSHA512Sum" = "$localSHA512Sum" ]; then
                        _success "本地存在的 $tomcatVersion 版本 Tomcat 压缩包完整性校验通过"
                    else
                        _warning "本地存在的 $tomcatVersion 版本 Tomcat 压缩包完整性校验失败，将删除本地压缩包并在下次确认打包时重新下载校验"
                        deleteTomcatArchive=1
                    fi
                else
                    _error "无法获取指定版本 Tomcat 的校验值，请检查版本号是否指定错误"
                    exit 1
                fi
            fi
        fi
    elif [ ! -f build/apache-tomcat-"$tomcatVersion".tar.gz ]; then
        _warning "未下载此版本的 Tomcat 压缩包(仅限识别apache-tomcat-x.x.x.tar.gz)，将从网络中获取"
        _info "开始检查与 Tomcat 官网的连接性(官网可能抽风，如果失败可尝试反复运行)"
        if ! timeout 10s ping -c2 -W1 archive.apache.org > /dev/null 2>&1; then
            _error "无法连接 Tomcat 官网，请检查网络连接，退出中"
            exit 1
        else
            _success "可连接 Tomcat 官网"
            _info "开始检查 Tomcat 官网是否存在指定版本的 Tomcat"
            if [ "$(curl -LIs -o /dev/null -w "%{http_code}" https://archive.apache.org/dist/tomcat/tomcat-"$tomcatFirstVersionNumber"/v"$tomcatVersion"/bin/apache-tomcat-"$tomcatVersion".tar.gz)" -eq 200 ]; then
                _success "指定版本的 Tomcat 可供下载"
            else
                _error "无法获取指定版本的 Tomcat，请检查版本号是否指定错误"
                exit 1
            fi
        fi
    fi
;;
1)
    :
;;
*)
    _error "tomcat-skip 选项只能是 0(不跳过) 或 1(跳过)，退出中"
    exit 1
esac

# [Mysql]
# mysql-skip
case "$mysqlSkip" in
0)
    if
    [ -z "$dependenciesInstalled" ] ||
    [ -z "$sqlFileName" ] ||
    [ -z "$mysqlUsername" ] ||
    [ -z "$mysqlPassword" ] ||
    [ -z "$databaseOldName" ]; then
        _error "启用配置 Mysql 功能后，以下选项必须填写对应参数："
        _warningnoblank "
        sql-file-name 要导入的sql文件名
        mysql-username 本地连接mysql有权限操作数据库的用户名
        mysql-password 本地连接mysql有权限操作数据库的账户的密码
        database-old-name 准备备份的数据库名称"|column -t
        _error "退出中"
        exit 1
    fi

    # sql-file-name
    if [[ "$sqlFileName" == *".sql" ]]; then
        :
    else
        sqlFileName="${sqlFileName}.sql"
    fi
    if [ ! -f source/"$sqlFileName" ]; then
        _error "SQL 文件不存在，请确认文件名填写正确或将 SQL 文件放到 source 文件夹下"
        exit 1
    fi

    # dependencies-installed
    if [ "$dependenciesInstalled" -eq 1 ]; then
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
            mysqlBinPath=$(sed 's/\/$//g' <<< "$mysqlBinPath")
            mysqlRealCommand="$mysqlBinPath/bin/mysql"
            mysqldumpRealCommand="$mysqlBinPath/bin/mysqldump"
        elif [ -z "$mysqlBinPath" ]; then
            mysqlRealCommand=$(which mysql)
            mysqldumpRealCommand=$(which mysqldump)
            mysqlBinPath=$(sed 's/\/bin\/mysql//g' <<< "$mysqlRealCommand")
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
        if [ "$tomcatSkip" -eq 0 ]; then
            if [ -z "$databaseBaseName" ]; then
                _error "启用配置 Tomcat 功能后，以下 MySQL 选项必须填写对应参数："
                _warningnoblank "
                database-base-name 准备创建的新数据库的基本名称"|column -t
                _error "退出中"
                exit 1
            else
                # database-base-name
                databaseNewName="$databaseBaseName$commonDate"
                if "$mysqlRealCommand" -u"$mysqlUsername" -p"$mysqlPassword" <<< "use $databaseNewName;" >/dev/null 2>&1; then
                    _error "MySQL 存在同名新版本数据库，请指定不同名称的新数据库用于创建(名称格式: [新数据库基本名称][日期])"
                    exit 1
                fi

                # databaseOldName and databaseNewName
                if [ "$databaseOldName" = "$databaseNewName" ]; then
                    _error "需要备份的数据库名不能和将创建的数据库名相同"
                    exit 1
                fi
            fi
        fi
    elif [ "$dependenciesInstalled" -eq 0 ]; then
        _warning "dependencies-installed 选项未设置为已安装，将跳过检查以下选项:"
        _warningnoblank "
        mysql-username 本地连接mysql有权限操作数据库的用户名
        mysql-password 本地连接mysql有权限操作数据库的账户的密码
        mysql-bin-path mysql整个程序总目录的绝对路径
        database-base-name 准备创建的新数据库的基本名称
        database-old-name 准备备份的数据库名称"|column -t
    else
        _error "dependencies-installed 选项只能是 0(未安装) 或 1(已安装)，退出中"
        exit 1
    fi
;;
1)
    :
;;
*)
    _error "mysql-skip 选项只能是 0(不跳过) 或 1(跳过)，退出中"
    exit 1
esac
