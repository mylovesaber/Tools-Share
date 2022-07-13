#!/bin/bash
# 作者: 欧阳剑宇

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

# 变量名
FIRST_SQL_WORD=
LOCAL_IP=
SH_NAME="auto-generate-key"
GEN_SH_NAME="auto-configure-other-servers"
PRE_ADD_LIST=""
PRE_DROP_LIST=""
COMMIT_INFO=
AUTHORIZED_KEYS=
PRIVATE_KEY=
CONFIG_FILE=
HELP=0
CHECK_DEP_SEP=0
COLORFUL_SHELL=0
SINGLE_OPTION=0
CONFIRM_CONTINUE=0
 
if ! ARGS=$(getopt -a -o l:,C:,D,s,h -l pre_add_list:,commit:,check_dep_sep,colorful_shell,help -- "$@")
then
    _error "脚本中没有此选项"
    exit 1
elif [ -z "$1" ]; then
    _error "没有设置选项"
    exit 1
elif [ "$1" == "-" ]; then
    _error "选项写法出现错误"
    exit 1
else
    # FIRST_SQL_WORD=$(echo "$1"|tr "[:upper:]" "[:lower:]")
    # EXTRAARG=$(echo "${*:2}" | tr -s "[:blank:]")
    FIRST_SQL_WORD=$(echo "$1"|tr "[:upper:]" "[:lower:]")
    declare -a EXTRAARG=("${@:2}")
    for i in "${EXTRAARG[@]}";do
    if ! [[ "$i" =~ ^[a-zA-Z0-9_-:]*$ ]]; then
        _error "传入参数只能包含大小写字母、数字、连字符(-)、下划线(_)和英文冒号(:)"
        exit 1
    fi
    done
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
    -s | --colorful_shell)
        COLORFUL_SHELL=1
        ;;
    -y | --confirm_continue)
        CONFIRM_CONTINUE=1
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

# 功能模块
InfoCheck(){
    # root 检查
	if [ $EUID != 0 ] || [[ $(grep "^$(whoami)" /etc/passwd | cut -d':' -f3) != 0 ]]; then
        _error "没有 root 权限，请运行 \"sudo su -\" 命令并重新运行该脚本"
		exit 1
	fi
    # ssh 版本检查
    LOCAL_SSH_VERSION=$(ssh -V 2>&1 | awk -F '[_,]' '{print $2}' | cut -d 'p' -f1)
    if [ "$(echo | awk "{print(${LOCAL_SSH_VERSION}<7.3)?1:0}")" -eq 1 ]; then
        _error "SSH 版本低于 7.3，不支持本工具的业务节点组的免密策略，为了保证功能性暂未适配低于 7.3 版本的 SSH，退出中"
        exit 1
    fi
    # 检查必要软件包安装情况(集成独立检测依赖功能)
    appList="timeout tput scp pwd basename sort tail tee md5sum ip ifconfig shuf column groups"
    appNotInstalled=""
    for i in ${appList}; do
        if which "$i" >/dev/null 2>&1; then
            [ "${CHECK_DEP_SEP}" == 1 ] && _success "$i 已安装"
        else
            [ "${CHECK_DEP_SEP}" == 1 ] && _error "$i 未安装"
            appNotInstalled="${appNotInstalled} $i"
        fi
    done
    if [ -n "${appNotInstalled}" ]; then
        _error "未安装的软件为: ${appNotInstalled}"
        _error "当前运行环境不支持部分脚本功能，为安全起见，此脚本在重新适配前运行都将自动终止进程"
        exit 1
    elif [ -z "${appNotInstalled}" ]; then
        _success "脚本正常工作所需依赖全部满足要求"
        [ "${CHECK_DEP_SEP}" == 1 ] && exit 0
    fi
    # 检测本机 IP 地址，用于此脚本
    COUNT=0
    LOCAL_NIC_NAME=$(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}')
    for i in $(find /sys/class/net -maxdepth 1 -type l | grep -v "lo\|docker\|br\|veth" | awk -F '/' '{print $NF}');do
        COUNT=$(( COUNT + 1 ))
    done
    if [ "${COUNT}" -lt 1 ]; then
        _error "未检测到网卡，请联系脚本作者进行适配"
        exit 1
    elif [ "${COUNT}" -gt 1 ]; then
        _error "检测到多个网卡，请联系脚本作者进行适配"
        exit 1
    else
        IP_RESULT1=$(ip addr | grep "${LOCAL_NIC_NAME}" | grep inet | awk '{print $2}' | cut -d'/' -f1)
        IP_RESULT2=$(ifconfig "${LOCAL_NIC_NAME}" | grep "inet " | awk '{print $2}')
        if [ "${IP_RESULT1}" = "${IP_RESULT2}" ]; then
            LOCAL_IP=${IP_RESULT1}
            _success "本机 IP 地址已确定! IP 地址: ${LOCAL_IP}"
        else
            _error "检测到本机存在多个 IP，请联系脚本作者适配"
            exit 1
        fi
    fi
}

CheckOption(){
    [ -z "${PRE_ADD_LIST}" ] && _error "必须指定要生成免密信息的服务器列表" && exit 1
    [ -z "${COMMIT_INFO}" ] && _error "必须指定公钥的备注信息" && exit 1
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
        if [[ "${SSH_PORT}" =~ ^[0-9]*$ ]]; then
            _error "端口号存在非数字字符，请检查传入的服务器信息字段的顺序是否有错"
            _error "错误的端口号信息: ${SSH_PORT}"
        elif [ "${SSH_PORT}" -le 1 ] || [ "${SSH_PORT}" -gt 65535 ]; then
            _error "端口号超过规定值[1-65535]"
            _error "错误的端口号: ${SSH_PORT}"
            exit 1
        fi
        COUNT=$(( COUNT + 1 ))
    done
    if [ "${SINGLE_OPTION}" -ne 1 ]; then
        if [ "${COUNT}" -le 1 ]; then
            _error "服务器信息列表必须包含至少两组服务器信息"
            exit 1
        else
            _error "未知错误，请联系脚本作者"
            exit 1
        fi
    fi
    _success "全部输入信息格式均正确且所有服务器处于可连接状态，开始配置并生成一键免密配置脚本"
}

GenerateKey(){
    if [ -d /root/.ssh/ssh_auto_generate ]; then
        _info "发现本工具部署残留，清理中"
        LABEL=$(awk '{print $NF}' /root/.ssh/ssh_auto_generate_key.pub)
        sed -i "/${LABEL}/d" /root/.ssh/authorized_keys
        rm -rf /root/.ssh/ssh_auto_generate
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


MySQLOperation(){
    FIRST_KEYWORD=(select create drop show insert delete use)
    MySQLKeywords=(accessible account action add after against aggregate algorithm all alter always analyze and any as asc ascii asensitive at autoextend_size auto_increment avg avg_row_length backup before begin between bigint binary binlog bit blob block bool boolean both btree by byte cache call cascade cascaded case catalog_name chain change changed channel char character charset check checksum cipher class_origin client close coalesce code collate collation column columns column_format column_name comment commit committed compact completion component compressed compression concurrent condition connection consistent constraint constraint_catalog constraint_name constraint_schema contains context continue convert cpu create cross current current_date current_time current_timestamp current_user cursor cursor_name data database databases datafile date datetime day day_hour day_microsecond day_minute day_second deallocate dec decimal declare default default_auth definer delayed delay_key_write delete desc describe deterministic diagnostics directory disable discard disk distinct distinctrow div do double drop dual dumpfile duplicate dynamic each else elseif enable enclosed encryption end ends engine engines enum error errors escape escaped event events every except exchange execute exists exit expansion expire explain export extended extent_size false fast faults fetch fields file file_block_size filter first fixed float float4 float8 flush follows for force foreign format found from full fulltext general generated geometry geometrycollection get get_format global grant grants group group_replication handler hash having help high_priority host hosts hour hour_microsecond hour_minute hour_second identified if ignore ignore_server_ids import in index indexes infile initial_size inner inout insensitive insert insert_method install instance int int1 int2 int3 int4 int8 integer interval into invisible invoker io io_after_gtids io_before_gtids io_thread ipc is isolation issuer iterate join json key keys key_block_size kill language last leading leave leaves left less level like limit linear lines linestring list load local localtime localtimestamp lock locks logfile logs long longblob longtext loop low_priority master master_auto_position master_bind master_connect_retry master_delay master_heartbeat_period master_host master_log_file master_log_pos master_password master_port master_retry_count master_ssl master_ssl_ca master_ssl_capath master_ssl_cert master_ssl_cipher master_ssl_crl master_ssl_crlpath master_ssl_key master_ssl_verify_server_cert master_tls_version master_user match maxvalue max_connections_per_hour max_queries_per_hour max_rows max_size max_updates_per_hour max_user_connections medium mediumblob mediumint mediumtext memory merge message_text microsecond middleint migrate minute minute_microsecond minute_second min_rows mod mode modifies modify month multilinestring multipoint multipolygon mutex mysql_errno name names national natural nchar ndb ndbcluster never new next no nodegroup none not no_wait no_write_to_binlog null number numeric nvarchar offset on one only open optimize optimizer_costs option optionally options or order out outer outfile owner pack_keys page parser partial partition partitioning partitions password phase plugin plugins plugin_dir point polygon port precedes precision prepare preserve prev primary privileges procedure processlist profile profiles proxy purge quarter query quick range read reads read_only read_write real rebuild recover redo_buffer_size redundant references regexp relay relaylog relay_log_file relay_log_pos relay_thread release reload remove rename reorganize repair repeat repeatable replace replicate_do_db replicate_do_table replicate_ignore_db replicate_ignore_table replicate_rewrite_db replicate_wild_do_table replicate_wild_ignore_table replication require reset resignal restore restrict resume return returned_sqlstate returns reverse revoke right rlike rollback rollup rotate routine row_count row_format rtree savepoint schedule schema schemas schema_name second second_microsecond security select sensitive separator serial serializable server session set share show shutdown signal signed simple slave slow smallint snapshot socket some soname sounds source spatial specific sql sqlexception sqlstate sqlwarning sql_after_gtids sql_after_mts_gaps sql_before_gtids sql_big_result sql_buffer_result sql_calc_found_rows sql_no_cache sql_small_result sql_thread sql_tsi_day sql_tsi_hour sql_tsi_minute sql_tsi_month sql_tsi_quarter sql_tsi_second sql_tsi_week sql_tsi_year ssl stacked start starting starts stats_auto_recalc stats_persistent stats_sample_pages status stop storage stored straight_join string subclass_origin subject subpartition subpartitions super suspend swaps switches table tables tablespace table_checksum table_name temporary temptable terminated text than then time timestamp timestampadd timestampdiff tinyblob tinyint tinytext to trailing transaction trigger triggers true truncate type types uncommitted undefined undo undofile undo_buffer_size unicode uninstall union unique unknown unlock unsigned until update upgrade usage use user user_resources use_frm using utc_date utc_time utc_timestamp validation value values varbinary varchar varcharacter variables varying view virtual visible wait warnings week weight_string when where while with without work wrapper write x509 xa xid xml xor year year_month zerofill zone)

    for i in "${FIRST_KEYWORD[@]}";do
        MARK=0
        [ "$i" = "$FIRST_SQL_WORD" ] && MARK=1 && break
    done
    if [ ${MARK} -eq 0 ];then
        _error "非本脚本所需 MySQL 关键字或非 SQL 关键字或使用顺序出错，退出中"
        exit 1
    fi
    # 增加免密节点组
    if [ "${FIRST_SQL_WORD}" = "create" ]; then
        case "${EXTRAARG[0]}" in
            "database")
                CreateDatabaseCheck
                ;;
            "table")
                dd
                ;;
            "user")
                CreateUserCheck
                ;;
            *)
            _error "可用参数:"
            echo -e "database - 创建项目节点组\ntable - 创建节点\nuser - 创建非root无特权用户" | column -t
            exit 1
        esac
        PRE_ADD_LIST=$EXTRAARG
        SINGLE_OPTION=1
    fi

    # 删除免密节点组
    if [[ $FIRST_SQL_WORD == "drop" ]]; then
        PRE_DROP_LIST=$EXTRAARG
        SINGLE_OPTION=1
    fi

    # 查询免密节点组
    if [[ $FIRST_SQL_WORD == "show" ]]; then
        PRE_DROP_LIST=$EXTRAARG
        SINGLE_OPTION=1
    fi
}

# 创建业务节点免密组的检查和执行
CreateDatabaseCheck(){
    # 通用部分
    if [ "${#EXTRAARG[@]}" -eq 1 ];then
        _error "没有输入参数"
        CreateDatabaseCheckFormat
        exit 1
    fi
    for i in "${!EXTRAARG[@]}";do       # unset "${EXTRAARG[0]}" 没法用，暂时不知道原因
        if [ "$i" -eq 0 ]; then
            continue
        else
            NEW_EXTRAARG+=("${EXTRAARG[$i]}")
        fi
    done
    EXTRAARG=("${NEW_EXTRAARG[@]}")
    _info "开始检查免密组结构名合法性"
    # 此选项专用的检查流程
    for GROUP_INFO in "${EXTRAARG[@]}";do
        _info "检查参数: ${GROUP_INFO}"
        if [[ ! "${GROUP_INFO}" =~ ^[a-zA-Z0-9_-:]*$ ]]; then
            _error "创建的业务节点组名只能包含大小写字母、数字、连字符(-)、下划线(_)或英文冒号(:)"
            exit 1
        fi
        if [[ ! "${GROUP_INFO}" =~ ":" ]]; then
            # echo "第一if，如果一个组名不包含冒号就来这  ${GROUP_INFO}"
            GROUP_INFO_LOWERCASE=$(echo "${GROUP_INFO}"|tr "[:upper:]" "[:lower:]")
            for j in "${MySQLKeywords[@]}";do
                if [ "${GROUP_INFO_LOWERCASE}" = "$j" ];then
                    _error "参数不能为 MySQL 的关键字或保留字！退出中" && exit 1
                fi
            done
            GROUP_NAME=${GROUP_INFO}
            _success "组名 ${GROUP_NAME} 检测无误"
        elif [[ "${GROUP_INFO}" =~ ":" ]]; then
            # echo "第二if，如果一个组名包含冒号就来这  ${GROUP_INFO}"
            GROUP_NAME=$(echo "${GROUP_INFO}"|cut -d':' -f 1)
            USER_NAME=$(echo "${GROUP_INFO}"|cut -d':' -f 2)
            if [ "$(echo "${GROUP_INFO}"|tr -cd ':'|wc -m)" -ge 2 ]; then
                # echo "第三if，如果一个组名第三段非空就来这  ${GROUP_INFO}"
                _error "非法字符! 只能存在一个冒号分隔符"
                CreateDatabaseCheckFormat
                exit 1
            else
                for j in "${MySQLKeywords[@]}";do
                    if [ "${GROUP_NAME}" = "$j" ] || [ "${USER_NAME}" = "$j" ];then
                        _error "参数不能为 MySQL 的关键字或保留字！退出中" && exit 1
                    fi
                done
            fi
            if [ -n "${GROUP_NAME}" ] && [ -n "${USER_NAME}" ]; then
                if [ "${USER_NAME}" = "root" ]; then
                    _error "[组名](用户名) 格式只适用于非 root 用户，root 用户请直接写组名，别加冒号"
                    exit 1
                fi
                if ! grep "^${USER_NAME}:" /etc/passwd >/dev/null 2>&1; then
                    _error "用户名: ${USER_NAME} 不存在! 请先通过命令创建此用户(需要用户名和密码)，再为该用户创建节点免密组，例: "
                    echo "bash <(cat $(pwd)/${SH_NAME}.sh) create user \"${USER_NAME}:密码\""
                    exit 1
                fi
            else
                _error "创建的非 root 用户免密组信息不完整"
                CreateDatabaseCheckFormat
                exit 1
            fi
            _success "组名: ${GROUP_NAME}，用户名: ${USER_NAME} 检测无误"
        else
            # echo "未知情况来此 ${GROUP_INFO}"
            _error "未知情况，请联系作者检查"
            CreateDatabaseCheckFormat
            exit 1
        fi
    done
    _success "免密组结构名检查完成，没有错误，开始创建各自业务的节点免密组结构"
    # 开始执行功能
    for GROUP_INFO in "${EXTRAARG[@]}";do
        GROUP_NAME=$(echo "${GROUP_INFO}"|cut -d':' -f 1)
        USER_NAME="$(echo "${GROUP_INFO}"|awk -F ':' '{print $2}')"
        if [ -n "${USER_NAME}" ] && [ -n "${GROUP_NAME}" ]; then
            CreateDatabase "${USER_NAME}" "${GROUP_NAME}"
        elif [ -z "${USER_NAME}" ] && [ -n "${GROUP_NAME}" ]; then
            CreateDatabase "${GROUP_NAME}"
        else
            _error "执行遇到异常情况，退出中"
            exit 1
        fi
    done
}

CreateDatabaseCheckFormat(){
        _error "合法的创建业务节点免密组名格式(必须用双引号将参数包裹起来防止传入系统不识别的符号): "
        echo -e  "root用户: \"组名\"\n非root用户: \"组名:用户名\"" | column -t
        echo "例:"
        echo "bash <(cat $(pwd)/${SH_NAME}.sh) create database \"组名\" \"组名:用户名\" \"组名\"..."
}

CreateDatabase(){
    if [ -z "${USER_NAME}" ]; then
        _info "开始创建用户 ${USER_NAME} 的 ${GROUP_NAME} 业务节点免密组结构"
        if [ ! -d /root/.ssh ]; then
            _warning ".ssh 文件夹未创建，开始创建并修改权限"
            mkdir -p /root/.ssh
            chmod 700 /root/.ssh
        fi
        mkdir -p /root/.ssh/"${GROUP_NAME}"
        chmod 700 /root/.ssh/"${GROUP_NAME}"
        _success "${GROUP_NAME} 业务节点免密组结构创建成功"
    else
        _info "开始创建 root 的 ${GROUP_NAME} 业务节点免密组结构"
        HOME_PATH=$(grep "^${USER_NAME}:" /etc/passwd|cut -d':' -f6)
        CHOWN_GROUP=$(groups "${USER_NAME}"|tr -d ' '|cut -d':' -f2)
        if [ ! -d "${HOME_PATH}"/.ssh ]; then
            _warning ".ssh 文件夹未创建，开始创建并修改权限"
            mkdir -p "${HOME_PATH}"/.ssh
            chown -R "${USER_NAME}":"${CHOWN_GROUP}" "${HOME_PATH}"/.ssh
            chmod -R 700 "${HOME_PATH}"/.ssh
        fi
        chmod 700 "${HOME_PATH}"/.ssh
        mkdir -p "${HOME_PATH}"/.ssh/"${GROUP_NAME}"
        chmod -R 700 "${HOME_PATH}"/.ssh/"${GROUP_NAME}"
        chown -R "${USER_NAME}":"${CHOWN_GROUP}" "${HOME_PATH}"/.ssh/"${GROUP_NAME}"
        _success "${GROUP_NAME} 业务节点免密组结构创建成功"
    fi
}

# 创建用户的检查和执行
CreateUserCheck(){
    # 通用部分
    _info "开始检查准备创建的节点组用户信息"
    if [ "${#EXTRAARG[@]}" -eq 1 ];then
        _error "没有输入参数"
        CreateUserCheckFormat
        exit 1
    fi
    for i in "${!EXTRAARG[@]}";do       # unset "${EXTRAARG[0]}" 没法用，暂时不知道原因
        if [ "$i" -eq 0 ]; then
            continue
        else
            NEW_EXTRAARG+=("${EXTRAARG[$i]}")
        fi
    done
    EXTRAARG=("${NEW_EXTRAARG[@]}")
    _info "开始检查准备创建的节点组用户信息合法性"
    for USER_INFO in "${EXTRAARG[@]}";do
        _info "检查参数: ${USER_INFO}"
        if [[ ! "$i" =~ ^[a-zA-Z0-9_-:]*$ ]]; then
            _error "设置的用户信息只能包含大小写字母、数字、连字符(-)、英文冒号(:)或下划线(_)"
            exit 1
        fi
        if [[ ! "${USER_INFO}" =~ ":" ]]; then
            # echo "第一if，如果一个用户信息没有冒号就来这  ${USER_INFO}"
            _error "用户信息不完整"
            CreateUserCheckFormat
            exit 1
        elif [ "$(echo "${USER_INFO}"|tr -cd ':'|wc -m)" -ge 2 ]; then
            _error "非法字符! 只能存在一个冒号分隔符"
            CreateDatabaseCheckFormat
            exit 1
        elif [ "$(echo "${USER_INFO}"|tr -cd ':'|wc -m)" -eq 1 ]; then
            # echo "只有一个冒号来这"
            USER_NAME=$(echo "${USER_INFO}"|awk -F ':' '{print $1}')
            USER_PASS=$(echo "${USER_INFO}"|awk -F ':' '{print $2}')
            if [ -n "${USER_NAME}" ] && [ -n "${USER_PASS}" ]; then
                # echo "第二if，如果一个用户信息的用户名和密码均非空就来这  ${USER_INFO}"
                USER_NAME_LOWERCASE=$(echo "${USER_INFO}"|tr "[:upper:]" "[:lower:]"|awk -F ':' '{print $1}')
                USER_PASS_LOWERCASE=$(echo "${USER_INFO}"|tr "[:upper:]" "[:lower:]"|awk -F ':' '{print $2}')
                for j in "${MySQLKeywords[@]}";do
                    if [ "${USER_NAME_LOWERCASE}" = "$j" ] || [ "${USER_PASS_LOWERCASE}" = "$j" ];then
                        _error "参数不能为 MySQL 的关键字或保留字！退出中"
                        exit 1
                    fi
                done
                if [ "${USER_NAME}" = "root" ]; then
                    _error "不能创建 root 用户"
                    exit 1
                elif grep "^${USER_NAME}:" /etc/passwd >/dev/null 2>&1; then
                    _error "系统已存在此用户，不能重复创建!"
                    exit 1
                elif grep "^${USER_NAME}:" /etc/passwd >/dev/null 2>&1; then
                    _error "用户名: ${USER_NAME} 已存在! 请删除此用户信息后再次运行"
                    exit 1
                fi
            else
                _error "用户信息不完整"
                CreateUserCheckFormat
                exit 1
            fi
            _success "用户名: \"${USER_NAME}\"，密码: \"${USER_PASS}\"，检测无误"
        else
            _error "未知情况，请联系作者检查"
            CreateUserCheckFormat
            exit 1
        fi
    done
    _success "节点组用户信息检查完成，没有错误，开始创建用户"
    # 开始执行功能
    for USER_INFO in "${EXTRAARG[@]}";do
        USER_NAME=$(echo "${USER_INFO}"|awk -F ':' '{print $1}')
        USER_PASS=$(echo "${USER_INFO}"|awk -F ':' '{print $2}')
        CreateUser "${USER_NAME}" "${USER_PASS}"
    done
}

CreateUserCheckFormat(){
    _error "正确传入用户信息格式(必须用双引号将参数包裹起来防止传入系统不识别的符号):"
    echo "\"用户名:密码\""
    echo "注意: 创建的用户不具备提权能力，如有需求请自行授予"
}

CreateUser(){
    _info "开始创建新用户 ${USER_NAME}"
    useradd -m -s /bin/bash "${USER_NAME}"
    echo "${USER_NAME}":"${USER_PASS}" | /usr/sbin/chpasswd
    USER_HOME_PATH=$(grep "^${USER_NAME}" /etc/passwd|cut -d':' -f6)
    echo "PS1='\[\e[1;31m\]\u\[\e[1;33m\]@\[\e[1;36m\]\h \[\e[1;33m\]\w \[\e[1;35m\]\$ \[\e[0m\]'" >> "${USER_HOME_PATH}"/.bashrc
    _success "账户创建成功"
}

# Main
[ "${HELP}" -eq 1 ] && Help && exit 0
InfoCheck
if [ -z "${FIRST_SQL_WORD}" ]; then
    CheckOption
    GenerateKey
    GenerateScript
    Tips
elif [ -n "${FIRST_SQL_WORD}" ]; then
    MySQLOperation
else
    _error "主选项出现未知情况，退出中"
    exit 1
fi
