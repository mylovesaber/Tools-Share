#!/bin/bash
echo "正在停止并清理所有残留 Tomcat 服务(形如: tomcat-版本号-端口号.service)"
mapfile -t tomcatServiceList < <(find /etc/systemd/system -maxdepth 1 -type f -name "tomcat-*-*.service"|awk -F '/' '{print $NF}')
for i in "${tomcatServiceList[@]}" ; do
	if systemctl is-active "$i" >/dev/null 2>&1; then
		systemctl stop "$i"
		sleep 2
	fi
	if systemctl is-enabled "$i" >/dev/null 2>&1; then
		systemctl disable "$i" 1>& /dev/null
	fi
	rm -rf /etc/systemd/system/"$i"
done
echo "Tomcat 残留服务停止并清理完成"
echo ""

echo "正在停止并清理所有残留 Redis 服务(形如: redis-版本号-端口号.service)"
mapfile -t redisServiceList < <(find /etc/systemd/system -maxdepth 1 -type f -name "redis-*-*.service"|awk -F '/' '{print $NF}')
for i in "${redisServiceList[@]}" ; do
	if systemctl is-active "$i" >/dev/null 2>&1; then
		systemctl stop "$i"
		sleep 2
	fi
	if systemctl is-enabled "$i" >/dev/null 2>&1; then
		systemctl disable "$i" 1>& /dev/null
	fi
	rm -rf /etc/systemd/system/"$i"
done
echo "Redis 残留服务清理完成"
echo ""

echo "正在停止并清理所有残留 Mysql 服务(形如: mysql-版本号-端口号.service)"
mapfile -t mysqlServiceList < <(find /etc/systemd/system -maxdepth 1 -type f -name "mysql-*-*.service"|awk -F '/' '{print $NF}')
for i in "${mysqlServiceList[@]}" ; do
	if systemctl is-active "$i" >/dev/null 2>&1; then
		systemctl stop "$i"
		sleep 2
	fi
	if systemctl is-enabled "$i" >/dev/null 2>&1; then
		systemctl disable "$i" 1>& /dev/null
	fi
	rm -rf /etc/systemd/system/"$i"
done
echo "Mysql 残留服务清理完成"
echo ""
systemctl daemon-reload
echo ""
