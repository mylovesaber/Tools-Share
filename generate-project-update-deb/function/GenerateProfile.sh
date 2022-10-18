#!/bin/bash
cat > ../generate-deb.conf << EOF
# 为防读取配置文件错误，预留的英文双引号别删，等号后面任意位置，除非是写在双引号里面的内容，否则别留空格
# 如果填写的配置信息内还有双引号，则添加反斜杠，例：
# 要添加的内容：JAVA_OPTS="-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m"
# 写进配置文件后：catalina-option="JAVA_OPTS=\"-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m\""

[General]
# 部署的根目录，此工具会将所有要安装的软件均安装到同一个目录下，
# 比如将 tomcat/mysql/redis 等安装在 /opt/project 目录下，则 /opt/project 为部署的根目录
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

# 安装此包得确保已安装的依赖的包名，可以留空，如果有多个依赖包名，则需要指定版本号和包名为一组，每组通过空格和英文逗号隔开
# 例: foo(>= 1.0.0), foo1(>= 2.0.0), ... foon(>= xxx)
# 对于更新包而言，暂时只需要依赖基础包(内含 java/tomcat/redis/mysql)即可，工具会自动生成对应的格式并在打包时应用
package-depends-base-name=""
package-depends-base-version=""

# 对安装包的更多的介绍信息
package-more-description=""

# 安装包的版本号，此版本号与下面源代码包名组合成为打包目录的名称，系统中可以查到此版本号
# 因为更新包版本号会不断更新，所以这里注释了用于和下面的源代码包名选项用于释义，把选项放在了下面频繁更新的分类中
# package-version=""

# 源代码包名，此名称将与安装包的版本号拼接后作为总打包目录名，实际安装包安装时系统中看到的包名不是这个
package-source=""


[Tomcat]
# 跳过下载配置 Tomcat 的开关选项，1 是跳过，0 是不跳过
tomcat-skip=0

# 需要下载的 Tomcat 的版本号，例: 9.0.12
tomcat-version=""

# 需要添加的 jar 包排除项，多个 jar 包请用英文逗号隔开(,)，中间不要有空格，单个则无需添加逗号，例: aaa.jar,bbb.jar,ccc.jar
exclude-jar=""

# 其他 catalina 调试选项
catalina-option="JAVA_OPTS=\"-Xms1024m -Xmx1024m -Xss2048K -XX:PermSize=512m -XX:MaxPermSize=1024m\""

[Mysql]
# 是否跳过配置 Mysql 的开关选项，1 是跳过，0 是不跳过，如果更新包不需要更新数据库内容的话就可以跳过，生成的包不会对数据库做任何更新
mysql-skip=0

# 本地连接 mysql 有权限操作数据库的账户比如 root 账户
mysql-username=""
mysql-password=""

# mysql 的绝对路径(即整个程序的总目录，此路径下有 bin/include/lib 等其他子文件夹)
# 不填写则默认已设置过 mysql 的环境变量，进行数据库操作时将直接以 mysql 为命令进行连接操作
mysql-bin-path=""

# sql 文件的名称
sql-file-name=""


[Frequently Changing Options]
# [General] 日期格式只接受纯数字，例: 20221231，此时间将拼接在tomcat和mysql数据库名称中
common-date=""

# [General] 是否清空打包环境，0 不清空，1 清空所有，2 保留下载的 Tomcat 压缩包和解压包
need-clean=0

# [Mysql] 准备创建的新数据库名称，mysql中查看数据库名称将看到的名字格式：[数据库名][日期]
database-new-name=""

# [Mysql] 准备备份的数据库名称(这个用于更新包的选项，一体包不考虑)
database-old-name=""

# [Package] 对安装包的简介，命令 dpkg -l 可以看到这个提示信息
package-description=""

# [Package] 安装包的版本号，系统中可以查到此版本号
package-version=""

# [Tomcat] 需要新建的 Tomcat 的端口号，例: 8088
tomcat-new-port=

# [Tomcat] 上一个版本的 Tomcat 的端口号，例: 8087
# 这两个端口号目的是同时保证环境内有两个正常启动的项目，然后不属于这两个项目的其他版本 Tomcat 在更新时会被停止工作
tomcat-previous-port=

EOF