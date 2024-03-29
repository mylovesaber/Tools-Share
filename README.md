# Tools-Share

存放各种自动化脚本或工具

# 注意事项

1. 在部分涉密服务器上工作的话，传统 bash 或 source 功能无法使用，可以使用进程替换的方式来绕过系统限制，例: `bash <(cat /root/xxx.sh)`，本仓库所有自动化工具的内置帮助菜单中均默认使用此方式显示。
2. auto-generate-key 工具使用了 SSH 的高级功能，所以请确保 SSH 版本高于 7.3，即 2017 年以后安装的系统均支持，查看版本命令: `ssh -V`
3. 带 + 的脚本文件名称别改，要改的话必须把脚本文件中的代码开头部分的文件名常量给修改成相同的名称，否则工作会报错。在涉密服务器上 `basename` 命令无法用于脚本，因为使用的是进程替换方式绕过禁止脚本工作的限制，所以该命令得到的不是脚本本身名称。
4. 本仓库内有一些工具是为使用无外网连接甚至纯粹无网络服务器的数据维护而写，如果有网络的话会有一些更好的开源替代工具。

# 可用列表

文件夹名即为工具名。

带 * 为工作依赖于免密环境部署工具，需要先行部署免密环境部署工具。

带 + 为可以工作在涉密服务器上的工具，一般为单个文件。

没有特殊标记的均为一定程度上通用的工具，具体请看每个工具内部介绍。

| 工具名称                                                                                                    |用途|
|---------------------------------------------------------------------------------------------------------|---|
| [auto-generate-key](auto-generate-key) +             |免密环境部署工具，该工具是此仓库中多个自动化工具正常工作的必备前提条件|
| [multi-sync-backup](multi-sync-backup) *+            |任意多节点之间同步和备份工具(基于scp)|
| [auto-update-github-hosts](auto-update-github-hosts) |自动更新大陆可以访问 github 的 hosts 节点信息工具|

---

# 其他

**other** 和 **todo_or_idea** 文件夹中存放的是各种非成品功能或模块，很多文件代码和文档是残缺的，没有任何参考价值，仅供作者测试或备份用，未来可能会实装，也有可能被抛弃

如果仓库中存在不是以上两个名称的文件夹或者可用列表中的文件夹，大概率是还没写完就误 push 的，也没有使用或参考价值。