# 必要文件

|文件名|简介|
|---|---|
|program-frame.tar.xz|脚本工作的基本框架，解压出来是program文件夹，可配合deploy.conf选项参数理解用法|
|program.tar.xz|脚本在mips机器上可以直接使用的版本，使用前需要解压出program文件夹|
|deploy.conf|决定deploy.sh工作细节的配置文件|
|deploy.sh|一键脚本|
|setup.sh|用于制作加密一键部署的一体包|

# 自解压加密包的制作方法

setup.sh使用方法（只能用于最终交付时一次性使用，测试时别用，打包解包速度太慢）：
```bash
# 1.1 不可更改一体包
tar -cJf program.tar.xz deploy.sh deploy.conf program/

# 1.2 配置文件没有被集成的一体包，方便改参数完成不同操作需求调试（调试散装比较合适）
tar -cJf program.tar.xz deploy.sh program/

# 以上制作压缩包的操作二选一，以下是制作自解压加密一体包
cat program.tar.xz >> setup.sh
```
制作自解压一体包默认使用 xz 压缩（网上暂时只有tar.gz的用法），这是linux下压缩能力最强几乎没有之一的工具，比 7z 压缩还强很多，windows 下可以使用去广告版的好压，这是 win 下少有的支持 xz 压缩的压缩软件，而且压缩能力远比比较热门的 bandizip 之流强，但高压时对硬件性能需求高。

# 用法

1. 解压 program.tar.xz 压缩包，确保同一个目录内同时有deploy.sh/deploy.conf/program文件夹
2. 授予 deploy.sh 执行权限: chmod +x deploy.sh
3. 执行脚本: ./deploy.sh （所有参数在 deploy.conf 中均有定义，所以脚本本身直接运行不用添加任何参数，方便配置人在多机器上同配置参数无脑部署）

# 已有功能

1. 一键免安装部署： tomcat/redis/java/mariadb/项目（前后端包和桌面生成奇安信浏览器指定打开项目地址的快捷方式）
2. 对账户权限没有需求
3. 设计预期是自动检测cpu架构并选择对应平台可用的组件包进行安装
4. 所有组件有开机自启功能（系统限制只有登录账户的时候才可以触发自启功能，未来root账户部署的就可以不登录账号就能开机自启）

# 存在的问题

待完善（时间不够导致）：
1. 脚本缺少对配置文件中选项和参数合法性的判断、自修正和拦截
2. 脚本只做了每个环境组件的独立安装功能以及全局卸载功能，每个组件的独立升级、卸载、重置功能没写
3. root账户配置和有root提权能力的账户配置没写
4. mysql部署模块有选项和参数没写，打包中有mips64el的mysql软件本体

待完善（没测试条件）：
1. 特殊权限机器上的兼容性适配