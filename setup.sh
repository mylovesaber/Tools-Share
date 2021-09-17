#!/bin/bash

# Variable initialization
source=0

_norm=$(tput sgr0)
_red=$(tput setaf 1)
_green=$(tput setaf 2)
_tan=$(tput setaf 3)
_cyan=$(tput setaf 6)

function _print() {
	printf "${_norm}%s${_norm}\n" "$@"
}
function _info() {
	printf "${_cyan}➜ %s${_norm}\n" "$@"
}
function _success() {
	printf "${_green}✓ %s${_norm}\n" "$@"
}
function _warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
function _error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}

function _checkroot() {
	if [[ $EUID != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

function _checkhosts() {
    if [[ ! -f /etc/hosts ]]; then
        _error "该linux系统中默认位置不存在hosts文件，安装取消"
        exit 1
    fi
}

function _usage(){
	# print help info
	echo -e "\nGithub hosts 自动部署和更新工具"
	echo -e "\n命令格式: \n$(basename "$0")  选项  参数"
	echo -e "\n选项:\n"
	echo "-s 或 --source        指定下载源，可选参数为 gitee 或 github，若不使用该选项则默认从 Gitee 下载"
	echo "-h 或 --help          显示帮助信息并退出"
}

#################################################
# Options
if ! ARGS=$(getopt -a -o hs: -l help,source: -- "$@")
then
    _error "选项输入有误，请参照以下使用说明"
    _usage
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in
    -s | --source)
        if [[ "$2" =~ "gitee"|"github"|"" ]]; then
            source="$2"
        else
            _error "参数输入错误，请参照以下使用说明"
            _usage
            exit 1
        fi
        shift
        ;;
    -h | --help)
        _usage
        exit 1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

function _placescript(){
    cd /root
    if [[ $extraarg =~ "gitee" ]]; then
        _info "从码云下载脚本"
        wget -qO /usr/bin/hosts-tool https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/hosts-tool.sh
    elif [[ $extraarg =~ "github" ]]; then
        _info "从 Github 下载脚本"
        wget -qO /usr/bin/hosts-tool https://raw.githubusercontent.com/mylovesaber/auto_update_github_hosts/master/hosts-tool.sh
    else
        _info "未选择下载源，默认从码云下载脚本"
        wget -qO /usr/bin/hosts-tool https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/hosts-tool.sh
    fi
    chown root: /usr/bin/hosts-tool
    chmod 755 /usr/bin/hosts-tool
}

function _backuphosts(){
    # 首次使用此脚本，备份已有 hosts，在清除更新 github hosts 规则的自动环境之前均不会改动此文件
    if [[ ! -f /etc/hosts.bak ]]; then
        cp -af /etc/hosts /etc/hosts.bak
    fi
    # 将系统自带及用户自定义的 hosts 规则筛选出来并重定向为 hosts.default 文件
    # 用户后续可在特定标记行之后自由修改 hosts 中的信息
    # hosts 文件中特定标记行之后改动的信息会随之后的系统定时任务更新到新的 hosts.default 文件中
    cutlinetext="#=========请确保hosts文件中新增的所有内容均在该行之后========="
    if [[ ! -f /etc/hosts.default ]]; then
        if [[ -n $(grep "${cutlinetext}" /etc/hosts) ]]; then
            sed -i '/'${cutlinetext}'/d' /etc/hosts
        fi
        sed -i '1i\'${cutlinetext}'' /etc/hosts
        cp -af /etc/hosts /etc/hosts.default
    else
        cutline=$(grep -n "${cutlinetext}" /etc/hosts | cut -d':' -f1)
        sed -n ''${cutline}',$p' /etc/hosts > /etc/hosts.default
    fi
}

function _combine(){
    if [[ -f /etc/githubhosts.new ]]; then
        rm -rf /etc/githubhosts.new
    fi
    wget -qO /etc/githubhosts.new https://raw.hellogithub.com/hosts
    cat /etc/githubhosts.new > /etc/hosts_combine
    cat /etc/hosts.default >> /etc/hosts_combine
    mv -f /etc/hosts_combine /etc/hosts
}

function _setcron(){
    sed -i '/\/usr\/bin\/hosts-tool/d' /etc/crontab
    echo "*/30 * * * * root /usr/bin/bash /usr/bin/hosts-tool run" >> /etc/crontab
    echo "* */7 * * * root /usr/bin/bash /usr/bin/hosts-tool updatefrom gitee" >> /etc/crontab
    echo "* */10 * * * root /usr/bin/bash /usr/bin/hosts-tool rmlog" >> /etc/crontab
}

function _showinfo(){
    _success "Github hosts 自动部署和更新工具已安装完成并开启自动更新"
    _success "命令行输入：hosts-tool -h 即可查看具体控制选项"
}

function _main(){
        _checkhosts
        _placescript
        _backuphosts
        _combine
        _setcron
}

if [[ ! -d /var/log/hosts-tool ]]; then
    mkdir -p /var/log/hosts-tool
fi
_main | tee /var/log/hosts-tool/install.log
