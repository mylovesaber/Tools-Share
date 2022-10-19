#!/bin/bash
PrepareBuildEnv(){
    _info "开始检查系统依赖包安装情况"
    local buildDeps=("dh-make" "build-essential" "devscripts" "debhelper" "tree" "screen" "curl")
    local needInstall=0
    for i in "${buildDeps[@]}"; do
        if ! dpkg -l|awk -F ' ' '{print $2}'|grep "^$i" >/dev/null 2>&1; then
            _warning "存在未安装的依赖包，开始安装依赖"
            needInstall=1
            break
        fi
    done
    if [ "${needInstall}" -eq 1 ]; then
        local COUNT=0
        if ! while [ $COUNT -le 5 ]; do
            apt update
            if ! apt install dh-make build-essential devscripts debhelper tree screen curl -yqq; then
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
        done ; then
            exit 1
        fi

#        if [ "$?" -ne 0 ]; then
#            exit 1
#        fi
    else
        _success "已安装打包所需的必要依赖包"
    fi
}

"$@"