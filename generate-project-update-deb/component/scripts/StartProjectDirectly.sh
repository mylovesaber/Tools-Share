#!/bin/bash
# 变量
tomcatNewPort="TOMCAT_NEW_PORT"
tomcatVersion="TOMCAT_VERSION"
tomcatNewName="tomcat-$tomcatVersion-$tomcatNewPort"
tomcatLatestRunningVersion="TOMCAT_LATEST_RUNNING_VERSION"
tomcatPreviousPort="TOMCAT_PREVIOUS_PORT"
tomcatRunningName="tomcat-$tomcatLatestRunningVersion-$tomcatPreviousPort"
packageDeployPath="PACKAGE_DEPLOY_PATH"
javaHomeName="JAVA_HOME_NAME"
packageSource="PACKAGE_SOURCE"


cp -a /tmp/$packageSource/$tomcatNewName $packageDeployPath
echo ""
echo "开始配置新版项目的 Tomcat 服务"
cat > /etc/systemd/system/$tomcatNewName.service << EOF
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=$packageDeployPath/$tomcatNewName
Environment="JAVA_HOME=$packageDeployPath/$javaHomeName"
Environment="CATALINA_PID=$packageDeployPath/$tomcatNewName/temp/$tomcatNewName.pid"
ExecStart=$packageDeployPath/$tomcatNewName/bin/startup.sh
ExecStop=$packageDeployPath/$tomcatNewName/bin/shutdown.sh
Restart=always

[Install]
WantedBy=default.target
EOF
systemctl daemon-reload
systemctl start $tomcatNewName.service 1>& /dev/null
echo "正在更新 Tomcat 配置"
tomcatIsActive=$(systemctl is-active $tomcatNewName.service)
if [ "${tomcatIsActive}" = "active" ]; then
	echo "服务正在运行，正在停止"
	systemctl stop $tomcatNewName.service 1>& /dev/null
	sleep 2
fi

if [ -f $packageDeployPath/$tomcatNewName/temp/$tomcatNewName.pid ]; then
	echo "发现进程文件，正在读取进程文件中的进程号并尝试停止"
	pkill -F $packageDeployPath/$tomcatNewName/temp/$tomcatNewName.pid
	sleep 2
fi
if pgrep -f $tomcatNewName >/dev/null 2>&1; then
	echo "发现匹配进程，正在尝试停止"
	kill "$(pgrep -f $tomcatNewName)"
	sleep 2
fi
if [ "$(ps aux|grep -c tomcat)" -gt 1 ]; then
	echo "发现残留 Tomcat 进程"
fi
cat > /etc/systemd/system/$tomcatNewName.service << EOF
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=$packageDeployPath/$tomcatNewName
Environment="JAVA_HOME=$packageDeployPath/$javaHomeName"
Environment="CATALINA_PID=$packageDeployPath/$tomcatNewName/temp/$tomcatNewName.pid"
ExecStartPre=/bin/rm -rf $packageDeployPath/$tomcatNewName/logs/catalina.out
ExecStart=$packageDeployPath/$tomcatNewName/bin/startup.sh
ExecStop=$packageDeployPath/$tomcatNewName/bin/shutdown.sh
Restart=always

[Install]
WantedBy=default.target
EOF
systemctl daemon-reload
systemctl enable $tomcatNewName.service --now 1>& /dev/null
sleep 2
tomcatIsActive=$(systemctl is-active $tomcatNewName.service)
if [ "${tomcatIsActive}" = "active" ]; then
	echo "Tomcat 部署完成"
else
	echo "Tomcat 部署失败"
fi
echo ""


echo "正在停止并清理上一版本以前的所有 Tomcat 服务及有关程序包"
mapfile -t needRemoveTomcatList < <(find $packageDeployPath -maxdepth 1 -type d -name "tomcat-*-*"|grep -v "$tomcatNewName\|$tomcatRunningName")
mapfile -t needRemoveTomcatServiceList < <(find /etc/systemd/system -maxdepth 1 -type f|grep -v "$tomcatNewName\|$tomcatRunningName"|awk -F '/' '{print $NF}')
for i in "${needRemoveTomcatServiceList[@]}";do
    if [ -f /etc/systemd/system/"$i".service ]; then
        if systemctl is-active "$i".service >/dev/null 2>&1; then
            systemctl stop "$i".service
            sleep 2
        fi
        if systemctl is-enabled "$i".service >/dev/null 2>&1; then
            systemctl disable "$i".service 1>& /dev/null
        fi
        rm -rf /etc/systemd/system/"$i".service
    fi
    if [ -f $packageDeployPath/"$i"/temp/"$i".pid ]; then
        echo "发现 Tomcat 进程文件，正在读取进程文件中的进程号并尝试停止"
        pkill -F $packageDeployPath/"$i"/temp/"$i".pid
        sleep 2
    fi
    if pgrep -f "$i" >/dev/null 2>&1; then
        echo "发现 Tomcat 匹配进程，正在尝试停止"
        kill "$(pgrep -f "$i")"
        sleep 2
    fi
done

for i in "${needRemoveTomcatList[@]}";do
    rm -rf "$i"
done

if [ "$(ps aux|grep -c tomcat)" -gt 2 ]; then
    echo "发现残留 Tomcat 进程"
else
    echo "Tomcat 服务停止并清理完成"
fi
echo ""

