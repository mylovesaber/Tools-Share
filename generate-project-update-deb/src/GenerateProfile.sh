#!/bin/bash
cat > ../generate-deb.conf << EOF
# 为防读取配置文件错误，预留的英文双引号别删，等号后面任意位置，除非是写在双引号里面的内容，否则别留空格

[General]
# 日期格式只接受纯数字，例: 20221231，此时间将拼接在tomcat和mysql数据库名称中
common-date=""

# 部署的根目录，此工具会将所有要安装的软件均安装到同一个目录下，
# 比如将 tomcat/mysql/redis 等安装在 /opt/project 目录下，则此目录为部署的根目录
package-deploy-path=""


[Package]
# 跳过打包的开关选项，1 是跳过，0 是不跳过
package-skip=0

# 一般填写维护者和对应邮箱，例: 腾讯有限公司 <xxx@qq.com>
package-maintainer=""

# 填写打包者的网址，例: https://www.baidu.com
package-homepage=""

# 安装包名，会显示在系统的程序列表中的名字
package-name=""

# 适应的架构，例: all 或者 mips64el 等等
package-architecture=""

# 安装此包得确保已安装的依赖的包名，可以留空
package-depends=""

# 对安装包的简介，命令 dpkg -l 可以看到这个提示信息
package-description=""

# 对安装包的更多的介绍信息
package-more-description=""


[Java]
# 跳过配置 Java 的开关选项，1 是跳过，0 是不跳过
java-skip=0

# 配置的 java 版本，mips64 架构暂时只有 1.8.0_332 版本，取自龙芯开源社区，x86_64 暂未适配
java-version=1.8.0_332


[Tomcat]
# 跳过下载配置 Tomcat 的开关选项，1 是跳过，0 是不跳过
tomcat-skip=0

# 需要设置的 tomcat 的端口号，例: 8087
tomcat-port=

# 需要下载的 tomcat 的版本号，例: 9.0.12
tomcat-version=""

# 需要添加的 jar 包排除项，多个 jar 包请用英文逗号隔开(,)，中间不要有空格，单个则无需添加逗号，例: aaa.jar,bbb.jar,ccc.jar
exclude-jar=""


[Redis]
# 由于 Redis 软件生成的文件数量过少，所以将可执行文件、配置文件、进程文件、数据库均放在一个目录内
# 是否跳过 Redis 依赖包生成的开关选项，1 是跳过，0 是不跳过
redis-deps-skip=0

# 是否跳过编译 Redis 的开关选项，1 是跳过，0 是不跳过
redis-compile-skip=0

# 是否跳过配置包中的 Redis 的开关选项，1 是跳过，0 是不跳过
redis-skip=0

# 需要下载编译的 Redis 版本(mips64 架构 CPU 的银河麒麟 V10 系统中 7.0.5 编译运行测试通过)
# Redis 默认下载的是最新版即 stable 版本，暂时只有编译运行后才知道版本号，所以默认编译的是最新版
# 也可以指定版本号，系统会联网查询是否存在此版本
mysql-version=""


[Mysql]
# 是否跳过 Mysql 依赖包生成的开关选项，1 是跳过，0 是不跳过
mysql-deps-skip=0

# 是否跳过编译 Mysql 的开关选项，1 是跳过，0 是不跳过
mysql-compile-skip=0

# 是否跳过配置 Mysql 的开关选项，1 是跳过，0 是不跳过
mysql-skip=0

# 需要下载编译的 Mysql 版本(mips64 架构 CPU 的银河麒麟 V10 系统中 5 系列最后一个版本 5.7.38 编译运行测试通过)
mysql-version=""

# 准备创建的新数据库名称，mysql中查看数据库名称将看到的名字格式：[数据库名][日期]
database-new-name=""

# 准备备份的数据库名称(这个用于更新包的选项，一体包暂时不考虑)
# database-old-name=""

# 连接 mysql 有权限操作数据库的账户比如 root 账户
mysql-username=""
mysql-password=""

# mysql 的绝对路径，不填写则默认已设置过 mysql 的环境变量，进行数据库操作时将直接以 mysql 为命令进行连接操作
mysql-bin-path=""

# sql 文件的名称
sql-file-name=""
EOF