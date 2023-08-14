# 通用程序定时重启部署工具

此工具基于 nohup，为满足定时重启的需求但又要后台保持运行，且对 systemd 服务支持不太完善的程序设置好定时重启（比如 mysql）。

# 工作流程

1. 如果指定错了选项或没有指定任何选项，则均打印帮助菜单并退出。
2. 如果指定了清理选项，则工具会删除所有基于本工具的定时功能。
3. 端口号和执行命令选项必填，否则会报错退出
4. 如果指定了定时规则，则进入部署环节，此环境本身只是往系统中写入一条定时规则。
5. 如果没指定定时规则，则停止指定端口号对应的系统进程，然后执行程序运行命令，所以支持同时停止多个端口号对应进程，然后启动多个程序执行命令。


# 可用选项

以下为可用选项(选项可复用，没有先后顺序):

```bash
-t  |  --timer        定时规则
-p  |  --port         需要终止的程序所占用的端口号
-r  |  --run-command  需要执行的命令
-h  |  --help         打印此帮助信息并退出
-c  |  --clean        彻底卸载部署的定时重启脚本
```

注意：

- `-p | --port` 和 `-c | --command` 为有参选项，必须同时指定。 前者用于终止指定端口号对应的进程，后者用于根据指定的启动命令来启动程序。

- `-c | --command` 的参数必须用双引号括起来，且只能写命令本身，不能添加标准输入/输出或错误输出指令。

例:

```bash
# 手动希望程序在后台运行而手动输入:
nohup /opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root >/dev/null 2>&1 &

# 则 -c | --command 应填写的参数为:
/opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root

```

## 手动重启

用于测试参数填写后，脚本是否按照实际需求工作。

如果想满足以下需求：

>1. 关闭两个端口号
>2. 启动两个进程

则使用范例为：
```bash
bash <(cat /var/log/restart-cron/restart-cron.sh) \
-p 8081 \
-p 8082 \
-r "/opt/mysql/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=root" \
-r "/opt/test/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=mysql"

```

ps: 删除每行最后反斜杠 \ 和后面的回车即可写成一行，以上写成多行只是方便查看

# 部署
定时规则举例:
- 每周四凌晨一点执行重启程序所需的定时规则: `0 1 * * 4`

如果想满足以下需求：

>1. 关闭一个端口号
>2. 启动一个进程
>3. 设置定时规则: 每周四凌晨一点执行

则部署的定时范例为：
```bash
bash <(cat /var/log/restart-cron/restart-cron.sh) \
-p 8081 \
-r "/opt/test/bin/mysqld --defaults-file=/opt/mysql/config/my.cnf --user=mysql" -t "0 1 * * 4"

```


# 卸载

无需加任何参数即可完全删除所有此脚本创建的定时配置：

```bash
bash <(cat /var/log/restart-cron/restart-cron.sh) -c

```

