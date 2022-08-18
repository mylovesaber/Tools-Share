# Anshare

存放各种自动化脚本或工具

# 注意事项

1. 在部分涉密服务器上工作的话，传统 bash 或 source 功能无法使用，可以使用进程替换的方式来绕过系统限制，例: `bash <(cat /root/xxx.sh)`，本仓库所有自动化工具的内置帮助菜单中均默认使用此方式显示。
2. auto-generate-key 工具使用了 SSH 的高级功能，所以请确保 SSH 版本高于 7.3，即2017年以后安装的系统均支持，查看版本命令: `ssh -V`
3. 脚本文件名称别改，要改的话必须把脚本文件中的代码开头部分的文件名常量给修改成相同的名称，否则工作会报错。在涉密服务器上 `basename` 命令无法用于脚本，因为试用的是进程替换方式绕过禁止脚本工作的限制，所以该命令会得到的是内存文件名而不是脚本本身名称。

# 可用列表

文件夹名即为工具名

|工具名称|用途|
|---|---|
|[auto-generate-key](https://gitlab.com/mylovesaber/anshare/-/tree/main/auto-generate-key)|免密环境部署工具，该工具是此仓库中多个自动化工具正常工作的必备前提条件|
|[multi-sync-backup](https://gitlab.com/mylovesaber/anshare/-/tree/main/multi-sync-backup)|任意多节点之间同步和备份工具(基于scp)|

---

~~**other** 和 **todo_or_idea** 文件夹中存放的是各种非成品功能或模块，很多文件代码和文档是残缺的，没有任何参考价值，仅供作者测试或备份用，未来可能会实装，也有可能被抛弃~~

