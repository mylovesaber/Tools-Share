# GitHub hosts 自动部署和更新工具

自动更新 linux 服务器中的 hosts 文件（路径：/etc/hosts）以实现正常下载上传 github 项目的需求。
制作此工具的目的是：一次无脑的一键安装后，永久不用在意更新事宜，全部自动搞定。
(暂时发现有更新着就把自己给更新没了的问题...已修改并在未来测试下是否依旧复现)
本项目不定时更新，万一因为 bug 导致 hosts-tool 无法正常工作的话，请重新跑一下本项目的安装脚本...不用单独卸载，安装脚本自带覆盖和处理冲突的功能
工具中使用的 hosts 更新源来自此项目：https://github.com/521xueweihan/GitHub520
在此表示感谢。


本工具已具备 DNS 刷新功能，所以取消通用性，暂时指定支持以下系统：

- Debian 9+
- Ubuntu 18.04+
- CentOS 7+
- RHEL 7+
- Synology(群晖)
- MacOS (Menterey 测试通过，理论上文件系统是 APFS 的新一代系统应该都支持)

注意：MacOS 每次系统版本更新后都得重新跑一遍安装脚本或者命令 `hosts-tool update` 或 `hosts-tool updatefrom [gitlab/github]` ，否则定时功能会被苹果清空

其他系统或版本有需要适配的请发 issue 并提供所用系统版本和对应可用的 DNS 刷新功能的方法，如果有需要安装软件包的话请提供下包名

~unRAID 系统定时功能做了定制，所以单独适配了，手动控制方式上没有区别，工具会自动识别。~

unRAID 系统适配好像没完全生效。。。等以后用这系统再单独测试吧。。。

# 工具说明、功能介绍、安装步骤

本项目在 GitLab 和 GitHub 都有同步。
2022年5月18日，码云（Gitee）启动了代码审查机制，但凡不合规矩或者存在个别字眼比较敏感的都可能被删除或阻止其他用户访问，
且默认阻断匿名访问，鉴于本工具骨骼清奇，码云平台已彻底屏蔽此项目，所以该平台我已彻底放弃。
经过测试，中国大陆大部分地区没有特殊手段无法打开 GitHub 网站，但基本都能打开 GitLab，于是我设置成中国大陆用户默认从 GitLab 获取工具源码。
不要有非 GitHub 不用的思想，我代码都是首先 push 到 GitLab，然后再由 GitLab 自动同步到 GitHub 上。

GitHub： https://github.com/mylovesaber/Tools-Share/tree/main/auto-update-github-hosts

GitLab：  https://gitlab.com/mylovesaber/tools-share/-/tree/main/auto-update-github-hosts

项目内含两个脚本，分别为安装脚本和日用脚本。

**首次请运行安装脚本，如果未来日用脚本失效了，请重新运行安装脚本即可**

**如果不想用此工具但因日用脚本失效导致系统中存在残留，请先运行安装脚本，然后运行日用脚本完成清理操作**

两个脚本均存在当检测到 GitHub 源无法正常连通时就自动切换到 GitLab 源进行更新的逻辑判断，并且一旦 GitHub 源更新失败的时候，自动更新工具在切换到 GitLab 源并更新本身之后，将把未来自动更新工具的源头替换为 GitLab 源，如果有人执意要用 GitHub 更新的话，请手动运行一次日用脚本中的更新工具本身并指定 GitHub 为更新源(说真的，没必要，因为两个源是同步的，使用哪个都一样...)

安装后系统会自动进行以下操作。

- 每1小时自动更新一次 hosts 并刷新 dns（实际效果取决于更新源的更新）
- 每3天自动更新一次工具本身
- 每10天自动清理一次工具产生的旧日志
- 自动备份用户未来在 /etc/hosts 中新增的新内容

## 安装脚本

安装脚本为一次性脚本，必须指定选项参数运行否则会报错。脚本内置帮助信息和选项参数如下：

```bash
GitHub hosts 自动部署和更新工具

命令格式: 
setup.sh  选项  参数

选项:

-s 或 --source        指定下载源，可选参数为 gitlab 或 github，若不使用该选项则默认从 GitLab 下载
-h 或 --help          显示帮助信息并退出
```

大陆节点或家宽 nas 直接指定 GitLab 为工具安装源和即可。
本脚本依赖 bash shell，如果系统不存在 bash 的话暂时未适配请勿使用。(输入命令： `which bash` 能看到具体 bash 路径就能用)

安装命令：

```bash
# GitLab 托管的安装脚本 + 指定 GitLab 为日用脚本安装源
bash <(curl -Ls https://gitlab.com/api/v4/projects/37571126/repository/files/auto%2Dupdate%2Dgithub%2Dhosts%2Fsetup%2Esh/raw?ref=main) -s gitlab

# GitHub 托管的安装脚本 + 指定 GitLab 为日用脚本安装源
bash <(curl -Ls https://raw.githubusercontent.com/mylovesaber/Tools-Share/main/auto-update-github-hosts/setup.sh) -s gitlab
```

## 日用脚本

日用脚本包含以下功能：

- 更新工具本身
- 更新 hosts 并刷新 dns
- 完全卸载
- 移除过期日志

自带的帮助信息如下：

```bash
GitHub hosts 自动部署和更新工具

命令格式: 
hosts-tool  选项1  (选项2)

选项:
run                        立即更新hosts

update                     默认从 GitLab 升级该工具

updatefrom gitlab|github   需指定下载源才能升级该工具
                           可选选项为 gitlab 或 github
                           
remove                     该选项将将此工具和生成的各种文件从系统中移除并还原 host 文件内容

help                       显示帮助信息并退出

```

日用命令：

```bash
# 即时更新 hosts（同时会立即备份 /etc/hosts 中用户自行增加的各种dns解析规则）
hosts-tool run

# 默认从 GitLab 立即更新此工具本身
hosts-tool update

# 立即根据指定的更新源更新此工具本身（以下有两种源，择一运行即可），推荐上面那个更新命令
hosts-tool updatefrom gitlab
hosts-tool updatefrom github

# 完全卸载工具
hosts-tool remove
```