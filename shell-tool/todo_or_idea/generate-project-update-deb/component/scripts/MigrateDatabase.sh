#!/bin/bash
# 变量
mysqlRealCommand="MYSQL_REAL_COMMAND"
mysqlUsername="MYSQL_USERNAME"
mysqlPassword="MYSQL_PASSWORD"
databaseOldName="DATABASE_OLD_NAME"
databaseNewName="DATABASE_NEW_NAME"
sqlFileName="SQL_FILE_NAME"
mysqldumpRealCommand="MYSQLDUMP_REAL_COMMAND"
packageSource="PACKAGE_SOURCE"

echo ""
echo "开始更新新版本项目的数据库"
echo "开始创建新数据库"
if MYSQL_PWD="$mysqlPassword" $mysqlRealCommand -u"$mysqlUsername" -e "CREATE DATABASE IF NOT EXISTS $databaseNewName;" 1>/dev/null; then
    echo "新数据库创建完成"
else
    echo "新数据库创建失败，请手动检查环境"
fi
echo ""
echo "开始迁移上一版本数据库到新版本数据库"
if MYSQL_PWD="$mysqlPassword" $mysqldumpRealCommand -u"$mysqlUsername" $databaseOldName |MYSQL_PWD="$mysqlPassword" $mysqlRealCommand -u"$mysqlUsername" $databaseNewName 1>/dev/null; then
    echo "上一版本数据库迁移完成"
else
    echo "上一版本数据库迁移失败，请手动检查环境"
fi
echo ""
echo "开始导入更新的项目数据库内容"
if MYSQL_PWD="$mysqlPassword" $mysqlRealCommand -u"$mysqlUsername" -e "\
USE $databaseNewName; \
source /tmp/$packageSource/$sqlFileName; \
"; then
    echo "项目数据库内容导入成功"
else
	echo "项目数据库内容导入出现问题，请手动检查环境"
fi
echo ""

