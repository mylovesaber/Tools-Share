#!/bin/bash
# 变量初始化
set -e
## 选项变量
vendorEN=
vendorCN=
topPath=
topRedisPath=
rpmTopPath=
buildPath=
buildRootPath=
sourcePath=
sysConfPath=
unitPath=

## 资源变量
linuxDir=
linuxSource=
linuxLink=
linuxSha256=
glibcDir=
glibcSource=
glibcLink=
glibcSha256=
zlibDir=
zlibSource=
zlibLink=
zlibSha256=
xzDir=
xzSource=
xzLink=
xzSha256=
lz4Dir=
lz4Source=
lz4Link=
lz4Sha256=
zstdDir=
zstdSource=
zstdLink=
zstdSha256=
libcapDir=
libcapSource=
libcapLink=
libcapSha256=
opensslDir=
opensslSource=
opensslLink=
opensslSha256=
systemdDir=
systemdSource=
systemdLink=
systemdSha256=

jemallocDir=
jemallocSource=
jemallocLink=
jemallocSha256=

redis6Dir=
redis6Source=
redis6Ver=
redis6Link=
redis6Sha256=
redis7Dir=
redis7Source=
redis7Ver=
redis7Link=
redis7Sha256=
glibcPatchSource=
glibcPatchLink=
glibcPatchSha256=

## 构建变量
passDynamicLinker=
dynamicLinker=
headerPath=
rpathPath=
libPath=

SourceInfo(){
    # gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
    # wget https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.1.11.tar.sign
    # unxz linux-6.1.11.tar.xz
    # gpg2 --verify linux-6.1.11.tar.sign linux-6.1.11.tar
    # 此 sha256 值为校验 linux-6.1.11.tar.xz 而来
    linuxDir=linux-6.1.11
    linuxSource=linux-6.1.11.tar.xz
    linuxLink=https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.1.11.tar.xz
    linuxSha256=581b0560077863c5116512c0b5fd93b97814092c80e6ebebabe88101949af7a1

    # wget https://ftp.gnu.org/gnu/gnu-keyring.gpg
    # gpg2 --keyring ./gnu-keyring.gpg --verify glibc-2.37.tar.xz.sig glibc-2.37.tar.xz
    glibcDir=glibc-2.37
    glibcSource=glibc-2.37.tar.xz
    glibcLink=https://ftp.gnu.org/gnu/glibc/glibc-2.37.tar.xz
    glibcSha256=2257eff111a1815d74f46856daaf40b019c1e553156c69d48ba0cbfc1bb91a43

    # wget https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.xz.asc
    # gpg2 --verify zlib-1.3.tar.xz.asc zlib-1.3.tar.xz
    zlibDir=zlib-1.3
    zlibSource=zlib-1.3.tar.xz
    zlibLink=https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.xz
    zlibSha256=8a9ba2898e1d0d774eca6ba5b4627a11e5588ba85c8851336eb38de4683050a7

    # wget -qO- https://tukaani.org/misc/jia_tan_pubkey.txt | gpg2 --import
    # wget https://tukaani.org/xz/xz-5.4.4.tar.xz.sig
    # gpg2 --verify xz-5.4.4.tar.xz.sig xz-5.4.4.tar.xz
    xzDir=xz-5.4.4
    xzSource=xz-5.4.4.tar.xz
    xzLink=https://tukaani.org/xz/xz-5.4.4.tar.xz
    xzSha256=705d0d96e94e1840e64dec75fc8d5832d34f6649833bec1ced9c3e08cf88132e

    # wget -qO- https://github.com/lz4/lz4/releases/download/v1.9.4/lz4-1.9.4.tar.gz.sha256 | awk '{print $1}'
    lz4Dir=lz4-1.9.4
    lz4Source=lz4-1.9.4.tar.gz
    lz4Link=https://github.com/lz4/lz4/releases/download/v1.9.4/lz4-1.9.4.tar.gz
    lz4Sha256=0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b

    # wget -qO- https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz.sha256 | awk '{print $1}'
    zstdDir=zstd-1.5.5
    zstdSource=zstd-1.5.5.tar.gz
    zstdLink=https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz
    zstdSha256=9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4

    # https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/sha256sums.asc
    # 这链接中有 sha256 及对应版本
    libcapDir=libcap-2.69
    libcapSource=libcap-2.69.tar.xz
    libcapLink=https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.69.tar.xz
    libcapSha256=f311f8f3dad84699d0566d1d6f7ec943a9298b28f714cae3c931dfd57492d7eb

    #wget -qO- https://github.com/openssl/openssl/releases/download/openssl-3.1.3/openssl-3.1.3.tar.gz.sha256 | awk '{print $1}'
    opensslDir=openssl-3.1.3
    opensslSource=openssl-3.1.3.tar.gz
    opensslLink=https://github.com/openssl/openssl/releases/download/openssl-3.1.3/openssl-3.1.3.tar.gz
    opensslSha256=f0316a2ebd89e7f2352976445458689f80302093788c466692fb2a188b2eacf6

    #md5 0d266e5361dc72097b6c18cfde1c0001
    systemdDir=systemd-254
    systemdSource=systemd-254.tar.gz
    systemdLink=https://github.com/systemd/systemd/archive/v254/systemd-254.tar.gz
    systemdSha256=244da7605800a358915e4b45d079b0b89364be35da4bc8d849821e67bac0ce62

    # jemalloc 长期未更新 Release，目前最新版本是 redis 7 系列内置的，6 系列需要替换下内置的 jemalloc 版本
    jemallocDir=jemalloc-5.3.0
    jemallocSource=jemalloc-5.3.0.tar.bz2
    jemallocLink=https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2
    jemallocSha256=2db82d1e7119df3e71b7640219b6dfe84789bc0537983c3b7ac4f7189aecfeaa

    # 这里有两个版本
    # https://github.com/redis/redis-hashes/
    redis6Dir=redis-6.2.13
    redis6Source=redis-6.2.13.tar.gz
    redis6Ver=6
    redis6Link=http://download.redis.io/releases/redis-6.2.13.tar.gz
    redis6Sha256=89ff27c80d420456a721ccfb3beb7cc628d883c53059803513749e13214a23d1

    redis7Dir=redis-7.2.1
    redis7Source=redis-7.2.1.tar.gz
    redis7Ver=7
    redis7Link=http://download.redis.io/releases/redis-7.2.1.tar.gz
    redis7Sha256=5c76d990a1b1c5f949bcd1eed90d0c8a4f70369bdbdcb40288c561ddf88967a4

    #md5 9a5997c3452909b1769918c759eff8a2
    glibcPatchSource=glibc-2.37-fhs-1.patch
    glibcPatchLink=https://www.linuxfromscratch.org/patches/lfs/11.3/glibc-2.37-fhs-1.patch
    glibcPatchSha256=643552db030e2f2d7ffde4f558e0f5f83d3fabf34a2e0e56ebdb49750ac27b0d

}
SourceInfo

PrepareSource(){
    local i j k l
    local -n funcRemoveBuildDirAndFileList=$1
    local -n funcSourcePackageWithLinkList=$2
    local -n funcSourcePackageWithSha256List=$3
    # 删除本地已有的全部解压源码文件夹和补丁文件(无需判断是否存在，直接删)
    for i in "${funcRemoveBuildDirAndFileList[@]}"; do
        rm -rf "${buildPath:?}"/"${i}"
    done

    # 如果本地存在没有的源码包或补丁文件则下载
    for j in "${!funcSourcePackageWithLinkList[@]}"; do
        if [ ! -f "${sourcePath}"/"${j}" ]; then
            wget --continue -P "${sourcePath}" "${funcSourcePackageWithLinkList[$j]}";
        fi
    done

    # 校验 sha256 的值
    for k in "${!funcSourcePackageWithSha256List[@]}"; do
        if [ "$(sha256sum "${sourcePath}"/"${k}"|awk '{print $1}')" != "${funcSourcePackageWithSha256List[$k]}" ]; then
            echo "本地已存在的源码包或补丁文件 ${k} 校验不通过，已删除，请重新运行打包工具以实现重新自动下载，退出中"
            rm -rf "${sourcePath:?}"/"${k}"
            exit 1
        else
            echo "${sourcePath}/${k} 校验通过"
        fi
    done

    # 解压源码包(如果是补丁文件就从 SOURCES 目录直接复制到 BUILD 目录下)
    for l in "${!funcSourcePackageWithSha256List[@]}"; do
        if [[ $(file -b "${sourcePath}"/"${l}") == *"compressed data"* ]]; then
            echo "正在解压 ${sourcePath}/${l}"
            tar xf "${sourcePath}"/"${l}" -C "${buildPath}"
        else
            cp -p "${sourcePath}"/"${l}" "${buildPath}"
        fi
    done
}

SetBuildEnv(){
    # 由于定制了链接库路径，构建 rpm 包的方式是直接在系统最终位置生成所需环境，
    # 然后移动到 rpmbuild 构建环境中制作 rpm 包，要特别注意权限问题
    # 默认设计为：topPath 变量值不能为空，且 topRedisPath 对应绝对路径必须是 topPath 的子路径

    if [ -z "${topPath}" ] || [ -z "${topRedisPath}" ]; then
        echo "构建时选项 --top-path 和 --top-redis-path 均不能为空，请检查，退出中"
        exit 1
    fi

    if [[ ! ${topRedisPath} =~ ${topPath} ]]; then
        echo "构建时选项 --top-path 必须是 --top-redis-path 的父级路径（不限层级），请检查，退出中"
        exit 1
    fi

    if [[ $(stat -c %U "${topPath}") != $(whoami) ]]; then
        echo "请在 root 账户下将 ${top_path} 的属主改成当前账户 $(whoami) 后重新构建 rpm 包"
        echo "退出中"
        exit 1
    fi

    # x86_64 和 aarch64 使用以下相同的配置
    rpathPath="-Wl,--rpath=${topRedisPath}/deps/usr/lib"
    passDynamicLinker="-Wl,--dynamic-linker=${topRedisPath}/deps/usr/bin/ld.so"
    dynamicLinker="${topRedisPath}/deps/usr/bin/ld.so"
    headerPath="-I${topRedisPath}/deps/usr/include"
    libPath="-L${topRedisPath}/deps/usr/lib"

    # 清理已经存在的 redis 安装路径和 linux-header 路径
    rm -rf "${topPath}"/headers "${topRedisPath}"

    mkdir -pv \
        "${topRedisPath}"/deps/{etc,var} \
        "${topRedisPath}"/deps/usr/{bin,lib,sbin} \
        "${topPath}"/headers/usr

    if ! grep "^set +h" ~/.bashrc >/dev/null 2>&1; then
        cat >> ~/.bashrc <<BUD
set +h
BUD
    fi
    if ! grep "^PATH=${topRedisPath}/deps/usr/bin:" ~/.bashrc >/dev/null 2>&1; then
        cat >> ~/.bashrc <<BUD
PATH=${topRedisPath}/deps/usr/bin:\$PATH
BUD
    fi
    source ~/.bashrc
}

BuildHeaders(){
    # s0: linux-headers
    cd "${buildPath}"/${linuxDir} || exit 1
    make mrproper
    make headers 1>/dev/null
    find usr/include -type f ! -name '*.h' -delete
    cp -r usr/include "${topPath}"/headers/usr
}

BuildGlibc(){
    # s1: glibc
    cd "${buildPath}"/${glibcDir} || exit 1
    patch -Np1 -i ../${glibcPatchSource} || exit 1
    sed '/width -=/s/workend - string/number_length/' \
        -i stdio-common/vfprintf-process-arg.c
    mkdir -v build
    cd build || exit 1
    echo "rootsbindir=${topRedisPath}/deps/usr/sbin" >configparms
    CFLAGS="${headerPath}:${topPath}/headers/usr/include" \
        LDFLAGS="${rpathPath} ${libPath}" \
        ../configure --prefix="${topRedisPath}"/deps/usr \
        --disable-werror \
        --enable-kernel=3.2 \
        --enable-stack-protector=strong \
        libc_cv_slibdir="${topRedisPath}"/deps/usr/lib
    make -j"$(nproc)"
    make install
    make localedata/install-locales -j"$(nproc)"

    # x86_64 需要修改 ldd 文件中的链接器路径
    sed "/RTLDLIST=.*/c RTLDLIST=\"${dynamicLinker}\"" -i "${topRedisPath}"/deps/usr/bin/ldd

    # 删除最开始的 linux 头文件安装路径，glibc 构建完成就不再需要这东西了
    rm -rf "${topPath}"/headers
}

BuildZlib(){
    # s2: zlib
    cd "${buildPath}"/${zlibDir} || exit 1
    CFLAGS="${headerPath}" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}" \
        ./configure --prefix="${topRedisPath}"/deps/usr
    make -j"$(nproc)"
    #make check
    make install
    rm -fv "${topRedisPath}"/deps/usr/lib/libz.a
}

BuildXz(){
    # s3: xz
    cd "${buildPath}"/${xzDir} || exit 1
    CFLAGS="${headerPath}" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}" \
        ./configure --prefix="${topRedisPath}"/deps/usr \
        --disable-static \
        --disable-doc
    make -j"$(nproc)"
    make install
}

BuildLz4(){
    # s4: lz4
    cd "${buildPath}"/${lz4Dir} || exit 1
    make -j"$(nproc)" \
        CFLAGS="${headerPath}" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}"
    make prefix="${topRedisPath}"/deps/usr install
}

BuildZstd(){
    # s5: zstd
    # 缺少 ${libPath} 会导致 zstd 构建时取消对 lz4 的支持
    cd "${buildPath}"/${zstdDir} || exit 1
    make -j"$(nproc)" \
        prefix="${topRedisPath}"/deps/usr \
        CFLAGS="-fPIC ${headerPath}" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath} -shared"
    make prefix="${topRedisPath}"/deps/usr install
}

BuildLibcap(){
    # s6: libcap
    cd "${buildPath}"/${libcapDir} || exit 1
    sed -i '/install -m.*STA/d' libcap/Makefile
    sed -i -e '/empty:/,/^$/d' -e '/loader.txt:/,/^$/d' libcap/Makefile
    echo -e "${dynamicLinker}" | tr -d '\n' >libcap/loader.txt
    sed -i "/\$(MAKE) -C tests \$@/s/^/#/; /\$(MAKE) -C doc \$@/s/^/#/" Makefile
    make -j"$(nproc)" \
        prefix="${topRedisPath}"/deps/usr lib=lib \
        CFLAGS="${headerPath} -fPIC" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}"
    make prefix="${topRedisPath}"/deps/usr lib=lib install
}

BuildOpenssl(){
    # s7: openssl
    cd "${buildPath}"/${opensslDir} || exit 1
    CFLAGS="${headerPath}" \
        LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}" \
        ./config --prefix="${topRedisPath}"/deps/usr \
        --openssldir="${topRedisPath}"/deps/etc/ssl \
        --libdir=lib \
        shared \
        -DOPENSSL_TLS_SECURITY_LEVEL=2 \
        enable-ec_nistp_64_gcc_128 \
        zlib-dynamic
    make -j"$(nproc)"
    sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
    make MANSUFFIX=ssl install_sw
}

BuildSystemd(){
    # s8: systemd
    local soName
    cd "${buildPath}"/${systemdDir} || exit 1
    LDFLAGS="${rpathPath} ${passDynamicLinker} ${libPath}" \
    meson build
    soName=$(find build -maxdepth 1 -type d -name "libsystemd.so*" | sed 's#build/##; s#.p$##')
    ninja -C build "${soName}"
    cp -p build/{libsystemd.so,libsystemd.so.0,"${soName}"} "${topRedisPath}"/deps/usr/lib

#    # 手动能生效，但自动似乎不生效，还是直接安装 systemd-devel 比较合适
#    # 防止构建 redis 时报 systemd/sd-daemon.h not found 的报错
#    mkdir -p "${topRedisPath}"/deps/usr/lib/systemd
#    cp -p src/systemd/*.h "${topRedisPath}"/deps/usr/lib/systemd
}

BuildRedis(){
# s9: redis
    cd "${buildPath}"/${redisDir} || exit 1

    case "${restArgs[1]}" in
    "redis-6")
        # 更新 jemalloc 版本
        rm -rf "${buildPath}"/${redisDir}/deps/jemalloc
        mv "${buildPath}"/${jemallocDir} "${buildPath}"/${redisDir}/deps/jemalloc
        # 解决 redis 6 系列无法构建成功的问题：zmalloc.h:50:10: fatal error: jemalloc/jemalloc.h: No such file or directory
        sed -i -e 's/--with-version=5.1.0-0-g0/--with-version=5.3.0-0-g0/g; s/cd jemalloc \&\& \.\/configure/cd jemalloc \&\& \.\/configure --disable-cxx/' deps/Makefile
    ;;
    "redis-7")
        if ! grep "WARNINGS+=-Werror" deps/hiredis/Makefile >/dev/null 2>&1; then
            sed -i '/^WARNINGS=/c WARNINGS=-Wall -Wextra -Wstrict-prototypes -Wwrite-strings -Wno-missing-field-initializers' deps/hiredis/Makefile
        fi
    ;;
    esac
    make distclean
    # 各种 redis 版本均存在的 arm 架构 cpu 兼容性问题
    case $(arch) in
    "x86_64")
        sed -e 's/--with-lg-quantum/--with-lg-page=12 --with-lg-quantum/' -i deps/Makefile
    ;;
    "aarch64")
        sed -e 's/--with-lg-quantum/--with-lg-page=16 --with-lg-quantum/' -i deps/Makefile
    ;;
    esac

    # Module API 版本的安全性检查
    local redisModulesAbi moduleApi
    redisModulesAbi=1
    moduleApi=$(sed -n -e 's/#define REDISMODULE_APIVER_[0-9][0-9]* //p' src/redismodule.h)
    if test "${moduleApi}" != "${redisModulesAbi}"; then
        echo "Error: 上游 API 版本现为 ${moduleApi}，现为 ${redisModulesAbi}，退出中"
        exit 1
    fi

    # 不使用 ${libPath} 是此处可能在 x86_64 架构 cpu 上出现构建失败的情况，原因未知
    make -j"$(nproc)" \
        BUILD_TLS=yes \
        USE_WERROR=0 \
        OPENSSL_PREFIX="${topRedisPath}"/deps/usr \
        MALLOC=jemalloc \
        USE_SYSTEMD=yes \
        CFLAGS="${headerPath} -fPIC" \
        LDFLAGS="${rpathPath} ${passDynamicLinker}"

    # 创建 redis 应用专属目录并转移构建好的 redis 相关二进制到最终目录下
    mkdir -p "${topRedisPath}"/{bin,run,conf}
    mkdir -p "${topRedisPath}"/default/{log,data}
    mkdir -p "${topRedisPath}"/modules
    cp -p "${buildPath}"/${redisDir}/src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} "${topRedisPath}"/bin
    chmod 755 "${topRedisPath}"/bin/*

    # 准备一个数组装 1-5 的数组，后面好几个步骤都需要重复5次
    local noArray num
    noArray=( 1 2 3 4 5 )
    for num in "${noArray[@]}"; do
        # redis 进程文件及对应的配置准备五份，做好相关配置文件参数的修改
        cp -rp "${topRedisPath}"/default "${topRedisPath}/${num}"

        cp "${buildPath}/${redisDir}/redis.conf" "${topRedisPath}/conf/redis-${num}.conf"

        # redis 6 和 7 系列 配置文件方面有区别，第一行就是
        sed -i -e "/^# save 3600 1.*/c save 3600 1 300 100 60 10000"                \
               -e "s|^dir .*$|dir ${topRedisPath}/${num}/data|g"                    \
               -e "s|^pidfile .*$|pidfile ${topRedisPath}/run/redis-${num}.pid|g"   \
               -e "s|^logfile .*$|logfile ${topRedisPath}/${num}/log/redis.log|g"   \
        "${topRedisPath}/conf/redis-${num}.conf"

        cp "${buildPath}/${redisDir}/sentinel.conf" "${topRedisPath}/conf/sentinel-${num}.conf"

        sed -i -e "s|^pidfile .*$|pidfile ${topRedisPath}/run/redis-sentinel-${num}.pid|g" \
               -e "s|^logfile .*$|logfile ${topRedisPath}/${num}/log/sentinel.log|g" \
        "${topRedisPath}/conf/sentinel-${num}.conf"

    done

    # 删除临时参考目录
    rm -rf "${topRedisPath}"/default
}

BuildStrip(){
# 精简环境(不用打包工具的精简方式是因为会增加其他不想要的检测处理流程)
    local fileList files
    mapfile -t -O "${#fileList[@]}" fileList < <(find "${topRedisPath}" -type f)
    echo "num=${#fileList[@]}"
    for files in "${fileList[@]}";do
        strip --strip-unneeded "${files}" >/dev/null 2>&1
    done
    return 0
}

InstallFile(){
    # 转移实际位置的全部二进制到打包环境中
    # 这里设定几个规则：
    # - vendor-en 必须有值作为区分系统官方制作的 redis 的区分名称
    # - buildroot-path 和 sys-conf-path 和 unit-path 一定要有值，否则安装流程没法进行
    # - top-redis-path 和 top-path 至少要有一个有值以确定 redis 安装总目录
    # 这里假定有两种传参情况：
    # - 如果 top-redis-path 有合规路径，无论 top-path 是否有值，直接使用 top-redis-path 路径
    # - 如果 top-redis-path 无值，但 top-path 有值，则在 top-path 下创建 vendor-en文件夹，然后进入后再创建 redis 文件夹，最终进入 redis 目录后的绝对路径作为 top-redis-path 路径
    if [ -z "${vendorEN}" ] || [ -z "${buildRootPath}" ] || [ -z "${sysConfPath}" ] || [ -z "${unitPath}" ]; then
        echo "vendor-en / buildroot-path / sys-conf-path / unit-path 选项必须都有值，退出中"
        exit 1
    fi
    if [ -z "${topRedisPath}" ] && [ -z "${topPath}" ]; then
        echo "top-path 和 top-redis-path 至少要有一个选项有值，退出中"
        exit 1
    elif [ -n "${topRedisPath}" ]; then
        :
    elif [ -n "${topPath}" ]; then
        topRedisPath="${topPath}/${vendorEN}/redis"
    fi

    # 本定制版 redis 只去加载构建好的二进制 module 而不是去开发，故跳过 headers 和 macro 的安装

    # 准备临时安装目录
    mkdir -p                                                                            \
    "${buildRootPath}${unitPath}"                                                       \
    "${buildRootPath}${topRedisPath}"                                                   \
    "${buildRootPath}${sysConfPath}/logrotate.d"                                        \
    "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d"
    # 将构建好的整个路径转移到临时安装目录
    mv "${topRedisPath}"/* "${buildRootPath}${topRedisPath}"

    #######################################################################################################################################
    # 安装 logrotate 文件
    cat > "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}" <<EOF
${topRedisPath}/log/*.log {
    weekly
    rotate 10
    copytruncate
    delaycompress
    compress
    notifempty
    missingok
}
EOF
    chmod 644 "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}"

    #######################################################################################################################################
    # 安装 systemd 单元文件
    cat > "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}.service" <<EOF
[Unit]
Description=Redis ${redisVer} ${vendorCN}定制版
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${topRedisPath}/bin/redis-server ${topRedisPath}/conf/redis.conf --daemonize no --supervised systemd
Type=notify
User=redis-${vendorEN}
Group=${vendorEN}
RuntimeDirectory=redis-${redisVer}-${vendorEN}
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}.service"

    #######################################################################################################################################
    cat > "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}.service" <<EOF
[Unit]
Description=Redis Sentinel ${redisVer} ${vendorCN}定制版
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${topRedisPath}/bin/redis-sentinel ${topRedisPath}/conf/sentinel.conf --daemonize no --supervised systemd
Type=notify
User=redis-${vendorEN}
Group=${vendorEN}
RuntimeDirectory=redis-sentinel-${redisVer}-${vendorEN}
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}.service"

    #######################################################################################################################################
    # 安装 systemd limit 文件
    cat > "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d/limit.conf" <<EOF
[Service]
# If you need to change max open file limit
# for example, when you change maxclient in configuration
# you can change the LimitNOFILE value below.
# See "man systemd.exec" for more information.

# Slave nodes on large system may take lot of time to start.
# You may need to uncomment TimeoutStartSec and TimeoutStopSec
# directives below and raise their value.
# See "man systemd.service" for more information.

LimitNOFILE=10240
#TimeoutStartSec=90s
#TimeoutStopSec=90s
EOF
    chmod 644 "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d/limit.conf"

    #######################################################################################################################################
    # 准备一个数组装 1-5 的数组，后面好几个步骤都需要重复5次
    local noArray num
    noArray=( 1 2 3 4 5 )
    for num in "${noArray[@]}"; do
        cp -p "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}" "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}-${num}"
        sed -i -e "s|.*log.*|${topRedisPath}/${num}/log/*.log {|g" "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}-${num}"

        cp -p "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}.service" "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}-${num}.service"
        sed -i -e "s|redis\.conf|redis-${num}.conf|g; s|RuntimeDirectory=redis-${redisVer}-${vendorEN}|RuntimeDirectory=redis-${redisVer}-${vendorEN}-${num}|g" "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}-${num}.service"

        cp -p "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}.service" "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}-${num}.service"
        sed -i -e "s|sentinel\.conf|sentinel-${num}.conf|g; s|RuntimeDirectory=redis-sentinel-${redisVer}-${vendorEN}|RuntimeDirectory=redis-sentinel-${redisVer}-${vendorEN}-${num}|g" "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}-${num}.service"

        cp -rp "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d" "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}-${num}.service.d"
        cp -rp "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d" "${buildRootPath}${sysConfPath}/systemd/system/redis-sentinel-${redisVer}-${vendorEN}-${num}.service.d"
    done

    # 删除原始档案
    rm -rv                                                                                  \
    "${buildRootPath}${sysConfPath}/logrotate.d/redis-${redisVer}-${vendorEN}"                          \
    "${buildRootPath}${unitPath}/redis-${redisVer}-${vendorEN}.service"                                 \
    "${buildRootPath}${unitPath}/redis-sentinel-${redisVer}-${vendorEN}.service"                        \
    "${buildRootPath}${sysConfPath}/systemd/system/redis-${redisVer}-${vendorEN}.service.d/limit.conf"
}

# 选项
if ! ARGS=$(getopt -a -o e:c:t:r:T:B:b:S:s:u: -l vendor-en:,vendor-cn:,top-path:,top-redis-path:,rpm-top-path:,build-path:,buildroot-path:,source-path:,sys-conf-path:,unit-path: -- "$@")
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
    -e | --vendor-en)
        vendorEN=$2
        shift
        ;;
    -c | --vendor-cn)
        vendorCN=$2
        shift
        ;;
    # top-path 是 top-redis-path 不限层级的父路径，在 spec 文件中可以看到的默认设计：
    # top-redis-path 是 top-path 里面套一个名为 vendor-en 的子目录，其下再嵌套一个名为 redis 的目录
    # 当然，需要定制 redis 本身文件夹名称的情况下，可以不使用 spec 文件中的 top_redis_path 宏而是直接指定一个绝对路径
    -t | --top-path)
        topPath="${2/%\/}"
        shift
        ;;
    -r | --top-redis-path)
        topRedisPath="${2/%\/}"
        shift
        ;;
    # rpmbuild 目录的绝对路径
    -T | --rpm-top-path)
        rpmTopPath="${2/%\/}"
        shift
        ;;
    # rpmbuild 目录中的 BUILD 目录的绝对路径
    -B | --build-path)
        buildPath="${2/%\/}"
        shift
        ;;
    # rpmbuild 目录中的 BUILDROOT 目录的绝对路径
    -b | --buildroot-path)
        buildRootPath="${2/%\/}"
        shift
        ;;
    # rpmbuild 目录中的 SOURCES 目录的绝对路径
    -S | --source-path)
        sourcePath="${2/%\/}"
        shift
        ;;
    -s | --sys-conf-path)
        sysConfPath="${2/%\/}"
        shift
        ;;
    -u | --unit-path)
        unitPath="${2/%\/}"
        shift
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

restArgs=("$@")
if [ "${#restArgs[@]}" -gt 2 ]; then
    echo "除了选项和对应参数外，只能指定两个参数："
    echo " - spec 打包阶段名：prep/build/install"
    echo " - redis 大版本代号：redis-6/redis-7"
    echo "退出中"
    exit 1
fi

case "${restArgs[1]}" in
    "redis-6")
        # 为多个 redis 版本设置一个代理变量
        redisDir=${redis6Dir}
        redisSource=${redis6Source}
        redisVer=${redis6Ver}
        redisLink=${redis6Link}
        redisSha256=${redis6Sha256}
        case "${restArgs[0]}" in
            "prep")
                removeBuildDirAndFileList=(
                    "${linuxDir}"
                    "${glibcDir}"
                    "${zlibDir}"
                    "${xzDir}"
                    "${lz4Dir}"
                    "${zstdDir}"
                    "${libcapDir}"
                    "${opensslDir}"
                    "${systemdDir}"
                    "${redisDir}"
                    "${glibcPatchSource}"
                )
                declare -A sourcePackageWithLinkList sourcePackageWithSha256List
                sourcePackageWithLinkList=(
                    [${linuxSource}]=${linuxLink}
                    [${glibcSource}]=${glibcLink}
                    [${zlibSource}]=${zlibLink}
                    [${xzSource}]=${xzLink}
                    [${lz4Source}]=${lz4Link}
                    [${zstdSource}]=${zstdLink}
                    [${libcapSource}]=${libcapLink}
                    [${opensslSource}]=${opensslLink}
                    [${systemdSource}]=${systemdLink}
                    [${jemallocSource}]=${jemallocLink}
                    [${redisSource}]=${redisLink}
                    [${glibcPatchSource}]=${glibcPatchLink}
                )
                declare -A sourcePackageWithSha256List
                sourcePackageWithSha256List=(
                    [${linuxSource}]=${linuxSha256}
                    [${glibcSource}]=${glibcSha256}
                    [${zlibSource}]=${zlibSha256}
                    [${xzSource}]=${xzSha256}
                    [${lz4Source}]=${lz4Sha256}
                    [${zstdSource}]=${zstdSha256}
                    [${libcapSource}]=${libcapSha256}
                    [${opensslSource}]=${opensslSha256}
                    [${systemdSource}]=${systemdSha256}
                    [${jemallocSource}]=${jemallocSha256}
                    [${redisSource}]=${redisSha256}
                    [${glibcPatchSource}]=${glibcPatchSha256}
                )
                PrepareSource removeBuildDirAndFileList sourcePackageWithLinkList sourcePackageWithSha256List
            ;;
            "build")
                SetBuildEnv
                BuildHeaders
                BuildGlibc
                BuildZlib
                BuildXz
                BuildLz4
                BuildZstd
                BuildLibcap
                BuildOpenssl
                BuildSystemd
                BuildRedis
                BuildStrip
            ;;
            "install")
                InstallFile
            ;;
            *)
                echo "只有 prep/build/install 这三个选项之一，请重新修改，退出中"
                exit 1
        esac
    ;;
    "redis-7")
        # 为多个 redis 版本设置一个代理变量
        redisDir=${redis7Dir}
        redisSource=${redis7Source}
        redisVer=${redis7Ver}
        redisLink=${redis7Link}
        redisSha256=${redis7Sha256}
        case "${restArgs[0]}" in
            "prep")
                removeBuildDirAndFileList=(
                    "${linuxDir}"
                    "${glibcDir}"
                    "${zlibDir}"
                    "${xzDir}"
                    "${lz4Dir}"
                    "${zstdDir}"
                    "${libcapDir}"
                    "${opensslDir}"
                    "${systemdDir}"
                    "${redisDir}"
                    "${glibcPatchSource}"
                )
                declare -A sourcePackageWithLinkList sourcePackageWithSha256List
                sourcePackageWithLinkList=(
                    [${linuxSource}]=${linuxLink}
                    [${glibcSource}]=${glibcLink}
                    [${zlibSource}]=${zlibLink}
                    [${xzSource}]=${xzLink}
                    [${lz4Source}]=${lz4Link}
                    [${zstdSource}]=${zstdLink}
                    [${libcapSource}]=${libcapLink}
                    [${opensslSource}]=${opensslLink}
                    [${systemdSource}]=${systemdLink}
                    [${redisSource}]=${redisLink}
                    [${glibcPatchSource}]=${glibcPatchLink}
                )
                declare -A sourcePackageWithSha256List
                sourcePackageWithSha256List=(
                    [${linuxSource}]=${linuxSha256}
                    [${glibcSource}]=${glibcSha256}
                    [${zlibSource}]=${zlibSha256}
                    [${xzSource}]=${xzSha256}
                    [${lz4Source}]=${lz4Sha256}
                    [${zstdSource}]=${zstdSha256}
                    [${libcapSource}]=${libcapSha256}
                    [${opensslSource}]=${opensslSha256}
                    [${systemdSource}]=${systemdSha256}
                    [${redisSource}]=${redisSha256}
                    [${glibcPatchSource}]=${glibcPatchSha256}
                )
                PrepareSource removeBuildDirAndFileList sourcePackageWithLinkList sourcePackageWithSha256List
            ;;
            "build")
                SetBuildEnv
                BuildHeaders
                BuildGlibc
                BuildZlib
                BuildXz
                BuildLz4
                BuildZstd
                BuildLibcap
                BuildOpenssl
                BuildSystemd
                BuildRedis
                BuildStrip
            ;;
            "install")
                InstallFile
            ;;
            *)
                echo "只有 prep/build/install 这三个选项之一，请重新修改，退出中"
                exit 1
        esac
    ;;
    *)
        echo "暂时只支持这几种redis大版本代号的多选一参数：redis-5/redis-6/redis-7"
        echo "每个大版本代号均代表此系列版本的最新子版本"
        echo "退出中"
        exit 1
esac
