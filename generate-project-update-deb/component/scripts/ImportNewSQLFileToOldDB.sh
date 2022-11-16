#!/bin/bash
# 变量
mysqlRealCommand="MYSQL_REAL_COMMAND"
mysqlUsername="MYSQL_USERNAME"
mysqlPassword="MYSQL_PASSWORD"
databaseOldName="DATABASE_OLD_NAME"
sqlFileName="SQL_FILE_NAME"
packageSource="PACKAGE_SOURCE"

echo "正在导入项目数据"
if MYSQL_PWD="$mysqlPassword" $mysqlRealCommand -u"$mysqlUsername" -e "\
CREATE DATABASE IF NOT EXISTS $databaseOldName; \
USE $databaseOldName; \
source /tmp/$packageSource/$sqlFileName; \
"; then
    echo "项目数据导入成功"
else
	echo "项目数据导入出现问题，请手动检查环境"
fi
echo ""

