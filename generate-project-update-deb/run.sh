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
    if [ ! -d build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp ]; then
        mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp
        mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/usr/share/icons/hicolor/scalable
        mkdir -p build/"$packageSource"/"$packageSource"-"$packageVersion"/usr/share/applications
        mkdir -p build/"$packageSource"/combine
    fi
    if [ "$tomcatSkip" -eq 0 ]; then
        source function/execution/TomcatConfigure.sh
    fi

    if [ "$mysqlSkip" -eq 0 ]; then
        source function/execution/MySQLConfigure.sh
    fi

    if [ "$packageSkip" -eq 0 ]; then
        if [ "$tomcatSkip" -eq 1 ] && [ "$mysqlSkip" -eq 1 ]; then
            _error "Tomcat 或 MySQL 的配置不能同时跳过，退出中"
            exit 1
        else
            source function/execution/GenerateDeb.sh
        fi
    fi
fi

