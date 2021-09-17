# Github hosts 自动部署和更新工具

自动更新 linux 服务器中的 hosts 文件（路径：/etc/hosts）以实现正常下载上传 github 项目的需求。
制作此工具的目的是：一次无脑的一键安装后，永久不用在意更新事宜，全部自动搞定。
工具中使用的 hosts 更新源来自此项目：https://github.com/521xueweihan/GitHub520
在此表示感谢。

本工具源码未涉及系统中包管理器的操作，故理论上各种 linux 发行版应该是通用的（路由器等特殊定制导致dns解析文件不是以上路径或系统命令被改名的就无法使用）。

# 工具说明与功能介绍

本项目在码云和 Github 都有同步。
Github： https://github.com/mylovesaber/auto_update_github_hosts
Gitee：  https://gitee.com/mylovesaber/auto_update_github_hosts

项目内含两个脚本，分别为安装脚本和日用脚本。安装后系统会自动进行以下操作。

- 每30分钟自动更新一次hosts（实际效果取决于更新源的更新）
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

```bash
# 码云托管的安装脚本 + 指定码云为日用脚本安装源
bash <(wget --no-check-certificate -qO- https://gitee.com/mylovesaber/auto_update_github_hosts/raw/main/setup.sh) -s gitee

# github 托管的安装脚本 + 指定码云为日用脚本安装源
bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/mylovesaber/auto_update_github_hosts/main/setup.sh) -s gitee

```

## 日用脚本

日用脚本包含以下功能：

- 更新工具本身
- 更新hosts
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

# 即时更新此工具本身
hosts-tool updatefrom gitee

# 完全卸载工具（恢复第一次安装工具时备份的 hosts 文件，会丢弃日后新增的其他各种dns解析规则）
hosts-tool recover first_backup

# 完全卸载工具（恢复最后一次备份的hosts文件，推荐运行此卸载命令前先执行 hosts-tool run）
hosts-tool recover uptodate_backup

```

## 其他

如果 git push 到 github 没有反应，可以尝试下 Ctrl+C 强制中断后再执行该命令。
如果执行几次还没反应，可等自动提示 push 失败后执行命令：hosts-tool run ，之后再尝试 push
再不行的话。。。。晚些时候再尝试吧。。。。