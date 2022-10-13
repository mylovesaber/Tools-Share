#!/bin/bash
ArchitectureDetect(){
    case $(uname -p) in
        "mips64") CPUArchitecture="mips64el";;
        *) _error "未知 CPU 架构，请检查"; exit 1
    esac
}

PrepareBuildEnv(){
    apt update
    apt install dh-make build-essential devscripts debhelper tree -y
}

if [ ! -f ./GenerateProfile.sh ]; then

    source src/GenerateProfile.sh
    exit 0
fi
