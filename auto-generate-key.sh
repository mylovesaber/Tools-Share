#!/bin/bash
# bash <(cat auto-generate-key.sh) -l 

# 全局颜色
_norm=$(tput sgr0)
_red=$(tput setaf 1)
_green=$(tput setaf 2)
_tan=$(tput setaf 3)
_cyan=$(tput setaf 6)

_print() {
	printf "${_norm}%s${_norm}\n" "$@"
}
_info() {
	printf "${_cyan}➜ %s${_norm}\n" "$@"
}
_success() {
	printf "${_green}✓ %s${_norm}\n" "$@"
}
_warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
_error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}

_checkroot() {
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

# 变量名
SH_NAME="auto-generate-key"
GEN_SH_NAME="auto-configure-other-servers"
PRE_ADD_LIST=""
COMMIT_INFO=
AUTHORIZED_KEYS=
PRIVATE_KEY=
CONFIG_FILE=
LOCAL_IP=
HELP=0
TO_DELETE=0
CHECK_DEP_SEP=0

# 功能模块
InfoCheck(){
    [ "${TO_DELETE}" -eq 1 ] && rm -rf /root/.ssh && _success "已删除 /root/.ssh 文件夹" && exit 0

    _info "检查脚本使用的有关软件安装情况"
    # 检查必要软件包安装情况
    appList="timeout tput pwd ip ifconfig"
    appNotInstalled=""
    for i in ${appList}; do
        if which "$i" >/dev/null 2>&1; then
            _success "$i 已安装"
        else
            _error "$i 未安装"
            appNotInstalled="${appNotInstalled} $i"
        fi
    done

    # 独立检查脚本依赖情况模块
    if [ "${CHECK_DEP_SEP}" == 1 ]; then
        if [ -n "${appNotInstalled}" ]; then
            _error "未安装的软件为: ${appNotInstalled}"
            _error "当前运行环境不支持部分脚本功能，为安全起见，此脚本在重新适配前运行都将自动终止进程"
            exit 1
        elif [ -z "${appNotInstalled}" ]; then
            _success "脚本正常工作所需依赖全部满足要求"
            exit 0
        fi
    elif [ "${CHECK_DEP_SEP}" == 0 ]; then
        if [ -n "${appNotInstalled}" ]; then
            _error "未安装的软件为: ${appNotInstalled}"
            _error "当前运行环境不支持部分脚本功能，为安全起见，此脚本在重新适配前运行都将自动终止进程"
            exit 1
        elif [ -z "${appNotInstalled}" ]; then
            _success "脚本正常工作所需依赖全部满足要求"
        fi
    fi

    [ -z "${COMMIT_INFO}" ] && _error "必须指定公钥的备注信息" && exit 1
    [ -z "${PRE_ADD_LIST}" ] && _error "必须指定要生成免密信息的服务器列表" && exit 1

    _info "检测本机 IP 地址"
    COUNT=0
    for i in $(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}');do
        COUNT=$(( COUNT + 1 ))
    done
    if [ "${COUNT}" -ne 1 ]; then
        _error "检测到本机存在多个网卡，请联系脚本作者进行适配"
        exit 1
    else
        LOCAL_NIC_NAME=$(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}')
        IP_RESULT1=$(ip addr | grep "${LOCAL_NIC_NAME}" | grep inet | awk '{print $2}' | cut -d'/' -f1)
        IP_RESULT2=$(ifconfig "${LOCAL_NIC_NAME}" | grep "inet " | awk '{print $2}')
        if [ "${IP_RESULT1}" = "${IP_RESULT2}" ]; then
            LOCAL_IP=${IP_RESULT1}
            _success "本地 IP 地址已确定"
            _print "IP 地址: ${LOCAL_IP}"
        else
            _error "检测到本机存在多个 IP，请联系脚本作者适配"
            exit 1
        fi
    fi

    _info "开始检查传入的服务器列表信息"
    echo "${PRE_ADD_LIST}" | sed 's/ /\n/g'
    COUNT=0
    for i in ${PRE_ADD_LIST}; do
        STRING_COUNT=$(echo "$i" | awk -F '-' '{print NF}')
        if [ "${STRING_COUNT}" != 4 ]; then
            _error "你指定设置别名的传参方式"
            _error "则传入服务器信息中必须同时有: 别名/用户名/IP 地址/端口号 这四个参数且顺序不能错"
            _error "请检查输入的信息"
            exit 1
        else
            ALIAS_NAME=$(echo "$i" | cut -d'-' -f1)
            USERNAME=$(echo "$i" | cut -d'-' -f2)
            IP_ADDRESS=$(echo "$i" | cut -d'-' -f3)
            SSH_PORT=$(echo "$i" | cut -d'-' -f4)
        fi

        # 节点别名检查
        count=0
        reserved_names=('adm' 'admin' 'audio' 'backup' 'bin' 'cdrom' 'crontab' 'daemon' 'dialout' 'dip' 'disk' 'fax' 'floppy' 'fuse' 'games' 'gnats' 'irc' 'kmem' 'landscape' 'libuuid' 'list' 'lp' 'mail' 'man' 'messagebus' 'mlocate' 'netdev' 'news' 'nobody' 'nogroup' 'operator' 'plugdev' 'proxy' 'root' 'sasl' 'shadow' 'src' 'ssh' 'sshd' 'staff' 'sudo' 'sync' 'sys' 'syslog' 'tape' 'tty' 'users' 'utmp' 'uucp' 'video' 'voice' 'whoopsie' 'www-data')
        count=$(echo -n "${ALIAS_NAME}" | wc -c)
        if echo "${reserved_names[@]}" | grep -wq "${ALIAS_NAME}"; then
            _error "节点别名禁止使用系统内置命令名称!"
            _error "错误用户名: ${ALIAS_NAME}"
            exit 1
        elif [[ $count -lt 3 || $count -gt 32 ]]; then
            _error "节点别名字符数量必须控制在 3-32 个(包括 3 和 32 个字符)!"
            _error "错误用户名: ${ALIAS_NAME}"
            exit 1
        elif ! [[ "${ALIAS_NAME}" =~ ^[a-zA-Z0-9_-.]*$ ]]; then
            _error "节点别名只能包含大小写字母、数字、连字符(-)、下划线(_)和小数点(.)"
            _error "错误用户名: ${ALIAS_NAME}"
            exit 1
        fi

        # IP 地址检查
        if [[ ! "${IP_ADDRESS}" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
            _error "IP 地址格式不正确，请检查写法"
            _error "错误的 IP 地址: ${IP_ADDRESS}"
            exit 1
        else
            if ! timeout 5s ping -c2 -W1 "${IP_ADDRESS}" > /dev/null 2>&1; then
                _error "所用 IP 无法 ping 通，可能 IP 填写错误或者宕机了？"
                exit 1
            fi
        fi

        # SSH 端口号大小检查
        if [ "${SSH_PORT}" -le 1 ] || [ "${SSH_PORT}" -ge 65535 ]; then
            _error "端口号超过规定值(1-255)，是不是写错了？"
            _error "错误的端口号: ${SSH_PORT}"
            exit 1
        fi
        COUNT=$(( COUNT + 1 ))
    done
    [ "${COUNT}" -le 1 ] && _error "服务器信息列表必须包含至少两组服务器信息" && exit 1
    _success "全部输入信息格式均正确且所有服务器处于可连接状态，开始配置并生成一键免密配置脚本"
}

GenerateKey(){
    if [ ! -d /root/.ssh ]; then
        _warning ".ssh 文件夹未创建，开始创建并修改权限"
        mkdir -p /root/.ssh
    fi
    chmod 700 /root/.ssh
    if [ -f /root/.ssh/ssh_auto_generate_key.pub ] && [ -f /root/.ssh/authorized_keys ] && [ -f /root/.ssh/config ]; then
        _info "发现本工具部署残留，清理中"
        LABEL=$(awk '{print $NF}' /root/.ssh/ssh_auto_generate_key.pub)
        sed -i "/${LABEL}/d" /root/.ssh/authorized_keys
        rm -rf /root/.ssh/{ssh_auto_generate_key.pub,ssh_auto_generate_key,config}
        _success "清理完成"
    fi
    _info "开始静默生成公密钥及其他配置文件"
    ssh-keygen -t rsa -q -f /root/.ssh/ssh_auto_generate_key -N "" -C "${COMMIT_INFO}"
    cat /root/.ssh/ssh_auto_generate_key.pub >> /root/.ssh/authorized_keys
    touch /root/.ssh/config
    for i in ${PRE_ADD_LIST};do
        ALIAS_NAME=$(echo "$i" | cut -d'-' -f1)
        USERNAME=$(echo "$i" | cut -d'-' -f2)
        IP_ADDRESS=$(echo "$i" | cut -d'-' -f3)
        SSH_PORT=$(echo "$i" | cut -d'-' -f4)
        cat >> /root/.ssh/config << EOF
Host ${ALIAS_NAME}
HostName ${IP_ADDRESS}
User ${USERNAME}
Port ${SSH_PORT}
StrictHostKeyChecking no
IdentityFile ~/.ssh/ssh_auto_generate_key

EOF
    done
    chmod 644 /root/.ssh/{ssh_auto_generate_key.pub,authorized_keys,config}
    chmod 600 /root/.ssh/ssh_auto_generate_key
    _success "本机公密钥配置已完成"
    # _info "测试传递进子脚本的信息"
    AUTHORIZED_KEYS=$(cat /root/.ssh/ssh_auto_generate_key.pub)
    PRIVATE_KEY=$(cat /root/.ssh/ssh_auto_generate_key)
    CONFIG_FILE=$(cat /root/.ssh/config)
    # echo "AUTHORIZED_KEYS"
    # echo "${AUTHORIZED_KEYS}"
    # echo "PRIVATE_KEY"
    # echo "${PRIVATE_KEY}"
    # echo "CONFIG_FILE"
    # echo "${CONFIG_FILE}"
}

GenerateScript(){
    _info "开始生成其他服务器使用的自动部署脚本"
    cat > /root/"${GEN_SH_NAME}".sh <<EOF
#!/bin/bash
_norm=\$(tput sgr0)
_red=\$(tput setaf 1)
_green=\$(tput setaf 2)
_tan=\$(tput setaf 3)
_cyan=\$(tput setaf 6)

_print() {
	printf "\${_norm}%s\${_norm}\n" "\$@"
}
_info() {
	printf "\${_cyan}➜ %s\${_norm}\n" "\$@"
}
_success() {
	printf "\${_green}✓ %s\${_norm}\n" "\$@"
}
_warning() {
	printf "\${_tan}⚠ %s\${_norm}\n" "\$@"
}
_error() {
	printf "\${_red}✗ %s\${_norm}\n" "\$@"
}

_checkroot() {
	if [ \$EUID != 0 ] || [[ \$(grep "^\$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
}
_checkroot

OVERRIDE=0
DELETE=0

if ! ARGS=\$(getopt -a -o o,d -l override,delete -- "\$@")
then
    _error "脚本中没有此选项"
    exit 1
elif [ -z "\$1" ]; then
    _error "没有设置选项"
    exit 1
elif [ "\$1" == "-" ]; then
    _error "选项写法出现错误"
    exit 1
fi
eval set -- "\${ARGS}"
while true; do
    case "\$1" in
    -o | --override)
        OVERRIDE=1
        ;;
    -d | --delete)
        DELETE=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

[ "\${DELETE}" -eq 1 ] && rm -rf /root/.ssh && exit 0

_info "开始检测此子脚本是否存在于可用的 IP 列表中"
COUNT=0
LOCAL_NIC_NAME=\$(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print \$NF}')
for i in \${LOCAL_NIC_NAME};do
    COUNT=\$(( COUNT + 1 ))
    _print "本机网卡名: \$i"
done
if [ "\${COUNT}" -lt 1 ]; then
    _error "未检测到网卡，请联系脚本作者进行适配"
    exit 1
elif [ "\${COUNT}" -gt 1 ]; then
    _error "检测到多个网卡，请联系脚本作者进行适配"
    exit 1
else
    
    IP_RESULT1=\$(ip addr | grep "\${LOCAL_NIC_NAME}" | grep inet | awk '{print \$2}' | cut -d'/' -f1)
    IP_RESULT2=\$(ifconfig "\${LOCAL_NIC_NAME}" | grep "inet " | awk '{print \$2}')
    if [ "\${IP_RESULT1}" = "\${IP_RESULT2}" ]; then
        LOCAL_IP=\${IP_RESULT1}
        _success "本地 IP 地址已确定"
        _print "IP 地址: \${LOCAL_IP}"
    else
        _error "检测到多个 IP，请联系脚本作者适配"
        exit 1
    fi
fi

if ! echo "${CONFIG_FILE}" | xargs | grep "\${LOCAL_IP}" >/dev/null 2>&1; then
    _error "此服务器不在配置列表中，退出中"
    exit 1
else
    _success "此服务器在配置列表中"
fi

_info "开始部署免密环境"
if [ ! -d /root/.ssh ]; then
    mkdir -p /root/.ssh
fi
chmod 700 /root/.ssh

if [ "\${OVERRIDE}" -eq 1 ]; then
    echo "${AUTHORIZED_KEYS}" > /root/.ssh/authorized_keys
    echo "${AUTHORIZED_KEYS}" > /root/.ssh/ssh_auto_generate_key.pub
elif [ "\${OVERRIDE}" -eq 0 ]; then
    LABEL=\$(awk '{print \$NF}' /root/.ssh/ssh_auto_generate_key.pub)
    sed -i "/\${LABEL}/d" /root/.ssh/authorized_keys
    echo "${AUTHORIZED_KEYS}" >> /root/.ssh/authorized_keys
    echo "${AUTHORIZED_KEYS}" > /root/.ssh/ssh_auto_generate_key.pub
fi
echo "${PRIVATE_KEY}" > /root/.ssh/ssh_auto_generate_key
echo "${CONFIG_FILE}" > /root/.ssh/config
chmod 600 /root/.ssh/ssh_auto_generate_key
chmod 644 /root/.ssh/{ssh_auto_generate_key.pub,authorized_keys,config}
_success "免密环境部署成功"
EOF
}

Tips(){
    _success "此服务器已完成部署，已自动生成子自动部署脚本"
    _success "生成的子脚本会检测所在设备 IP 是否在安装列表中，故其他 IP 的服务器上会自动中断运行"
    _success "请将生成的子脚本放置在以下 IP 的服务器上并执行部署:"
    for i in ${PRE_ADD_LIST}; do
        IP_ADDRESS=$(echo "$i" | cut -d'-' -f3)
        [ "${IP_ADDRESS}" = "${LOCAL_IP}" ] && continue
        _print "$(echo "$i" | cut -d'-' -f3)"
    done
    echo ""
    _success "部署命令: "
    _info "当 authorized_keys 文件不存在或其中存在其他项目写入的免密公钥则实现清理残留文件和配置信息后再完成新信息的配置: "
    _info "bash <(cat $(pwd)/${GEN_SH_NAME}.sh)"
    echo ""
    _info "当 authorized_keys 文件只存在此脚本生成的内容时则实现强制覆盖功能(此脚本重复部署过能确认文件中没有别的项目写入的免密公钥的前提下则使用此命令):"
    _info "bash <(cat $(pwd)/${GEN_SH_NAME}.sh) -o"
    _info "待以上 IP 列表中的所有服务器均部署完毕后，子脚本将保持可用状态直到父脚本重新生成了新的公密钥。"
}

Help(){
    echo "
    批量免密部署工具
    可用选项：
    -l | --pre_add_list                 想用此工具生成的免密部署的服务器列表信息
                                        每台服务器信息可传的内容格式包括四段，用 - 隔开，中间不要有空格
                                        <别名>-<用户名>-<ip>-<ssh端口号>
                                        多个服务器信息之间用空格格开

    -D | --check_dep_sep                一个独立检查脚本工作的所有必须依赖是否满足的功能
                                        和其他选项随便搭配，他总是最先检查的，检查完就自动退出了

    -d | --delete                       此选项将直接删除 /root/.ssh 文件夹，测试用，
                                        生产环境如果此文件夹下有非此工具生成的文件别用这参数

    -C | --commit                       公钥的别名，必须指定
    -h | --help                         打印此信息并退出

    比如三台服务器需要配置相互免密，信息如下: 
    A 独服: 
    IP: 1.1.1.1
    用户名: root
    别名: aaa
    ssh端口号: 22

    B 独服: 
    IP: 2.2.2.2
    用户名: root
    别名: bbb
    ssh端口号: 1111

    C 独服：
    IP: 3.3.3.3
    用户名: root
    别名: ccc
    ssh端口号: 1234

    部署人希望给公钥设置名称为: anshare

    1. 如果这三台服务器本地 /root/.ssh 路径下都存在 authorized_keys 文件且其中内容是其他项目生成的不能删，且此工具从未在此机器上部署过
    则部署命令: 
    bash <(cat $(pwd)/${SH_NAME}.sh) -C \"anshare\" -l \"aaa-root-1.1.1.1-22 bbb-root-2.2.2.2-111 ccc-root-3.3.3.3-1234\"

    2. 如果这三台服务器使用本工具部署过免密操作，本地 /root/.ssh 路径下都存在 authorized_keys 文件且其中内容存在其他项目生成的不能删
    工具的检测环节会从 ssh_auto_generate_key.pub 公钥中读取特征信息并从 authorized_keys 文件中删除失效公钥
    则部署命令: 
    bash <(cat $(pwd)/${SH_NAME}.sh) -C \"anshare\" -l \"aaa-root-1.1.1.1-22 bbb-root-2.2.2.2-111 ccc-root-3.3.3.3-1234\"

    3. 如果这三台服务器全新安装或没有人配置过免密连接的话，本地 /root/.ssh 文件夹都不存在
    则首次部署命令:
    bash <(cat $(pwd)/${SH_NAME}.sh) -C \"anshare\" -l \"aaa-root-1.1.1.1-22 bbb-root-2.2.2.2-111 ccc-root-3.3.3.3-1234\"

    以上三种情况的命令完全相同。

    4. 如果服务器之前并没有任何工具或项目创建了 /root/.ssh 文件夹并往其中写入有关文件的话，部署过本工具的服务器重新部署的话肯定存在残留文件
    以下命令并不会部署而是直接删掉整个 /root/.ssh 文件夹，适合测试本工具并清理垃圾用。
    bash <(cat $(pwd)/${SH_NAME}.sh) -d

    5. 检查脚本工作的所有必须依赖是否满足运行要求，但又不想开始运行脚本本身，就可以用这个命令，检查完成后立刻自动退出
    而且哪怕不小心跟其他选项组合了也没关系，这个选项优先级仅次于清理功能，指定该选项后，一旦检查完，其他所有后续功能都不会被运行:
    bash <(cat $(pwd)/${SH_NAME}.sh) -D
    "
}

if ! ARGS=$(getopt -a -o l:,C:,D,d,h -l pre_add_list:,commit:,check_dep_sep,delete,help -- "$@")
then
    _error "脚本中没有此选项"
    exit 1
elif [ -z "$1" ]; then
    _error "没有设置选项"
    exit 1
elif [ "$1" == "-" ]; then
    _error "选项写法出现错误"
    exit 1
fi
eval set -- "${ARGS}"
while true; do
    case "$1" in
    -l | --pre_add_list)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            PRE_ADD_LIST="$2"
        fi
        shift
        ;;
    -C | --commit)
        if [ "$2" == "-" ]; then
            _error "这是有参选项，必须指定对应参数，否则不能使用该选项！"
            exit 1
        else
            COMMIT_INFO="$2"
        fi
        shift
        ;;
    -D | --check_dep_sep)
        CHECK_DEP_SEP=1
        ;;
    -d | --delete)
        TO_DELETE=1
        ;;
    -h | --help)
        HELP=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

[ "${HELP}" -eq 1 ] && Help && exit 0
InfoCheck
GenerateKey
GenerateScript
Tips