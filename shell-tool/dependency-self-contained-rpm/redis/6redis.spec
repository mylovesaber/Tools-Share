#
# Fedora spec file
#


# 临时解决方案： https://bugzilla.redhat.com/2059488
%undefine _package_note_file
%global __check_files %{nil}
%global __os_install_post %{nil}
%global __arch_install_post %{nil}
%global _build_id_links none
%global debug_package %{nil}

# 切换 redis 构建版本靠 redis_version_code，redis_ver用于控制最终出包时的版本号
%global redis_ver 6.2.13
%global redis_version_code redis-6
%global redis_version_num 6

# 全局变量
%global vendor_en test
%global vendor_cn 测试
%global top_path /opt
%global top_redis_path %{top_path}/%{vendor_en}/redis-%{redis_version_num}
%global vendor_link http://a.b.c

Name:              redis-%{redis_version_num}-%{vendor_en}
Version:           %{redis_ver}
Release:           1%{?dist}
Summary:           Redis %{vendor_cn}定制版
License:           GPLv3
URL:               %{vendor_link}
AutoReqProv:       no

Requires:          logrotate
Requires(pre):     shadow-utils

%description
Redis 定制版，该版本与除内核外的一切 Linux 系统底层依赖解耦
向前兼容任何支持 rpm 安装包且内核版本大于等于 3.2 的 linux 发行版
同时不会对系统中已有的镜像源版本 redis 产生除运行端口号、配置文件中指定的各种路径以外的任何冲突

%prep
if ! source %{_specdir}/redis-rpmbuild.sh   \
--source-path "%{_sourcedir}"               \
--build-path "%{_builddir}"                 \
-- prep "%{redis_version_code}"; then
    echo "准备流程出现问题，退出中"
    exit 11
fi

%build
# 绕过 rpmbuild 运行时创建临时环境变量，这些环境变量会导致构建出来的redis体积是手动构建出来的体积的两倍以上，且存在不应产生的运行依赖，
# 比如生成的 libsystemd 动态库存在运行时依赖：libgcc_s.so，这依赖是 gcc 的，只会在构建时对其有依赖，不可能也不应该存在于运行依赖中
# rpmbuild 每次执行一个 body 都会重新 export 这些变量，至少得在源码构建流程中把这些取消掉
unset                   \
FFLAGS                  \
FCLAGS                  \
CFLAGS                  \
CXXFLAGS                \
LDFLAGS                 \
VALAFLAGS               \
LT_SYS_LIBRARY_PATH

if ! source %{_specdir}/redis-rpmbuild.sh   \
--top-path "%{top_path}"                    \
--top-redis-path "%{top_redis_path}"        \
--build-path "%{_builddir}"                 \
-- build "%{redis_version_code}"; then
    echo "构建流程出现问题，退出中"
    exit 11
fi

%install
if ! source %{_specdir}/redis-rpmbuild.sh   \
--top-path "%{top_path}"                    \
--top-redis-path "%{top_redis_path}"        \
--vendor-en "%{vendor_en}"                  \
--vendor-cn "%{vendor_cn}"                  \
--buildroot-path "%{buildroot}"             \
--sys-conf-path "%{_sysconfdir}"            \
--unit-path "%{_unitdir}"                   \
-- install "%{redis_version_code}"; then
    echo "构建流程出现问题，退出中"
    exit 11
fi

%pre
getent group %{vendor_en} &> /dev/null || \
groupadd -r %{vendor_en} &> /dev/null
getent passwd redis-%{vendor_en} &> /dev/null || \
useradd -r -g %{vendor_en} -d %{top_path}/%{vendor_en} -s /sbin/nologin \
-c 'Redis Database Server %{vendor_cn}定制版' redis-%{vendor_en} &> /dev/null
if ! grep "vm.overcommit_memory" /etc/sysctl.conf >/dev/null 2>&1; then
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi
exit 0

%preun
%systemd_preun %{name}-1.service
%systemd_preun %{name}-2.service
%systemd_preun %{name}-3.service
%systemd_preun %{name}-4.service
%systemd_preun %{name}-5.service
%systemd_preun redis-sentinel-%{redis_version_num}-%{vendor_en}-1.service
%systemd_preun redis-sentinel-%{redis_version_num}-%{vendor_en}-2.service
%systemd_preun redis-sentinel-%{redis_version_num}-%{vendor_en}-3.service
%systemd_preun redis-sentinel-%{redis_version_num}-%{vendor_en}-4.service
%systemd_preun redis-sentinel-%{redis_version_num}-%{vendor_en}-5.service

%postun
%systemd_postun_with_restart %{name}-1.service
%systemd_postun_with_restart %{name}-2.service
%systemd_postun_with_restart %{name}-3.service
%systemd_postun_with_restart %{name}-4.service
%systemd_postun_with_restart %{name}-5.service
%systemd_postun_with_restart redis-sentinel-%{redis_version_num}-%{vendor_en}-1.service
%systemd_postun_with_restart redis-sentinel-%{redis_version_num}-%{vendor_en}-2.service
%systemd_postun_with_restart redis-sentinel-%{redis_version_num}-%{vendor_en}-3.service
%systemd_postun_with_restart redis-sentinel-%{redis_version_num}-%{vendor_en}-4.service
%systemd_postun_with_restart redis-sentinel-%{redis_version_num}-%{vendor_en}-5.service


%files
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}-1
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}-2
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}-3
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}-4
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}-5
%defattr(-,redis-%{vendor_en},root,-)
%{top_redis_path}
# 会报File listed twice警告，忽略即可，以下的重复是想要的，需要单独设置这些文件的属性
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/redis-1.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/redis-2.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/redis-3.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/redis-4.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/redis-5.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/sentinel-1.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/sentinel-2.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/sentinel-3.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/sentinel-4.conf
%attr(0640, redis-%{vendor_en}, root) %config(noreplace) %{top_redis_path}/conf/sentinel-5.conf
%{_unitdir}/%{name}-1.service
%{_unitdir}/%{name}-2.service
%{_unitdir}/%{name}-3.service
%{_unitdir}/%{name}-4.service
%{_unitdir}/%{name}-5.service
%{_unitdir}/redis-sentinel-%{redis_version_num}-%{vendor_en}-1.service
%{_unitdir}/redis-sentinel-%{redis_version_num}-%{vendor_en}-2.service
%{_unitdir}/redis-sentinel-%{redis_version_num}-%{vendor_en}-3.service
%{_unitdir}/redis-sentinel-%{redis_version_num}-%{vendor_en}-4.service
%{_unitdir}/redis-sentinel-%{redis_version_num}-%{vendor_en}-5.service
%dir %{_sysconfdir}/systemd/system/%{name}-1.service.d
%dir %{_sysconfdir}/systemd/system/%{name}-2.service.d
%dir %{_sysconfdir}/systemd/system/%{name}-3.service.d
%dir %{_sysconfdir}/systemd/system/%{name}-4.service.d
%dir %{_sysconfdir}/systemd/system/%{name}-5.service.d
%config(noreplace) %{_sysconfdir}/systemd/system/%{name}-1.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/%{name}-2.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/%{name}-3.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/%{name}-4.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/%{name}-5.service.d/limit.conf
%dir %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-1.service.d
%dir %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-2.service.d
%dir %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-3.service.d
%dir %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-4.service.d
%dir %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-5.service.d
%config(noreplace) %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-1.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-2.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-3.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-4.service.d/limit.conf
%config(noreplace) %{_sysconfdir}/systemd/system/redis-sentinel-%{redis_version_num}-%{vendor_en}-5.service.d/limit.conf

# 日期转换方式：date +"%a %b %d %Y" -d "2023-10-14"
%changelog
* Tue Oct 17 2023 - 首版定版测试 01
- 支持为 x86_64 CPU 架构制作 redis 6.2.13 独立版安装包
- 支持为 aarch64 CPU 架构制作 redis 6.2.13 独立版安装包
- 支持为 x86_64 CPU 架构制作 redis 7.2.1 独立版安装包
- 支持为 aarch64 CPU 架构制作 redis 7.2.1 独立版安装包

* Tue Oct 17 2023 - 首版内部测试 08
- 增加 redis 6.2.13 即 6 系列 x86_64 和 aarch64 架构构建兼容

* Mon Oct 16 2023 - 首版内部测试 07
- 增加 x86_64 架构 CPU 的 redis 7 系列支持

* Sun Oct 15 2023 - 首版内部测试 06
- 基于以前所有修改，重构 spec 打包规则为外挂传参实现构建和准备打包环境以实现对 redis 6 系版本做好结构兼容

* Sat Oct 14 2023 - 首版内部测试 05
- 为所有构建模块增加开关以便调试(spec 不支持 function 的另类解决办法)
- 修复若干 bug
- 基于以上和以前所有修改，重构 spec 打包规则为外挂传参实现构建和准备打包环境

* Fri Oct 13 2023 - 首版内部测试 04
- 增加多版本 redis 切换开关并调整宏调用结构，以便快速切换不同版本 redis 构建

* Thu Oct 12 2023 - 首版内部测试 03
- 增加下载的源码包校验流程，因为指定各组件版本，故事先计算好 sha256 值

* Tue Oct 10 2023 - 首版内部测试 02
- 增加检测源码包不存在就在线下载逻辑

* Sat Oct 07 2023 - 首版内部测试 01
- 完成 aarch64 redis 7.2.1 单版本打包 spec