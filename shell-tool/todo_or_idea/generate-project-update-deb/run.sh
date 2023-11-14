#!/bin/bash
CPUArchitecture=""
confirmYes=0
printUsage=0
if ! ARGS=$(getopt -a -o yh -l confirmYes,help -- "$@")
then
    echo "无效的参数，请查看可用选项"
    Usage
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in
    -y | --yes)
        confirmYes=1
        ;;
    -h | --help)
        printUsage=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

# Main
if [ "$(pwd|awk -F '/' '{print $NF}')" != "generate-project-update-deb" ]; then
    echo "必须在 generate-project-update-deb 文件夹路径下执行 run.sh，退出中"
    exit 1
fi
source function/common/Color.sh
source function/common/CommonFunction.sh
[ "$printUsage" -eq 1 ] && Usage
ArchitectureDetect
CheckProfile
PrepareBuildEnv
source function/detection/CheckOption.sh
if [ "$confirmYes" -eq 0 ]; then
    _warningnoblank "============================"
    _success "选项检查完成，请查看工具收集并预调整或转换的选项参数结果"
    _successnoblank "  如果确认无误并执行打包流程，请重新运行工具并增加 -y | --yes 选项"
    source function/detection/OptionResultOutput.sh
    exit 0
elif [ "$confirmYes" -eq 1 ]; then
    _warningnoblank "============================"
    _info "开始执行打包流程"
    case $needClean in
    2)
        _info "开始清理指定项目的总打包目录"
        rm -rf build/"$packageSource"
        _success "已清理完成"
        ;;
    1)
        _info "开始彻底清空构建目录"
        rm -rf build/*
        _success "已清理完成"
        ;;
    0)
        _success "跳过清理环境流程"
        :
        ;;
    *)
        _error "清理构建目录时出现未知情况，请检查"
        exit 1
    esac

    if [ "$tomcatSkip" -eq 1 ] && [ "$mysqlSkip" -eq 1 ]; then
        case "$packageSkip" in
        0)
            _error "Tomcat 或 MySQL 的配置不能同时跳过，退出中"
            exit 1
        ;;
        1)
            _error "Tomcat/MySQL/打包 的配置不能同时跳过，退出中"
            exit 1
        ;;
        *)
            _error "package-skip 的值只能为 0 或 1，退出中"
            exit 1
        esac
    fi

    _info "开始创建必要文件夹结构"
    if [ ! -d build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp/"$packageSource" ]; then
        mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp/"$packageSource"
        mkdir -p build/"$packageSource"/combine
        if [ "$tomcatSkip" -eq 0 ]; then
            mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/usr/share/icons/hicolor/scalable
            mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp/"$packageSource"/desktopfile
        fi
    fi
    _success "必要文件夹结构创建完成"
    if [ "$tomcatSkip" -eq 0 ]; then
        _info "开始配置 Tomcat"
        source function/execution/TomcatConfigure.sh
        _success "Tomcat 配置完成"
    fi

    if [ "$mysqlSkip" -eq 0 ]; then
        _info "开始配置 MySQL"
        source function/execution/MySQLConfigure.sh
        _success "MySQL 配置完成"
    fi

    if [ "$packageSkip" -eq 0 ]; then
        _info "开始执行打包流程"
        source function/execution/GenerateDeb.sh
    fi
    if [ ! -d function/common ]; then
        cd ../../../ || exit 1
    fi
fi

