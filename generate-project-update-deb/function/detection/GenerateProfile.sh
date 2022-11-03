#!/bin/bash
cat > generate-deb.conf <<EOF
# 为防读取配置文件错误，预留的英文双引号别删，等号后面任意位置，除非是写在双引号里面的内容，否则别留空格
# 如果填写的配置信息内还有双引号，则添加反斜杠，例：
# 要添加的内容：JAVA_OPTS="-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m"
# 写进配置文件后：catalina-option="JAVA_OPTS=\"-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m\""

[General]
# 部署的项目所在家目录，此工具会将所有要安装的软件均安装到同一个目录下，
# 比如将 tomcat/mysql/redis 等安装在 /opt/project 目录下，则 /opt/project 为部署的项目所在家目录
package-deploy-path=""

# 为检查 mysql 绝对路径、用户名密码和新老数据库是否正确、指定正在运行的最新版项目所用 tomcat 版本是否存在，需要先把依赖底包安装上，0 是未安装，1 是已安装
dependencies-installed=1


[Package]
# 跳过打包的开关选项，1 是跳过，0 是不跳过
package-skip=1

# debian 包的分类名，可选值: "admin" "cli-mono" "comm" "database" "debug" "devel" "doc" "editors" "education" "electronics" "embedded" "fonts" "games" "gnome" "gnu-r" "gnustep" "graphics" "hamradio" "haskell" "httpd" "interpreters" "introspection" "java" "javascript" "kde" "kernel" "libdevel" "libs" "lisp" "localization" "mail" "math" "metapackages" "misc" "net" "news" "ocaml" "oldlibs" "otherosfs" "perl" "php" "python" "ruby" "rust" "science" "shells" "sound" "tasks" "tex" "text" "utils" "vcs" "video" "web" "x11" "xfce" "zope"
package-section=""

# 软件包的优先级名称，可选值: required/important/standard/optional
package-priority=""

# 一般填写维护者和对应邮箱，例: 腾讯有限公司 <xxx@qq.com>
package-maintainer=""

# 填写打包者的网址，例: https://www.baidu.com
package-homepage=""

# 安装后的系统包名，会显示在系统的程序列表中的名字(不能用中文)
package-name=""

# 适应的架构，例: all/any/mips64el，其他架构可以通过 dpkg-architecture -L 查看
package-architecture=""

# 安装此包得确保已安装的依赖的包名，可以留空，如果有多个依赖包名，则需要指定版本号和包名为一组，每组通过空格和英文逗号隔开
# 例: foo(>= 1.0.0), foo1(>= 2.0.0), ... foo_n(>= xxx)
# 对于更新包而言，暂时只需要依赖基础包(内含 java/tomcat/redis/mysql)即可，工具会自动生成对应的完整依赖格式并在打包时应用
package-depends=""

# 对安装包的介绍信息(不超过64字节)因为此选项会不断更新，所以这里注释了，仅用于和下面的对安装包的更多介绍信息选项配合理解功能性
#package-description=""
# 对安装包的更多介绍信息
#package-more-description=""

# 安装包的版本号，此版本号与下面源代码包名组合成为打包目录的名称，系统中可以查到此版本号
# 因为更新包版本号会不断更新，所以这里注释了，仅用于和下面的源代码包名选项配合理解功能性
# 把生效的同名选项放在了下面频繁更新的分类中
# package-version=""

# 源代码包名，此名称将与安装包的版本号拼接后作为总打包目录名，实际安装包安装时系统中看到的包名不是这个
# 因为 Tomcat 和 MySQL 配置的时候一定要创建工作目录，故此选项放在通用部分，此处注释
#package-source=""


[Tomcat]
# 跳过下载配置 Tomcat 的开关选项，1 是跳过，0 是不跳过
tomcat-skip=1

# 对比官网提供的 sha512 校验下载的 Tomcat 压缩包的完整性，需要联网，0 为校验，1 为不校验
tomcat-integrity-check-skip=0

# 需要添加的 jar 包排除项，多个 jar 包请用空格隔开(不限制空格数量)，单个则无需添加逗号，例: aaa.jar bbb.jar ccc.jar bcprov*.jar
exclude-jar=""

# 其他 catalina 调试选项，如果写在双引号中的选项本身存在双引号，则在这些双引号前面加上反斜杠以防止读取错误 <\">，例：
# catalina-option="JAVA_OPTS=\"-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m\""
# 多个选项都写在最外侧的双引号中，选项之间用组合符号 ˇωˇ 隔开，此符号足够非主流以避免跟正常选项中的字符存在冲突
#  ˇωˇ 符号建议直接复制，它和前后选项之间有无空格无所谓，此工具会对选项进行整形以删掉空格
# catalina 调试选项如果有同名的，必须合并，工具本身没有合并功能，比如上面的 JAVA_OPTS 有多个参数，必须全部合并到 JAVA_OPTS 选项中
catalina-option=""

# 需要依赖的 java 环境名称，例: java 路径为: /opt/java-1.8.0/bin/java，那么此处填写的名称为: java-1.8.0
# 此名称和 package-deploy-path 选项的结果强制绑定，即上面的结果基于 package-deploy-path="/opt/java-1.8.0"
java-home-name=""

# 图标名称，一定是 svg 图标，不能是png，没有对多分辨率做适配，例: xxx.svg
project-icon-name=""

# 项目名称(可以中文，会写入桌面快捷方式的文件中)
project-name=""


[Mysql]
# 是否跳过配置 Mysql 的开关选项，1 是跳过，0 是不跳过，如果更新包不需要更新数据库内容的话就可以跳过，生成的包不会对数据库做任何更新
mysql-skip=1

# 本地连接 mysql 有权限操作数据库的账户比如 root 账户
mysql-username=""
mysql-password=""

# mysql 整个程序总目录的绝对路径(此路径下有 bin/include/lib 等其他子文件夹)
# 不填写则默认已设置过 mysql 的环境变量，进行数据库操作时将直接以 mysql 为命令进行连接操作
mysql-bin-path=""

# 要导入的 sql 文件名，例：xxx.sql，那么输入 xxx 或 xxx.sql 都行，不写后缀名工具会自动补全为 xxx.sql
sql-file-name=""


[Frequently Changing Options]
# [General] 日期格式只接受纯数字，例: 20221231，此时间将拼接在tomcat和mysql数据库名称中
common-date=""

# [General] 在打包前是否清空打包环境:
# 0 不清空
# 1 清空所有(整个构建总目录内的所有项目打包目录以及各种版本的 Tomcat 压缩包均被删除)
# 2 保留构建总目录内下载的 Tomcat 压缩包和其他项目打包总目录，只删除配置文件中指定的打包总目录
need-clean=2

# [Mysql] 准备创建的新数据库的基本名称，mysql中查看数据库名称将看到的名字格式：[新数据库基本名称][日期]
database-base-name=""

# [Mysql] 联合 Tomcat 更新时准备备份的数据库名称或跳过 Tomcat，更新只需要被修改的数据库名称(这个用于更新包的选项，一体包不考虑)
database-old-name=""

# [Package] 对安装包的简介，命令 dpkg -l 可以看到这个提示信息
package-description=""
# [Package] 对安装包的更多介绍信息
package-more-description=""

# [Package] 安装包的版本号，系统中可以查到此版本号
package-version=""
# 源代码包名，此名称将与安装包的版本号拼接后作为总打包目录名，实际安装包安装时系统中看到的包名不是这个
package-source=""

# [Tomcat] 需要新建的 Tomcat 端口号，例: 8088
tomcat-new-port=

# [Tomcat] 上一版本的 Tomcat 端口号，例: 8087
# 这两个端口号目的是同时保证环境内有两个正常启动的项目，然后不属于这两个项目的其他版本 Tomcat 在更新时会被停止工作
tomcat-previous-port=

# [Tomcat] 需要指定的前端或后端，如果两个选项都没有指定的话，
# 默认将直接将 source 文件夹中的所有文件夹复制进新建的tomcat，如果有一个被指定而另一个为空
# 则 tomcat 将从指定的上一版本包创建的 tomcat 中把指定为空的包复制过来，都没指定或都指定的效果一样
tomcat-frontend-name=""
tomcat-backend-name=""

# [Tomcat] 需要配置或下载的 Tomcat 的版本号，例: 9.0.12，如果本地存在压缩包则进入校验压缩包完整性的流程
# 如果不跳过则需要联网
tomcat-version=""

# [Tomcat] 已在目标系统中运行的最新版本项目所用的 Tomcat 版本号
tomcat-latest-running-version=""
EOF