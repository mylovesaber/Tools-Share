#!/bin/bash

# Variable initialization
downloadSource="gitlab"
ExtraArgs=$1
cutLineText="#=========请确保hosts文件中新增的所有内容均在该行之后========="
systemType=

# if ! which tput > /dev/null 2>&1; then
_norm="\033[39m"
_red="\033[31m"
_green="\033[32m"
_tan="\033[33m"
_cyan="\033[36m"
# else
#     _norm=$(tput sgr0)
#     _red=$(tput setaf 1)
#     _green=$(tput setaf 2)
#     _tan=$(tput setaf 3)
#     _cyan=$(tput setaf 6)
# fi

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

function CheckRoot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
CheckRoot

function CheckSys(){
    _info "正在检查系统兼容性..."
    local systemName
    if [ -f /usr/bin/sw_vers ]; then
        systemType="MacOS"
    elif [ -f /usr/bin/lsb_release ]; then
        systemName=$(lsb_release -i 2>/dev/null)
        if [[ ${systemName} =~ "Debian" ]]; then
            systemType="Debian"
        elif [[ ${systemName} =~ "Ubuntu" ]]; then
            systemType="Ubuntu"
        fi
    elif [ -f /etc/redhat-release ]; then
        systemName=$(cat /etc/redhat-release 2>/dev/null)
        if [[ ${systemName} =~ "CentOS" ]]; then
            systemType="CentOS"
        elif [[ ${systemName} =~ "Red" ]]; then
            systemType="RedHat"
        fi
    elif which synoservicectl > /dev/null 2>&1; then
        systemType="Synology"
    # elif which opkg > /dev/null 2>&1; then
    #     systemType="ROUTER"
    # elif [[ $(find / -name *unRAID* 2>/dev/null |xargs) =~ "unRAID" ]]; then
    #     systemType="unRAID"
    else
        _error "暂未适配该系统，请联系作者适配，退出中..."
        exit 1
    fi
    _success "当前系统为： ${systemType} 此脚本支持该系统！"
}

function Usage(){
	# print help info
	echo ""
	echo "GitHub hosts 自动部署和更新工具"
	echo -e "\n命令格式: \n"
	echo "setup.sh  选项  参数"
	echo -e "\n选项:\n"
	echo "-s 或 --source        指定下载源，可选参数为 \"gitlab\" 或 \"github\"，若不使用该选项则默认从 GitLab 下载"
	echo "-h 或 --help          显示帮助信息并退出"
}

#################################################
# Options
if ! ARGS=$(getopt -a -o hs: -l help,source: -- "$@")
then
    _error "选项输入有误，请参照以下使用说明"
    Usage
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in

    -s | --source)
        if [[ "$2" =~ "gitlab"|"github"|"dev" ]]; then
            downloadSource="$2"
        else
            _error "参数输入错误，请参照以下使用说明"
            Usage
            exit 1
        fi
        shift
        ;;
    -h | --help)
        Usage
        exit 1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

function PlaceScript(){
    _info "开始安装工具..."
    if ! which timeout > /dev/null 2>&1; then
        # if [[ "${systemType}" == "ROUTER" ]]; then
        #     _info "开始安装 timeout"
        #     opkg update > /dev/null 2>&1
        #     opkg install coreutils-timeout
        #     _success "timeout 安装完成"
        # else
        if [ "${systemType}" = "MacOS" ]; then
            _warning "MacOS 未发现 timeout 命令，将临时下载 timeout 程序"
            curl -Ls https://gitlab.com/api/v4/projects/37571126/repository/files/auto%2Dupdate%2Dgithub%2Dhosts%2Ftimeout/raw?ref=main -o /usr/local/bin/timeout
            _info "修改权限中..."
            chown root:admin /usr/local/bin/timeout
            chmod 755 /usr/local/bin/timeout
            _success "timeout 程序已下载并应用成功"
        else
            _error "暂未适配，请联系作者"
            exit 1
        fi
    fi
    local COUNT=1
    while true;do
        case "${downloadSource}" in
            "gitlab")
                _info "从 GitLab 下载脚本"
                timeout 20s curl -Ls https://gitlab.com/api/v4/projects/37571126/repository/files/auto%2Dupdate%2Dgithub%2Dhosts%2Fhosts%2Dtool%2Esh/raw?ref=main -o /tmp/hosts-tool
                ;;
            "github")
                _info "从 GitHub 下载脚本"
                _info "开始检测 GitHub 连通性..."
                if ! timeout 5s ping -c2 -W1 github.com > /dev/null 2>&1; then
                    _error "本机所在网络无法连接 GitHub，将切换到 GitLab 同步源进行更新..."
                    downloadSource="gitlab"
                    continue
                else
                    timeout 5s wget -qO /tmp/hosts-tool https://raw.githubusercontent.com/mylovesaber/Tools-Share/main/auto-update-github-hosts/hosts-tool.sh
                fi
                ;;
            "dev")
                _info "从 GitLab dev 分支下载脚本"
                timeout 20s curl -Ls https://gitlab.com/api/v4/projects/37571126/repository/files/auto%2Dupdate%2Dgithub%2Dhosts%2Fhosts%2Dtool%2Esh/raw?ref=dev -o /tmp/hosts-tool
                ;;
            *)
                _error "参数输入错误，请参照以下使用说明"
                Usage
                exit 1
        esac
        if [ -f /tmp/hosts-tool ] && [ -n "$(cat /tmp/hosts-tool)" ];then
            _success "已下载，开始转移到系统程序路径"
            if [ "$downloadSource" = "dev" ]; then
                sed -i '/^downloadSource=/c\downloadSource="dev"' /tmp/hosts-tool
            fi
            break
        else
            sleep 1
            COUNT=$(( COUNT + 1 ))
            _warning "下载的 hosts-tool 不存在，开始尝试第 ${COUNT} 次下载..."
        fi
        if [ "${COUNT}" -gt 5 ]; then
            _error "hosts-tool 下载失败，请择日再运行此脚本，退出中..."
            exit 1
        fi
    done
    if [ "$(grep -c gitlab /tmp/hosts-tool)" == 0 ]; then
        _error "安装出现错误，退出中..."
        exit 1
    fi
    if [[ "${systemType}" == "MacOS" ]]; then
        mv /tmp/hosts-tool /usr/local/bin/hosts-tool
        _info "修改权限中..."
        chown root:admin /usr/local/bin/hosts-tool
        chmod 755 /usr/local/bin/hosts-tool
    # elif [[ "${systemType}" == "ROUTER" ]]; then
    #     mv /tmp/hosts-tool /opt/bin/hosts-tool
    #     _info "修改权限中..."
    #     chmod 755 /opt/bin/hosts-tool
    else
        mv /tmp/hosts-tool /usr/bin/hosts-tool
        _info "修改权限中..."
        chown root: /usr/bin/hosts-tool
        chmod 755 /usr/bin/hosts-tool
    fi
    _success "权限修改完成"
    _success "工具安装完成"
}

function BackupHosts(){
    # 永远根据当前 hosts 内容，将删除 github host 有关信息后的内容全部备份为 hosts.default 文件
    # 用户后续可在特定标记行之后自由修改 hosts 中的信息
    # hosts 文件中特定标记行之后改动的信息会随之后的系统定时任务更新到新的 hosts.default 文件中
    _info "为原始 hosts 文件文本添加标记并备份为实时更新的 hosts.default..."
    if grep -q "${cutLineText}" /etc/hosts; then
        _warning "发现原始 hosts 文件存在残留的标记信息，开始删除标记信息及以上的所有陈旧信息..."
        local cutLineTextNum
        cutLineTextNum=$(awk /${cutLineText}/'{print NR}' /etc/hosts)
        sed -i "1,${cutLineTextNum}d" /etc/hosts
        _success "陈旧信息删除完毕"
    fi
    _info "为 hosts 文件添加标记中..."
    sed -i "1i${cutLineText}" /etc/hosts
    _success "标记完毕"
    _info "将原始 hosts 备份为实时更新的 hosts.default..."
    cp -af /etc/hosts /etc/hosts.default
    _success "备份完毕"
}

function Combine(){
    if [[ -f /etc/githubhosts.new ]]; then
        _warning "发现 githubhosts.new，清理中..."
        rm -rf /etc/githubhosts.new
        _success "清理完毕"
    fi
    _info "下载最新 GitHub hosts 信息中..."
    local newIP
    local COUNT=0
    if ! while true; do
        newIP=$(curl -Ls https://raw.hellogithub.com/hosts|sed '/^</d')
        if [ -n "${newIP}" ]; then
            _success "下载完成"
            _info "正在合并并替换成新hosts文件..."
            echo "${newIP}" > /etc/hosts_combine
            cat /etc/hosts.default >> /etc/hosts_combine
            mv -f /etc/hosts_combine /etc/hosts
            _success "合并替换完成"
            break
        elif [ ${COUNT} -le 5 ]; then
            COUNT=$((COUNT + 1))
            _error "获取失败，准备尝试第 ${COUNT} 次获取"
            continue
        else
            _error "获取失败，退出中"
            exit 1
        fi
    done; then
        exit 1
    fi
}

function RefreshDNS(){
    _info "正在刷新 DNS 缓存..."
    # 路由器中的 bash 不知道啥原因不识别 =~ 会报错，以下其他系统都正常
    # if [[ "${systemType}" == "ROUTER" ]]; then
    #     if ! which restart_dns > /dev/null 2>&1; then
    #         _error "暂未发现该系统中的刷新 dns 功能，请自行搜索该系统的刷新 dns 方法并给脚本作者发 issue"
    #         exit 1
    #     fi
    #     restart_dns
    # elif [[ "${systemType}" =~ "Ubuntu"|"Debian"|"RedHat" ]]; then
    if [[ "${systemType}" =~ "Ubuntu"|"Debian"|"RedHat" ]]; then
        # 麒麟没有 resolvectl 且 systemd-resolve 为文件，只能用选项 flush-caches

        # ubuntu 老版本有 systemd-resolve 软链接指向 resolvectl
        # 但 systemd-resolve 可以用选项 --flush-caches 而指向的 resolvectl 只能用 flush-caches

        # ubuntu 新版本没有 systemd-resolve 软链接，但有文件 resolvectl 且只能用选项 flush-caches

        # 软链接也是文件的一种
        if [ "$(systemctl is-active NetworkManager)" = "active" ] && [ "$(systemctl is-enabled systemd-resolved.service)" = "disabled" ]; then
            systemctl enable systemd-resolved --now 1>& /dev/null
        fi
        if [ -f /usr/bin/resolvectl ]; then
            /usr/bin/resolvectl flush-caches
        elif [ ! -L /usr/bin/systemd-resolve ]; then
            /usr/bin/systemd-resolve flush-caches
        else
            _error "存在意外情况，请将以下双虚线(====...)之间的信息发送给作者"
            echo "======================"
            echo "1.----------------------"
            ls -l /usr/bin/resolvectl
            echo "2.----------------------"
            ls -l /usr/bin/systemd-resolve
            echo "3.----------------------"
            resolvectl flush-caches
            echo "4.----------------------"
            resolvectl --flush-caches
            echo "5.----------------------"
            ls -l systemd-resolve flush-caches
            echo "6.----------------------"
            ls -l systemd-resolve --flush-caches
            echo "end----------------------"
            echo "======================"
        fi
    elif [ "${systemType}" = "MacOS" ]; then
        killall -HUP mDNSResponder
    elif [ "${systemType}" = "CentOS" ]; then
        if ! which nscd > /dev/null 2>&1; then
            if ! which dnf > /dev/null 2>&1; then
                yum install -y nscd
            else
                dnf install -y nscd
            fi
        fi
        systemctl restart nscd
    elif [ "${systemType}" = "Synology" ]; then
        /var/packages/DNSServer/target/script/flushcache.sh
    fi
    _success "DNS 缓存刷新完成"
}

function SetCron(){
    # 默认每1小时更新一次hosts，每3天自动更新一次工具本身，每10天清理一次旧日志
    if [[ "${systemType}" == "MacOS" ]]; then
        _info "清理残留定时任务中..."
        crontab -l | grep -v "hosts-tool" | crontab -
        _success "清理完成"
        _info "添加新定时任务中..."
        {
            echo "0 */1 * * * /usr/local/bin/hosts-tool run"
            echo "0 0 */3 * * /usr/local/bin/hosts-tool updatefrom $downloadSource"
            echo "0 0 */10 * * /usr/local/bin/hosts-tool rmlog"
        } >> /tmp/cronfile
        crontab /tmp/cronfile
        rm -rf /tmp/cronfile
        _success "新定时任务添加完成"
    # elif [[ "${systemType}" == "ROUTER" ]]; then
    #     _info "清理残留定时任务中..."
    #     crontab -l | grep -v "hosts-tool" | crontab -
    #     _success "清理完成"
    #     _info "添加新定时任务中..."
    #     {
    #         echo "* */1 * * * /opt/bin/hosts-tool run"
    #         echo "* * */3 * * /opt/bin/hosts-tool updatefrom $downloadSource"
    #         echo "* * */10 * * /opt/bin/hosts-tool rmlog"
    #     } >> /tmp/cronfile
    #     crontab /tmp/cronfile
    #     rm -rf /tmp/cronfile
    #     _success "新定时任务添加完成"
    elif [[ ${systemType} =~ "unRAID" ]]; then
        _info "清理残留定时任务中..."
        local hostPath
        hostPath=/boot/config/plugins/dynamix/github-hosts.cron
        rm -rf $hostPath
        _success "清理完成"
        _info "添加新定时任务中..."
        cat >> $hostPath <<EOF
0 */1 * * * root /usr/bin/bash /usr/bin/hosts-tool run
0 0 */3 * * root /usr/bin/bash /usr/bin/hosts-tool updatefrom $downloadSource
0 0 */10 * * root /usr/bin/bash /usr/bin/hosts-tool rmlog
EOF
        /usr/local/sbin/update_cron
        _success "新定时任务添加完成"
    else
        _info "清理残留定时任务中..."
        sed -i '/\/usr\/bin\/hosts-tool/d' /etc/crontab
        _success "清理完成"
        _info "添加新定时任务中..."
        {
            echo "0 */1 * * * root /usr/bin/bash /usr/bin/hosts-tool run"
            echo "0 0 */3 * * root /usr/bin/bash /usr/bin/hosts-tool updatefrom $downloadSource"
            echo "0 0 */10 * * root /usr/bin/bash /usr/bin/hosts-tool rmlog"
        } >> /etc/crontab
        _success "新定时任务添加完成"
    fi
}

function ShowInfo(){
    _success "GitHub hosts 自动部署和更新工具已安装完成并开启自动更新"
    _success "命令行输入：hosts-tool 或 hosts-tool help 即可查看具体控制选项"
}

function Main(){
    CheckSys
    PlaceScript
    BackupHosts
    Combine
    RefreshDNS
    SetCron
    ShowInfo
}

if [[ -z $ExtraArgs ]];then
    _error "未输入选项，请参照以下使用说明运行该程序"
    Usage
    exit 1
fi

if [[ ! -d /var/log/hosts-tool ]]; then
    mkdir -p /var/log/hosts-tool
fi
Main | tee /var/log/hosts-tool/install.log
