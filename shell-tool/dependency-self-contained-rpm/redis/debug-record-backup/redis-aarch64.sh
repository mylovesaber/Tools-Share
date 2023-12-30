#!/bin/bash
#########################################################################################
#########################################################################################
#########################################################################################
# 检查办法（root账户）
# 系统默认情况下有一个 /usr/bin/ldd 和 /usr/bin/file
# 本文档定制了动态库的链接器绝对路径为一个定值: /opt/project/deps/usr/lib/ld-linux-aarch64.so.1
# 静态库不用检查，因为自给自足，动态库需要检查链接的库路径是否符合要求

# file: 输出信息没有做任何处理，看输出行中带 interpreter 字样的后面是不是定制的链接器绝对路径，如果不是则说明有问题
file bin/*
file lib/*

# 拷贝 ldd 为 lddd，然后将 lddd 中的链接器绝对路径修改成定制的路径（脚本开头的 RTLDLIST）并保存退出
cp -p /usr/bin/ldd /usr/bin/lddd
sed -i '/^RTLDLIST=/c RTLDLIST=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1' /usr/bin/lddd

# 然后开始检查
cd /opt/project/deps
ldd lib/*.so* 2>&1 | grep -v "/opt/project\|linux-vdso.so.1\|not a dynamic executable\|you do not have execution permission\|ld-linux-aarch64.so.1\|/lib64\|statically linked"
lddd lib/*.so* 2>&1 | grep -v "/opt/project\|linux-vdso.so.1\|not a dynamic executable\|you do not have execution permission\|statically linked"

# ldd 或 lddd 展示出来的形如此报错不用管（按理说以上命令中已经屏蔽了这种情况）：
#lib/libc.so:
#ldd: warning: you do not have execution permission for `lib/libc.so'
#        not a dynamic executable

# ldd 或 lddd 展示出来的类似这些只有库名冒号，后面没有信息的，代表正常编译符合需求：
#lib/liblz4.so:
#lib/liblz4.so.1:
#lib/liblz4.so.1.9.4:

# lddd 展示的漏网之鱼是动态库没有成功链接定制路径的链接器的效果：
#lib/libgmpxx.so:
#        libstdc++.so.6 => not found
#        libgcc_s.so.1 => not found
#lib/libgmpxx.so.4:
#        libstdc++.so.6 => not found
#        libgcc_s.so.1 => not found
#lib/libgmpxx.so.4.7.0:
#        libstdc++.so.6 => not found
#        libgcc_s.so.1 => not found

# ldd 展示的漏网之鱼是以上 lddd 展示的动态库错误链接到系统自带glibc的效果（后续要重新编译修复）：
#lib/libgmpxx.so:
#        libstdc++.so.6 => /lib64/libstdc++.so.6 (0x0000ffff95f80000)
#        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x0000ffff95c50000)
#lib/libgmpxx.so.4:
#        libstdc++.so.6 => /lib64/libstdc++.so.6 (0x0000ffffa49c0000)
#        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x0000ffffa4690000)
#lib/libgmpxx.so.4.7.0:
#        libstdc++.so.6 => /lib64/libstdc++.so.6 (0x0000ffffb6540000)
#        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x0000ffffb6210000)


ldd bin/* 2>&1 | grep -v "/opt/project\|linux-vdso.so.1\|not a dynamic executable\|statically linked\|/lib64"
lddd bin/* 2>&1 | grep -v "/opt/project\|linux-vdso.so.1\|not a dynamic executable\|statically linked"
# ldd 或 lddd 展示出来的类似这些只有库名冒号，后面没有信息的，代表正常编译符合需求：
#bin/bzfgrep:
#bin/bzgrep:
#bin/bzip2:

# 否则 bin下的其他输出信息需要留意是否有漏网之鱼

# 检查的最终目的：
# 1. 确认 file 展示出来的所有包括 interpreter 字样的后面是定制的链接器绝对路径
# 2. 确认 ldd 和 lddd 展示的各二进制程序和动态库链接正确符合预期

#########################################################################################
#########################################################################################
#########################################################################################
# 0. 基本认知
#- c 语言开发的程序有动态库和静态库的分类
#- glibc 本身是高度自给自足的，不会受限于任何操作系统
#- linux 除了内核，软件层面最底层的软件是 glibc，绝大多数软件想要运行都依赖于 glibc，故一个程序想不受限于系统，则必须构建一个独立的glibc
#- 程序运行所需依赖和编译所需依赖不一定相同，即只需确保程序运行时不缺依赖，不用为了编译一个软件而手动编译出其所有编译依赖所需的的程序，对于 c 程序而言，后者等同于将整个操作系统编译出来

#########################################################################################
#########################################################################################
#########################################################################################
# 1. 准备工作
#########################################################################################
#########################################################################################
#########################################################################################

dnf groupinstall "Development Tools" -y
dnf install texinfo gcc-c++ -y
[ -f /usr/bin/yacc ] && mv /usr/bin/yacc /usr/bin/yacc.bak
ln -s /usr/bin/bison /usr/bin/yacc

# 这里只创建依赖所需的通用路径，具体软件的后面再单独创建
mkdir -pv \
    /opt/project/redis/deps/{etc,var} \
    /opt/project/redis/deps/usr/{bin,lib,sbin} \
    /opt/headers/usr

for i in bin lib sbin; do
    ln -sv usr/$i /opt/project/redis/deps/$i
done

case $(uname -m) in
x86_64) mkdir -pv /opt/project/redis/deps/lib64 ;;
esac


chown -vR build /opt


# set +h 至关重要，设置后就可以实时获取并调用新安装的软件了
cat >>/home/build/.bashrc <<BUD
set +h
PATH=/opt/project/redis/deps/usr/bin:\$PATH
BUD
chown build: /home/build/.bashrc

su - build

cd ~/sources

#########################################################################################
#########################################################################################
#########################################################################################
# redis
# 注意后文中为了保险起见，所有 CFLAGS 和 LDFLAGS 均不可以为了易读而写成多行的形式
# 不能排除其他组件都做了适配（适配了的一般会警告说不建议使用多行写法，但编译不会受到影响）
# 比如 zlib 的 configure 中没有将回车转换成空格的代码，导致该脚本后续 sed 会把 LDFLAGS 变量中的回车读进去而报错导致无法生成 Makefile
#########################################################################################
#########################################################################################
#########################################################################################
# linux-headers（编译依赖，非运行依赖）
mkdir -p /opt/headers/usr
tar xfv linux-6.1.11.tar.xz
cd linux-6.1.11
make mrproper

make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include /opt/headers/usr
cd ..
rm -rf linux-6.1.11

#########################################################################################
# glibc
tar xfv glibc-2.37.tar.xz
cd glibc-2.37
patch -Np1 -i ../glibc-2.37-fhs-1.patch
sed '/width -=/s/workend - string/number_length/' \
    -i stdio-common/vfprintf-process-arg.c
mkdir -v build
cd build
echo "rootsbindir=/opt/project/redis/deps/usr/sbin" >configparms

CFLAGS="-I/opt/project/redis/deps/usr/include:/opt/project/headers/usr/include" \
LDFLAGS="-Wl,--rpath=/opt/project/redis/deps/usr/lib" \
../configure --prefix=/opt/project/redis/deps/usr \
--disable-werror \
--enable-kernel=3.2 \
--enable-stack-protector=strong \
libc_cv_slibdir=/opt/project/redis/deps/usr/lib
make -j$(nproc)
make install
make localedata/install-locales -j$(nproc)
# 可以不写
#sed '/RTLDLIST=/s@/usr@@g' -i /opt/project/deps/usr/bin/ldd
cd ../../
rm -rf glibc-2.37

#########################################################################################
# Zlib-1.2.13
tar xfv zlib-1.2.13.tar.xz
cd zlib-1.2.13
CFLAGS="-I/opt/project/deps/usr/include" \
LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1" \
./configure --prefix=/opt/project/deps/usr
make -j$(nproc)
#make check
make install
rm -fv /opt/project/deps/usr/lib/libz.a

# 对照组
make DESTDIR=/home/build/zlib install
rm -fv /home/build/zlib/opt/project/deps/usr/lib/libz.a
# 实测正确链接到了指定的glibc中，所以不用单独执行该命令了

cd ..
rm -rf zlib-1.2.13

#########################################################################################
# Xz-5.4.1
tar xfv xz-5.4.1.tar.xz
cd xz-5.4.1
CFLAGS="-I/opt/project/deps/usr/include" \
LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1" \
./configure --prefix=/opt/project/deps/usr \
    --disable-static \
    --disable-doc
make -j$(nproc)

make install

# 对照组
make DESTDIR=/home/build/xz install
# 需要安装到构建时指定的路径下 lzma 有关的链接才会正常，DESTDIR 会提示库文件 not found

cd ..
rm -rf xz-5.4.1

#########################################################################################
# lz4-1.9.4
# 不在lfs自带功能中(当前最新版是 1.9.4)
# https://github.com/lz4/lz4
# wget -P ~/sources "$(curl -s https://api.github.com/repos/lz4/lz4/releases/latest | grep -o '.browser_download_url.*.tar.gz"' | awk -F '"' '{print $(NF-1)}')"

wget -P ~/sources https://github.com/lz4/lz4/releases/download/v1.9.4/lz4-1.9.4.tar.gz
tar xfv lz4-1.9.4.tar.gz
cd lz4-1.9.4
make -j$(nproc) \
    CFLAGS="-I/opt/project/deps/usr/include" \
    LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"

# 注意在编译时指定路径没有效果，必须在 install 的时候指定路径，否则将会试图安装进系统默认的 /usr/local 下
make prefix=/opt/project/deps/usr install

# 对照组
make prefix=/home/build/lz4/usr install
# 注意别用 DESTDIR，在指定的路径下会生成 /usr/local 路径，prefix 路径需要 /usr ，否则全装到 /home/build/lz4 路径下了

cd ..
rm -rf lz4-1.9.4

#########################################################################################
# Zstd-1.5.4
# 依赖于 lz4/zlib/xz
tar xfv zstd-1.5.4.tar.gz
cd zstd-1.5.4
# 注意根据 Makefile 中的构建方式，-fPIC 必须放 CFLAGS 中，LDFLAGS 追加 -shared，否则编译一定报错
make -j$(nproc) \
    prefix=/opt/project/deps/usr \
    CFLAGS=" -fPIC -I/opt/project/deps/usr/include" \
    LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1 -shared"

# prefix后面必须跟usr，否则内置的［bin/include/lib/share］目录就装到/opt/project/deps下了
# 这里不要用DESTDIR，因为zstd会将内置的［bin/include/lib/share］目录装到/opt/project/deps/usr/local下
make prefix=/opt/project/deps/usr install

# 对照组
make prefix=/home/build/zstd/usr install

cd ..
rm -rf zstd-1.5.4

#########################################################################################
# Libcap-2.67
tar xfv libcap-2.67.tar.xz
cd libcap-2.67

# 禁止安装静态库
sed -i '/install -m.*STA/d' libcap/Makefile

# libcap 项目编译的时候获得链接器的路径方式是先用gcc直接编译生成一个编译文件，然后使用 objcopy 将这个 ELF 文件中的链接器的绝对路径读取出来并重定向到loader.txt，
# 之后各种调用链接器的方式都是直接 cat 这个文本文件内容作为变量值（注意，这个变量值是不能带回车的，所以这 txt 文件用文本编辑器打开的话只有一行，而不会像传统文件一样最后一行是空行）
# 因为使用了一个定制路径的glibc，故可以通过屏蔽掉编译 empty 这个二进制文件，用直接创建一个包含了只有一行链接器绝对路径的文件供后续编译调用以实现变更链接器路径
sed -i -e '/empty:/,/^$/d' -e '/loader.txt:/,/^$/d' libcap/Makefile
echo -e "/opt/project/deps/usr/lib/ld-linux-aarch64.so.1" | tr -d '\n' > libcap/loader.txt

# libcap 完整编译除了必要的 libcap 和 prog 外，还默认会编译 tests 和 doc ，另外有两个模块分别需要 go 环境和 pam_modules.h 头文件已安装，如果没装则不会编译，
# redis/nginx/mysql/mariadb/postgresql 内置用户认证和授权机制，对 Linux-PAM 也不是刚需，可以不编译这个库

# 如果只编译 libcap 和 prog，则可以改一下 Makefile：
sed -i '/$(MAKE) -C tests \$@/s/^/#/; /$(MAKE) -C doc \$@/s/^/#/' Makefile

make -j$(nproc) \
prefix=/opt/project/deps/usr lib=lib \
CFLAGS="-I/opt/project/deps/usr/include -fPIC" \
LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"

# 以下是用于测试：编译是否正常的，测试过没问题，可跳过
make test\
CFLAGS="-I/opt/project/deps/usr/include -fPIC" \
LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"

# 注意直接 install 的时候会报几次错(/sbin/ldconfig: Can't create temporary cache file /etc/ld.so.cache~: Permission denied)
# 不用在意，因为构建的用户不是 root 用户没有权限运行，而 Makefile 中对于此命令的调用结果，设置的特性是运行结果报错也没事，所以不用管，因为最终该命令应该由 root 账户来执行
make prefix=/opt/project/deps/usr lib=lib install



# 对照组(个别库需要安装到构建时指定的路径下才可以编译)
make prefix=/home/build/libcap/usr lib=lib install

cd ..
rm -rf libcap-2.67

#########################################################################################
# libsystemd.so 运行依赖于：
# - libcap.so.2
# - liblzma.so.5
# - libzstd.so.1
# - glibc 的库
# 至于 lz4 只是 zstd 构建时默认会查找并构建的依赖支持，可有可无，那就带上吧，反正体积不大
#########################################################################################
# 8.47. OpenSSL-3.1.3
# 需要先安装 openssl 的编译依赖，它不是运行依赖，openssl 运行依赖是 zlib 和 glibc
dnf install perl -y

tar xfv openssl-3.1.3.tar.gz
cd openssl-3.1.3
CFLAGS="-I/opt/project/deps/usr/include" \
LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1" \
./config --prefix=/opt/project/deps/usr \
    --openssldir=/opt/project/deps/etc/ssl \
    --libdir=lib \
    shared \
    -DOPENSSL_TLS_SECURITY_LEVEL=2 \
    enable-ec_nistp_64_gcc_128 \
    zlib-dynamic
make -j$(nproc)
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install_sw

# 对照组
make MANSUFFIX=ssl DESTDIR=/home/build/aaa install_sw


cd ..
rm -rf openssl-3.1.3

#########################################################################################
# systemd
sudo dnf install meson gperf python3.12 python3-pip libcap-devel libmount-devel cmake

tar xfv systemd-252.tar.gz
cd systemd-252
patch -Np1 -i ../systemd-252-security_fix-1.patch

# meson 单独构建库文件有两种写法
## 方法一：
#mkdir -p build
#cd       build
#meson ..
#soName=$(find . -maxdepth 1 -type d -name libsystemd.so* | sed  's#./##; s#.p$##')
#ninja ${soName}

# 方法二：
# 运行 meson 会有一堆红色 NO，只要不是报错退出就不用管，毕竟只需要编译 libsystemd 的库文件
meson build
soName=$(find build -maxdepth 1 -type d -name libsystemd.so* | sed  's#build/##; s#.p$##')
ninja -C build ${soName}


cp -p build/{libsystemd.so,libsystemd.so.0,"${soName}"} /opt/project/deps/usr/lib
cd ..
rm -rf systemd-252

#########################################################################################
# redis
# 运行依赖只有 openssl / glibc
wget -P ~/sources https://download.redis.io/redis-stable.tar.gz
tar -xvf redis-stable.tar.gz
cd redis-stable
make distclean

## 以下是手动编译以查找报错原因的操作
#cd deps
#make -j$(nproc) fpconv  hdr_histogram  hiredis  jemalloc  linenoise  lua
#
# 注意，redis编译会报错，错误源头不是redis，而是hiredis这个模块的Makefile中设置了一个Werror选项，即将任何警告视为错误
# 然而glibc自带的一个limits.h的头文件会导致hiredis报错，经测试重命名此文件就不会触发该报错，而redis编译需要这个文件，
#In file included from net.c:42:
#/opt/project/deps/usr/include/limits.h:124:3: error: #include_next is a GCC extension [-Werror]
#  124 | # include_next <limits.h>
#      |   ^~~~~~~~~~~~
# 这导致hiredis没有编译完成就报错退出该进程了，而报错返回值传递给了redis的Makefile，这导致redis发现编译过程中有出错所以报错退出
# 因为hiredis因为报错的原因导致根本就没编译，此时再重复编译 redis 就会提示缺少 libhiredis.a 和 libhiredis_ssl.a 而报错退出
# 所以需要手动修改hiredis的Makefile才能避免，而hiredis仓库中已经有此修复，只是稳定版redis中没有此修复，所以要么等官方patch，要么手动添加判定代码
# 有关commit： https://github.com/redis/hiredis/commit/bff171c9fc83f8abed9a283a3da2dc91a5671419
# 修复后的用法是默认视警告为报错，但提供USE_WERROR选项，只要值不是1就可以只作为警告继续编译
# 例：
#make -j$(nproc) USE_WERROR=0

# 在官方修复之前可以不 patch，可以直接修改此文件删掉 Werror 就不需要新增选项了
# 还是加上判断吧，后面 make 也增加 USE_WERROR=0 免得后续官方更新了还得关注这事情：
if ! grep "WARNINGS+=-Werror" deps/hiredis/Makefile >/dev/null 2>&1; then sed -i '/^WARNINGS=/c WARNINGS=-Wall -Wextra -Wstrict-prototypes -Wwrite-strings -Wno-missing-field-initializers' deps/hiredis/Makefile;fi

# 注意，mac 的 arm64 架构 cpu 的内存分页是 4k，传统 aarch64 的 linux 内核是 64k，
# 这导致使用 mac 编译不能使用默认配置下的 jemalloc，即便 redis 7.2 已经支持了，一种是直接用 libc，一种是修改 jemalloc 的 Makefile。

# 方案一（jemalloc）：
case $(arch) in
    "x86_64"|"s390x")
        sed -e 's/--with-lg-quantum/--with-lg-page=12 --with-lg-quantum/' -i deps/Makefile
    ;;
    "ppc64"|"ppc64le"|"aarch64")
        sed -e 's/--with-lg-quantum/--with-lg-page=16 --with-lg-quantum/' -i deps/Makefile
    ;;
esac

# 构建源码中有两种 SYSTEMD 变量，经过阅读代码，能确认 BUILD_WITH_SYSTEMD 无需外部指定，直接指定 USE_SYSTEMD=yes 即可，
# 这两个变量赋值靠的是自动检测，BUILD_WITH_SYSTEMD 的值受到 USE_SYSTEMD 值的影响
make -j$(nproc) \
    BUILD_TLS=yes \
    USE_WERROR=0 \
    OPENSSL_PREFIX=/opt/project/deps/usr \
    MALLOC=jemalloc \
    USE_SYSTEMD=yes \
    CFLAGS="-I/opt/project/deps/usr/include -fPIC" \
    LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"

## 方案二（libc）：
#make -j$(nproc) \
#    BUILD_TLS=yes \
#    USE_WERROR=0 \
#    OPENSSL_PREFIX=/opt/project/deps/usr \
#    MALLOC=libc \
#    USE_SYSTEMD=yes \
#    CFLAGS="-I/opt/project/deps/usr/include -fPIC" \
#    LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"



## 如果需要测试：
#if ! grep "WARNINGS+=-Werror" deps/hiredis/Makefile >/dev/null 2>&1; then sed -i '/^WARNINGS=/c WARNINGS=-Wall -Wextra -Wstrict-prototypes -Wwrite-strings -Wno-missing-field-initializers' deps/hiredis/Makefile;fi
#make test -j$(nproc) \
#    BUILD_TLS=yes \
#    USE_WERROR=0 \
#    OPENSSL_PREFIX=/opt/project/deps/usr \
#    MALLOC=jemalloc \
#    USE_SYSTEMD=yes \
#    CFLAGS="-I/opt/project/deps/usr/include -fPIC" \
#    LDFLAGS="-Wl,--rpath=/opt/project/deps/usr/lib -Wl,--dynamic-linker=/opt/project/deps/usr/lib/ld-linux-aarch64.so.1"
## 如果出现这种报错，可能只是 gcc 的 bug，可以忽略：
##*** [err]: Server is able to generate a stack trace on selected systems in tests/integration/logging.tcl
##log message of '"*debugCommand*"' not found in ./tests/tmp/server.log.846627.32/stdout after line: 0 till line: 41
## 除了一些 ignore 以外几乎都应该是 ok 的



# redis 无需安装，就几个文件复制过去自定义路径结构即可
getent group project &> /dev/null || \
groupadd -r project &> /dev/null
getent passwd project &> /dev/null || \
useradd -r -g project -d /opt/project -s /sbin/nologin \
-c 'Redis Database Server Customized By ouyang@project' project &> /dev/null

# sudo usermod -a -G project build

mkdir -p /opt/project/redis/{bin,run,conf}
mkdir -p /opt/project/redis/1/{log,data}
cp -rp /opt/project/redis/1 /opt/project/redis/2
cp -rp /opt/project/redis/1 /opt/project/redis/3
cp -rp /opt/project/redis/1 /opt/project/redis/4
cp -rp /opt/project/redis/1 /opt/project/redis/5
cp -p src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} /opt/project/redis/bin
chmod 755 /opt/project/redis/bin/*


cp -p {redis.conf,sentinel.conf} /opt/project/redis/conf
mv /opt/project/redis/conf/redis.conf /opt/project/redis/conf/redis-1.conf
cp -p /opt/project/redis/conf/redis-1.conf /opt/project/redis/conf/redis-2.conf
cp -p /opt/project/redis/conf/redis-1.conf /opt/project/redis/conf/redis-3.conf
cp -p /opt/project/redis/conf/redis-1.conf /opt/project/redis/conf/redis-4.conf
cp -p /opt/project/redis/conf/redis-1.conf /opt/project/redis/conf/redis-5.conf

sed -i -e 's|^dir .*$|dir /opt/project/redis/1/data|g' /opt/project/redis/conf/redis-1.conf
sed -i -e 's|^dir .*$|dir /opt/project/redis/2/data|g' /opt/project/redis/conf/redis-2.conf
sed -i -e 's|^dir .*$|dir /opt/project/redis/3/data|g' /opt/project/redis/conf/redis-3.conf
sed -i -e 's|^dir .*$|dir /opt/project/redis/4/data|g' /opt/project/redis/conf/redis-4.conf
sed -i -e 's|^dir .*$|dir /opt/project/redis/5/data|g' /opt/project/redis/conf/redis-5.conf

sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-1.pid|g' /opt/project/redis/conf/redis-1.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-2.pid|g' /opt/project/redis/conf/redis-2.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-3.pid|g' /opt/project/redis/conf/redis-3.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-4.pid|g' /opt/project/redis/conf/redis-4.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-5.pid|g' /opt/project/redis/conf/redis-5.conf

sed -i -e 's|^logfile .*$|logfile /opt/project/redis/1/log/redis.log|g' /opt/project/redis/conf/redis-1.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/2/log/redis.log|g' /opt/project/redis/conf/redis-2.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/3/log/redis.log|g' /opt/project/redis/conf/redis-3.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/4/log/redis.log|g' /opt/project/redis/conf/redis-4.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/5/log/redis.log|g' /opt/project/redis/conf/redis-5.conf


mv /opt/project/redis/conf/sentinel.conf /opt/project/redis/conf/sentinel-1.conf
cp -p /opt/project/redis/conf/sentinel-1.conf /opt/project/redis/conf/sentinel-2.conf
cp -p /opt/project/redis/conf/sentinel-1.conf /opt/project/redis/conf/sentinel-3.conf
cp -p /opt/project/redis/conf/sentinel-1.conf /opt/project/redis/conf/sentinel-4.conf
cp -p /opt/project/redis/conf/sentinel-1.conf /opt/project/redis/conf/sentinel-5.conf

sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-sentinel-1.pid|g' /opt/project/redis/conf/sentinel-1.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-sentinel-2.pid|g' /opt/project/redis/conf/sentinel-2.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-sentinel-3.pid|g' /opt/project/redis/conf/sentinel-3.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-sentinel-4.pid|g' /opt/project/redis/conf/sentinel-4.conf
sed -i -e 's|^pidfile .*$|pidfile /opt/project/redis/run/redis-sentinel-5.pid|g' /opt/project/redis/conf/sentinel-5.conf

sed -i -e 's|^logfile .*$|logfile /opt/project/redis/1/log/sentinel.log|g' /opt/project/redis/conf/sentinel-1.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/2/log/sentinel.log|g' /opt/project/redis/conf/sentinel-2.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/3/log/sentinel.log|g' /opt/project/redis/conf/sentinel-3.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/4/log/sentinel.log|g' /opt/project/redis/conf/sentinel-4.conf
sed -i -e 's|^logfile .*$|logfile /opt/project/redis/5/log/sentinel.log|g' /opt/project/redis/conf/sentinel-5.conf

########################################################################################################################################
########################################################################################################################################
# 这段要用 root 运行
cat >/etc/systemd/system/redis-1-project.service <<EOF
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/opt/project/redis/bin/redis-server /opt/project/redis/conf/redis-1.conf --daemonize no --supervised systemd
Type=notify
User=project
Group=project
RuntimeDirectory=redis
RuntimeDirectoryMode=0755
[Install]
WantedBy=multi-user.target
EOF

cp -p /etc/systemd/system/redis-1-project.service /etc/systemd/system/redis-2-project.service
cp -p /etc/systemd/system/redis-1-project.service /etc/systemd/system/redis-3-project.service
cp -p /etc/systemd/system/redis-1-project.service /etc/systemd/system/redis-4-project.service
cp -p /etc/systemd/system/redis-1-project.service /etc/systemd/system/redis-5-project.service

sed -i 's|redis-1.conf|redis-2.conf|g' /etc/systemd/system/redis-2-project.service
sed -i 's|redis-1.conf|redis-3.conf|g' /etc/systemd/system/redis-3-project.service
sed -i 's|redis-1.conf|redis-4.conf|g' /etc/systemd/system/redis-4-project.service
sed -i 's|redis-1.conf|redis-5.conf|g' /etc/systemd/system/redis-5-project.service

systemctl daemon-reload

########################################################################################################################################
########################################################################################################################################
sudo usermod -a -G aaa build
# 如果build要修改/opt/project下的东西，要把权限改回build
chown -R project: /opt/project