#!/bin/bash
cat > ../generate-deb.conf << EOF
[Package]
# 一般填写维护者和对应邮箱，例: 腾讯有限公司 <xxx@qq.com>
package-maintainer=

# 填写作者网址，例: https://www.baidu.com
package-homepage=

# 安装包名，会显示在系统的程序列表中的名字
package-name=

# 适应的架构，例: all 或者 mips64el 等等
package-architecture=

# 安装此包得确保已安装的依赖的包名，可以留空
package-depends=

# 对安装包的简介，命令 dpkg -l 可以看到这个提示信息
package-description=

# 对安装包的更多的介绍信息
package-more-description=

[Redis]
# redis 端口号
redis-port=
EOF