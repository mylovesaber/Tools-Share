#!/bin/bash
source function/color.sh
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
    case $(uname -p) in
        "mips64") CPUArchitecture="mips64el";;
        *) _error "未知 CPU 架构或暂未适配此 CPU 架构，请检查"; exit 1
    esac
}

PrepareBuildEnv(){
    _info "开始检查系统依赖包安装情况"
    local buildDeps=("dh-make" "build-essential" "devscripts" "debhelper" "tree" "screen")
    local needInstall=0
    for i in "${buildDeps[@]}"; do
        if ! dpkg -l|grep "$i" >/dev/null 2>&1; then
            _warning "存在未安装的依赖包，开始安装依赖"
            needInstall=1
            break
        fi
    done
    if [ "${needInstall}" -eq 1 ]; then
        local COUNT=0
        while [ $COUNT -le 5 ]; do
            apt update
            if ! apt install dh-make build-essential devscripts debhelper tree -yqq; then
                _warning "系统源抽风，即将重试"
                COUNT=$((COUNT + 1))
                continue
            else
                _success "已安装打包所需的必要依赖包"
                break
            fi
            if [ "$COUNT" -gt 5 ]; then
                _error "系统源抽风无法安装系统必要依赖包，请择日再试，退出中"
                exit 1
            fi
        done
        if [ "$?" -ne 0 ]; then
            exit 1
        fi
    else
        _success "已安装打包所需的必要依赖包"
    fi
}

ArchitectureDetect
if [ ! -f generate-deb.conf ]; then
    _warning "未发现配置文件，将根据模板文件生成默认配置文件，请修改配置文件以定制脚本功能"
    if [ -f function/GenerateProfile.sh ]; then
        source function/GenerateProfile.sh
        _success "配置文件生成完成，请修改配置文件以定制脚本功能"
        exit 0
    else
        _error "打包环境不完整，请重新 git clone 获取完整环境"
        exit 1
    fi
fi

PrepareBuildEnv
source function/OptionCheck.sh
