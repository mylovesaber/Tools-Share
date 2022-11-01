#!/bin/bash
if MYSQL_REAL_COMMAND -u"MYSQL_USERNAME" -p"MYSQL_PASSWORD" <<< "CREATE DATABASE IF NOT EXISTS DATABASE_NEW_NAME;" >/dev/null 2>&1; then
    echo "新数据库创建完成"
else
    echo "新数据库创建失败，请手动检查环境"
fi

if MYSQLDUMP_REAL_COMMAND -u"MYSQL_USERNAME" -p"MYSQL_PASSWORD" DATABASE_OLD_NAME | MYSQL_REAL_COMMAND -u"MYSQL_USERNAME" -p"MYSQL_PASSWORD" DATABASE_NEW_NAME >/dev/null 2>&1; then
    echo "上一版本数据库迁移完成"
else
    echo "上一版本数据库迁移失败，请手动检查环境"
fi
MYSQLREALCOMMAND -u"MYSQL_USERNAME" -p"MYSQL_PASSWORD" <<EOF
USE DATABASE_NEW_NAME;
source /tmp/SQL_FILE_NAME
EOF
if [ "$?" -eq 0 ]; then
    echo "项目数据导入成功"
    rm -rf /tmp/SQL_FILE_NAME
else
	echo "项目数据导入出现问题，请手动检查环境"
fi
echo ""