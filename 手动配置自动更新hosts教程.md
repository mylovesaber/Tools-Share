# 手动教程

我的一键脚本适用于传统 linux 服务器和苹果较新的 MacOS 系统，别的偏门系统可以按照以下介绍自行解决，想加的可以加，路由器系统的适配暂时不做，我暂时不知道为什么系统解析传入的参数会给路由器那 sh 或者 bash 拆得七零八落，一键脚本里面有完整但被屏蔽的路由器的适配代码，能解决参数乱读乱拆的请发个 issue 给个处理方法介绍，在此表示感谢！(setup.sh 中的代码已经适配完整了，hosts-tool.sh 中的代码适配存在很多毛病)

## 必要条件检查

以下条件必须全部了解才行：

- 所用系统刷新 DNS 的操作（即命令行中如何可以通过命令来实现 DNS 的刷新）
- 在刷新 DNS 后可以生效的 hosts 的文件路径
- cron 定时可以生效的具体步骤

以下以网友刷了 padavan 的小米路由器和已有网友测试可用的 openwrt 系统为例

## 1. 更新 hosts 文件
### 1.1 下载 hosts 文件
以下命令会下载新版 hosts 文件保存为 /etc目录下的 newhosts 文件：

```bash
curl https://raw.hellogithub.com/hosts > /etc/newhosts
```

### 1.2 删除原有 hosts 文件中的过时 hosts 信息

常规 Linux/Unix 下的 hosts 文件位置都是: `/etc/hosts`，对于padavan、openwrt 等路由器系统还有一个可能有效的路径: `/etc/storage/dnsmasq/hosts`，具体哪个路径有效请自测，比如 `/etc/hosts` 有效，那么先备份一下：

```bash
cp -a /etc/hosts /etc/hosts.bak
```

然后删除 `/etc/hosts` 中已有的过时 hosts 信息：

```bash
sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts
```

然后输入命令 `cat /etc/hosts` 看看删除过时信息后的 hosts 文件是否显示正常，如果正常就执行后续操作，否则恢复备份: `cp -af /etc/hosts.bak /etc/hosts`

**需要特别小心的一点是，一定要直接复制自己下载的新 hosts 中的关键词，否则很大概率会遇到如下的问题：**

以下两行命令都是输出匹配的文本对应的行号，你能看得出两个 `# Github520 Host End` 有什么区别导致有一个匹配不到对应行号吗？我是没看出来，但它们是有区别的，对于 sed 的删除功能而言，一旦第一个文本信息匹配上了就会开启删除功能，而匹配不到正确的文本信息以关闭删除功能的话，整个 hosts 文件中的规则都会被删除干净，所以务必注意

```bash
root@VM-12-16-centos ~ # awk '/# Github520 Host End/{print NR}' hosts
root@VM-12-16-centos ~ # awk '/# GitHub520 Host End/{print NR}' hosts
43
root@VM-12-16-centos ~ #
```

比如以上例子第一行的匹配行信息就是直接复制的网页上网友分享的命令，导致测试时把整个 hosts 全删干净了。。。：

```bash
0 6 * * * sed -i '/# GitHub520 Host Start/,/# Github520 Host End/d' /etc/storage/dnsmasq/hosts;wget --no-check-certificate https://raw.hellogithub.com/hosts -O /etc/storage/dnsmasq/hosts.bak;cat /etc/storage/dnsmasq/hosts.bak >> /etc/storage/dnsmasq/hosts;restart_dhcpd
```

担心这个奇葩问题的话，可以和我脚本中的操作一样，为不断更新的 hosts 规则还有已有的规则各自单独创建一个备份文件，然后进行拼接，最终覆盖掉原版 hosts 文件就行，这样可以百分百规避这个可能删错规则的毛病。

### 1.3 新增新版 hosts 规则

一键搞定：

```bash
cat /etc/newhosts >> /etc/hosts
```

## 2. 刷新 DNS 缓存

直接替换 hosts 文件的话，有时候存在 DNS 缓存导致新 hosts 规则无法及时生效，已知路由器有以下两条命令都可能实现目的：

```bash
restart_dhcpd
restart_dns
```

不同系统甚至同系统都有可能出现有一个刷新命令有效果而另一个没有效果的问题，所以请自测

## 3. 定时运行

比如每 30 分钟运行一次名为 test 的文件，格式：
```bash
echo "*/30 * * * * test" | crontab -
```

# 自动更新

两种方式选一种就行，均为 ssh 以 root 身份登录路由器终端，根据自己测试实际可用的情况改变其中的参数配置（无论哪种方法使用 sed 命令尤其注意开启和关闭删除功能所对应匹配的文本，测试 ok 了再用）。
以 padavan 举例，已知条件如下：
- /etc/hosts 文件直接修改有效
- 刷新 DNS 缓存的有效命令为: `restart_dns`

## 一键定时

```bash
echo "*/30 * * * * sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts; curl https://raw.hellogithub.com/hosts >> /etc/hosts; restart_dns" | crontab - 
```

## 定时脚本

整个复制后直接粘贴进命令行（每条命令之间空了一行，上面连续几行是一个整体必须同时运行）：

```bash
cat < EOF > /etc/autoupdatehosts
#!/bin/bash
sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts
curl https://raw.hellogithub.com/hosts >> /etc/hosts
restart_dns
EOF

chmod +x /etc/autoupdatehosts

echo "*/30 * * * * /etc/autoupdatehosts" | crontab -
```