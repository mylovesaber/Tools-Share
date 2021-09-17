#!/bin/bash
# Variable initialization
options=$1
exec_log=/var/log/hosts-tool/exec-$(date +"%Y-%m-%d").log 2>&1

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

function _loginfo(){
    cat >> /var/log/hosts-tool/$(date +"%Y-%m-%d").log <<EOF

------------------------------------------------
时间：$(date +"%Y-%m-%d %H:%M:%S")
执行情况：
EOF
}

function _usage(){
	# print help info
	echo -e "\nGithub hosts 自动部署和更新工具"
	echo -e "\n命令格式: \n$(basename "$0")  选项1  (选项2)"
	echo -e "\n选项:\n"
    echo "run                        立即更新hosts"
	echo "updatefrom gitee|github    需指定下载源才能升级该工具"
    echo "                           可选选项为 gitee 或 github，默认是码云"
    echo ""
	echo "recover                    可选选项为 first_backup 或 uptodate_backup"
	echo "help                       显示帮助信息并退出"
}

function _placescript(){
    cd /root
    if [[ $extraarg =~ "gitee" ]]; then
        _info "从码云下载脚本"
        wget -qO /usr/bin/hosts-tool https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/hosts-tool.sh
    elif [[ $extraarg =~ "github" ]]; then
        _info "从 Github 下载脚本"
        wget -qO /usr/bin/hosts-tool https://raw.githubusercontent.com/mylovesaber/auto_update_github_hosts/master/hosts-tool.sh
    fi
    chown root: /usr/bin/hosts-tool
    chmod 755 /usr/bin/hosts-tool
}

function _backuphosts(){
    _info "开始备份hosts.bak 和 hosts.default..."
    # 首次使用此脚本，备份已有 hosts，在清除更新 github hosts 规则的自动环境之前均不会改动此文件
    if [[ ! -f /etc/hosts.bak ]]; then
        _warning "原始hosts.bak备份未找到，开始备份为hosts.bak"
        cp -af /etc/hosts /etc/hosts.bak
    fi
    _info "已发现hosts.bak，跳过"
    # 将系统自带及用户自定义的 hosts 规则筛选出来并重定向为 hosts.default 文件
    # 用户后续可在特定标记行之后自由修改 hosts 中的信息
    # hosts 文件中特定标记行之后改动的信息会随之后的系统定时任务更新到新的 hosts.default 文件中
    cutlinetext="#=========请确保hosts文件中新增的所有内容均在该行之后========="
    if [[ ! -f /etc/hosts.default ]]; then
        _info "发现hosts.default"
        if [[ -n $(grep "${cutlinetext}" /etc/hosts) ]]; then
            _info "发现切割行"
            sed -i '/'${cutlinetext}'/d' /etc/hosts
        fi
        _info "开始添加切割行并备份到hosts.default"
        sed -i '1i\'${cutlinetext}'' /etc/hosts
        cp -af /etc/hosts /etc/hosts.default
    else
        cutline=$(grep -n "${cutlinetext}" /etc/hosts | cut -d':' -f1)
        _info "未发现hosts.default，将hosts中非更新部分备份成该文件"
        sed -n ''${cutline}',$p' /etc/hosts > /etc/hosts.default
    fi
}

function _combine(){
    if [[ -f /etc/githubhosts.new ]]; then
        _info "发现githubhosts.new，删掉"
        rm -rf /etc/githubhosts.new
    fi
    _info "开始合成新hosts文件"
    wget -qO /etc/githubhosts.new https://raw.hellogithub.com/hosts
    cat /etc/githubhosts.new > /etc/hosts_combine
    cat /etc/hosts.default >> /etc/hosts_combine
    mv -f /etc/hosts_combine /etc/hosts
}

function _setcron(){
    # 默认每30分钟更新一次hosts，每周自动更新一次工具本身
    sed -i '/\/usr\/bin\/hosts-tool/d' /etc/crontab
    echo "*/30 * * * * root /usr/bin/bash /usr/bin/hosts-tool run" >> /etc/crontab
    echo "* */10 * * * root /usr/bin/bash /usr/bin/hosts-tool updatefrom gitee" >> /etc/crontab
    echo "* */10 * * * root /usr/bin/bash /usr/bin/hosts-tool rmlog" >> /etc/crontab
}

function _recover(){
    sed -i '/\/usr\/bin\/hosts-tool/d' /etc/crontab
    rm -rf /usr/bin/hosts-tool /var/log/hosts-tool/
    if [[ ${extraarg} =~ "first_backup" ]]; then
        mv -f /etc/hosts.bak /etc/hosts
        rm -rf /etc/hosts_combine /etc/hosts.default githubhosts.new
    elif [[ ${extraarg} =~ "uptodate_backup" ]]; then
        mv -f /etc/hosts.default /etc/hosts
        rm -rf /etc/hosts_combine /etc/hosts.bak githubhosts.new
    fi
}

function _rmlog(){
    logfile=$(find /var/log/hosts-tool/ -name "exec*.log" -mtime +20)
    for a in $logfile
    do
        rm -f ${a}
    done
}

if [[ $options == "updatefrom" ]]; then
	extraarg=${*:2}
	if [[ $extraarg != "gitee" && $extraarg != "github" && -z $extraarg ]]; then
		_error "请正确输入自动更新工具下载源名称对应括号内的英文选项："
		_warning "码云（gitee）"
		_warning "Github（github）"
	else
        _loginfo
        _placescript
        _setcron
	fi
fi

if [[ $options == "recover" ]]; then
	extraarg="${*:2}"
    if [[ $extraarg != "first_backup" && $extraarg != "uptodate_backup" ]]; then
		_error "请正确输入需要恢复的hosts文件对应括号内的英文选项："
		_warning "首次备份（first_backup）"
		_warning "最新备份（uptodate_backup）"
	else
        _loginfo
		_recover
	fi
fi

if [[ $options == "help" ]]; then
	_usage
	exit 0
fi

if [[ $options == "run" ]]; then
    _loginfo
    _backuphosts
    _combine
fi

if [[ $options == "rmlog" ]]; then
    _rmlog
fi

if [[ ! $options =~ ("recover"|"updatefrom"|"help"|"run"|"rmlog") ]]; then
	_error "选项不存在"
	_usage
	exit 1
fi