# Github hosts 自动部署和更新工具

自动更新 linux 服务器中的 hosts 文件（路径：/etc/hosts）以实现正常下载上传 github 项目的需求。
制作此工具的目的是：一次无脑的一键安装后，永久不用在意更新事宜，全部自动搞定。（如果失效了请重新跑一下本项目...）
工具中使用的 hosts 更新源来自此项目：https://github.com/521xueweihan/GitHub520
在此表示感谢。


本工具已具备 DNS 刷新功能，所以取消通用性，暂时指定支持以下系统：

- Debian 9+
- Ubuntu 18.04+
- CentOS 7+
- RHEL 7+
- Synology(群晖)
- MacOS (Menterey 测试通过，理论上文件系统是 APFS 的新一代系统应该都支持)

其他系统或版本有需要适配的请发 issue 并提供所用系统版本和对应可用的 DNS 刷新功能的方法，如果有需要安装软件包的话请提供下包名

~unRAID 系统定时功能做了定制，所以单独适配了，手动控制方式上没有区别，工具会自动识别。~

unRAID 系统适配好像没完全生效。。。等以后单独测试吧。。。

# 工具说明、功能介绍、安装步骤

本项目在码云和 Github 都有同步。

Github： https://github.com/mylovesaber/auto_update_github_hosts

Gitee：  https://gitee.com/mylovesaber/auto_update_github_hosts

项目内含两个脚本，分别为安装脚本和日用脚本。 **首次请运行安装脚本，如果未来日用脚本失效了，请重新运行安装脚本即可**

两个脚本均存在当检测到 github 源无法正常连通时就自动切换到国内码云源进行更新的逻辑判断，并且一旦 github 源更新失败的时候，自动更新工具在切换到码云源并更新本身之后，将把未来自动更新工具的源头替换为码云源，如果有人执意要用 github 更新的话，请手动运行一次日用脚本中的更新工具本身并指定 github 为更新源(说真的，没必要，因为两个源是同步的，使用哪个都一样...)

安装后系统会自动进行以下操作。

- 每30分钟自动更新一次 hosts 并刷新 dns（实际效果取决于更新源的更新）
- 每3天自动更新一次工具本身
- 每10天自动清理一次工具产生的旧日志
- 自动备份用户未来在 /etc/hosts 中新增的新内容

## 安装脚本

安装脚本为一次性脚本，必须指定选项参数运行否则会报错。脚本内置帮助信息和选项参数如下：

```bash
Github hosts 自动部署和更新工具

命令格式: 
setup.sh  选项  参数

选项:

-s 或 --source        指定下载源，可选参数为 gitee 或 github，若不使用该选项则默认从 Gitee 下载
-h 或 --help          显示帮助信息并退出
```

大陆节点或家宽 nas 直接指定码云为工具安装源和即可。
本脚本依赖 bash shell，如果系统不存在 bash 的话暂时未适配请勿使用。(输入命令： `which bash` 能看到具体 bash 路径就能用)

安装命令：

```bash
# 码云托管的安装脚本 + 指定码云为日用脚本安装源
wget --no-check-certificate -qO- https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/setup.sh | bash -s gitee

# github 托管的安装脚本 + 指定码云为日用脚本安装源
wget --no-check-certificate -qO- https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/setup.sh | bash -s gitee

```

## 日用脚本

日用脚本包含以下功能：

- 更新工具本身
- 更新 hosts 并刷新 dns
- 完全卸载

自带的帮助信息如下：

```bash
Github hosts 自动部署和更新工具

命令格式: 
hosts-tool  选项1  (选项2)

选项:

run                        立即更新hosts
updatefrom gitee|github    需指定下载源才能升级该工具
                           可选选项为 gitee 或 github，默认是码云

recover                    该选项将将此工具所有功能从系统中移除
                           可选选项为 first_backup 或 uptodate_backup

help                       显示帮助信息并退出
```

日用命令：

```bash
# 即时更新 hosts（同时会立即备份 /etc/hosts 中新增的各种dns解析规则）
hosts-tool run

# 即时更新此工具本身（以下有两种源，择一运行即可）
hosts-tool updatefrom gitee
hosts-tool updatefrom github

# 完全卸载工具（恢复第一次安装工具时备份的 hosts 文件，会丢弃日后新增的其他各种dns解析规则）
hosts-tool recover first_backup

# 完全卸载工具（恢复最后一次备份的hosts文件，推荐运行此卸载命令前先执行 hosts-tool run）
hosts-tool recover uptodate_backup

```