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
        if [[ "$2" =~ "gitee"|"github" ]]; then
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
_info "开始安装工具..."
    if [[ $source =~ "gitee" ]]; then
        _info "从码云下载脚本"
        wget -qO /tmp/hosts-tool https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/hosts-tool.sh
    elif [[ $source =~ "github" ]]; then
        _info "从 Github 下载脚本"
        wget -qO /tmp/hosts-tool https://raw.githubusercontent.com/mylovesaber/auto_update_github_hosts/master/hosts-tool.sh
    fi
    while true;do
        if [[ -f /tmp/hosts-tool ]];then
            _success "已下载，开始转移到系统程序路径"
            break
        else
            sleep 1
        fi
    done
    mv /tmp/hosts-tool /usr/bin/hosts-tool
    _info "修改权限中..."
    chown root: /usr/bin/hosts-tool
    chmod 755 /usr/bin/hosts-tool
    _success "权限修改完成"
    _success "工具安装完成"
}

function _backuphosts(){
    _info "开始备份 hosts.bak 和 hosts.default..."
    # 首次使用此脚本，备份已有 hosts，在清除更新 github hosts 规则的自动环境之前均不会改动此文件
    _info "检测 hosts.bak 文件是否存在"
    if [[ ! -f /etc/hosts.bak ]]; then
        _warning "原始 hosts.bak 备份未找到，备份当前 hosts 文件为 hosts.bak"
        cp -af /etc/hosts /etc/hosts.bak
        _success "备份完毕"
    fi
    _success "已发现hosts.bak，跳过"
    # 将系统自带及用户自定义的 hosts 规则筛选出来并重定向为 hosts.default 文件
    # 用户后续可在特定标记行之后自由修改 hosts 中的信息
    # hosts 文件中特定标记行之后改动的信息会随之后的系统定时任务更新到新的 hosts.default 文件中
    _info "检测环境安装后实时更新的 hosts.default 文件是否存在"
    cutlinetext="#=========请确保hosts文件中新增的所有内容均在该行之后========="
    if [[ ! -f /etc/hosts.default ]]; then
        _warning "未发现 hosts.default 文件，为原始 hosts 文件文本添加标记并备份为实时更新的 hosts.default..."
        if [[ -n $(grep "${cutlinetext}" /etc/hosts) ]]; then
            _warning "发现原始 hosts 文件存在残留的标记信息，清理中..."
            sed -i '/'${cutlinetext}'/d' /etc/hosts
            _success "清理完毕"
        fi
        _info "为原始 hosts 文件添加标记中..."
        sed -i '1i\'${cutlinetext}'' /etc/hosts
        _success "标记完毕"
        _info "将原始 hosts 备份为实时更新的 hosts.default..."
        cp -af /etc/hosts /etc/hosts.default
        _success "备份完毕"
    else
        _info "未发现hosts.default，将原始 hosts 信息和用户新增内容备份为 hosts.default..."
        cutline=$(grep -n "${cutlinetext}" /etc/hosts | cut -d':' -f1)
        sed -n ''${cutline}',$p' /etc/hosts > /etc/hosts.default
        _success "备份完毕"
    fi
    _success "所有备份已完成"
}

function _combine(){
    _info "开始合并 hosts..."
    if [[ -f /etc/githubhosts.new ]]; then
        _warning "发现githubhosts.new，清理中..."
        rm -rf /etc/githubhosts.new
        _success "清理完毕"
    fi
    _info "下载最新 Github hosts 信息中..."
    wget -qO /etc/githubhosts.new https://raw.hellogithub.com/hosts
    _success "下载完成"
    _info "正在合并并替换成新hosts文件..."
    cat /etc/githubhosts.new > /etc/hosts_combine
    cat /etc/hosts.default >> /etc/hosts_combine
    mv -f /etc/hosts_combine /etc/hosts
    _success "合并替换完成"
}

function _setcron(){
    # 默认每30分钟更新一次hosts，每周自动更新一次工具本身，每10天清理一次旧日志
    _info "清理残留定时任务中..."
    sed -i '/\/usr\/bin\/hosts-tool/d' /etc/crontab
    _success "清理完成"
    _info "添加新定时任务中..."
    echo "*/30 * * * * root /usr/bin/bash /usr/bin/hosts-tool run" >> /etc/crontab
    echo "* */3 * * * root /usr/bin/bash /usr/bin/hosts-tool updatefrom gitee" >> /etc/crontab
    echo "* */10 * * * root /usr/bin/bash /usr/bin/hosts-tool rmlog" >> /etc/crontab
    _success "新定时任务添加完成"
}

function _showinfo(){
    _success "Github hosts 自动部署和更新工具已安装完成并开启自动更新"
    _success "命令行输入：hosts-tool 或 hosts-tool help 即可查看具体控制选项"
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
_showinfo
