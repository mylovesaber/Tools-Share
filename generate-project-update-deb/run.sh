#!/bin/bash
CPUArchitecture=""
confirmYes=0
source function/common/Color.sh
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
        Usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

Usage(){
    echo "项目更新包一键生成工具"
    echo ""
    echo "此工具是基于基础包的更新包一键生成工具，必须和基础包搭配使用，默认检测流程和执行流程解耦"
    echo "所有工具工作情况均通过配置文件设置，此工具会检测同级目录是否存在配置文件，没有则根据模板生成一个"
    echo "建议每次打包前先直接不加选项运行工具，环境检测无误后再加 -y | --yes 执行打包流程"
    echo "以下是可用选项"
    echo "
        -y | --yes 此选项将会执行打包流程过程，没有的话工具运行只会打印出解析的选项和对于打包环境的检测情况
        -h | --help 打印此帮助菜单并退出"|column -t
}

ArchitectureDetect(){
    case $(dpkg-architecture |awk -F '=' /DEB_HOST_ARCH=/'{print $2}') in
        "mips64el") CPUArchitecture="mips64el";;
        *) _error "未知 CPU 架构或暂未适配此 CPU 架构，请检查"; exit 1
    esac
}

# Main
ArchitectureDetect
if [ ! -f generate-deb.conf ]; then
    _warning "未发现配置文件，将根据模板文件生成默认配置文件"
    if [ -f function/GenerateProfile.sh ]; then
        source function/detection/GenerateProfile.sh
        _success "配置文件生成完成，请修改配置文件以定制脚本功能"
        exit 0
    else
        _error "打包环境不完整，请重新 git clone 获取完整环境"
        exit 1
    fi
fi

source function/common/PrepareBuildEnv.sh
PrepareBuildEnv
source function/detection/CheckOption.sh
if [ "$confirmYes" -eq 0 ]; then
    _success "选项检查完成，请查看工具收集并预调整或转换的选项参数结果，如果确认无误并执行打包流程，请重新运行工具并增加 -y | --yes 选项"
    source function/detection/OptionResultOutput.sh
    exit 0
else
    :
    # 这里是具体执行流程分支
fi

