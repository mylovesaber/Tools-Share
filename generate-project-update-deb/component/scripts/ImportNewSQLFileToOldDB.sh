#!/bin/bash
echo "正在导入项目数据"
MYSQL_REAL_COMMAND -u"MYSQL_USERNAME" -p"MYSQL_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS DATABASE_OLD_NAME;
USE DATABASE_OLD_NAME;
source /tmp/SQL_FILE_NAME
EOF
if [ "$?" -eq 0 ]; then
    echo "项目数据导入成功"
    rm -rf /tmp/SQL_FILE_NAME
else
	echo "项目数据导入出现问题，请手动检查环境"
fi
echo ""