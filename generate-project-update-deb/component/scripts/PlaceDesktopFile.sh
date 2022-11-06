#!/bin/bash
packageSource="PACKAGE_SOURCE"
desktopFileName="DESKTOP_FILE_NAME"

mapfile -t programFileNameList < <(find /tmp/$packageSource/desktopfile -maxdepth 1 -type f -name "*.desktop*"|awk -F '/' '{print $NF}'|cut -d'.' -f1)
noBrowserFound=1
for i in "${programFileNameList[@]}";do
    if which "$i" >/dev/null 2>&1; then
        chmod +x /tmp/$packageSource/desktopfile/"$i".desktop
        mv -f /tmp/$packageSource/desktopfile/"$i".desktop /usr/share/applications/$desktopFileName.desktop
        noBrowserFound=0
        break
    fi
done

if [ "$noBrowserFound" -eq 1 ]; then
    echo "没有找到已适配的浏览器软件，暂时只支持以下浏览器："
    echo "奇安信安全浏览器"
    echo "360 安全浏览器"
    echo "firefox(火狐)浏览器"
elif [ "$noBrowserFound" -eq 0 ]; then
    mapfile -t desktopPath < <(find /home -type d -name "桌面")
    for i in "${desktopPath[@]}"; do
        cp -af /usr/share/applications/$desktopFileName.desktop "$i"
        chmod 755 "$i"/$desktopFileName.desktop
        userName=$(awk -F '/' '{print $3}' <<< "$i")
        chown "${userName}": "$i"/archivecollectjswx.desktop
    done
fi
