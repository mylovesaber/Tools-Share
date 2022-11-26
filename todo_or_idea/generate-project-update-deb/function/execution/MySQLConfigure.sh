#!/bin/bash
ImportNewSQLFileToOldDB(){
    cp -a source/"$sqlFileName" build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp/"$packageSource"
    cp -a component/scripts/ImportNewSQLFileToOldDB.sh build/"$packageSource"/combine
    local SHPath="build/$packageSource/combine/ImportNewSQLFileToOldDB.sh"
    sed -i '1d' "$SHPath"
    sed -i "s|MYSQL_REAL_COMMAND|$mysqlRealCommand|g" "$SHPath"
    sed -i "s/MYSQL_USERNAME/$mysqlUsername/g" "$SHPath"
    sed -i "s/MYSQL_PASSWORD/$mysqlPassword/g" "$SHPath"
    sed -i "s/DATABASE_OLD_NAME/$databaseOldName/g" "$SHPath"
    sed -i "s/SQL_FILE_NAME/$sqlFileName/g" "$SHPath"
    sed -i "s/PACKAGE_SOURCE/$packageSource/g" "$SHPath"
}

MigrateDatabase(){
    cp -a source/"$sqlFileName" build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp/"$packageSource"
    cp -a component/scripts/MigrateDatabase.sh build/"$packageSource"/combine
    local SHPath="build/$packageSource/combine/MigrateDatabase.sh"
    sed -i '1d' "$SHPath"
    sed -i "s|MYSQL_REAL_COMMAND|$mysqlRealCommand|g" "$SHPath"
    sed -i "s|MYSQLDUMP_REAL_COMMAND|$mysqldumpRealCommand|g" "$SHPath"
    sed -i "s/MYSQL_USERNAME/$mysqlUsername/g" "$SHPath"
    sed -i "s/MYSQL_PASSWORD/$mysqlPassword/g" "$SHPath"
    sed -i "s/DATABASE_OLD_NAME/$databaseOldName/g" "$SHPath"
    sed -i "s/DATABASE_NEW_NAME/$databaseNewName/g" "$SHPath"
    sed -i "s/SQL_FILE_NAME/$sqlFileName/g" "$SHPath"
    sed -i "s/PACKAGE_SOURCE/$packageSource/g" "$SHPath"
}

if [ "$tomcatSkip" -eq 1 ] || [ "$tomcatPlan" = "frontend" ]; then
    _info "开始设置 MySQL 的导入方案的文件配置和钩子脚本处理"
    ImportNewSQLFileToOldDB
    _success "导入方案处理完成"
elif [[ "$tomcatPlan" =~ "backend"|"double"|"none" ]]; then
    _info "开始设置 MySQL 的迁移方案的文件配置和钩子脚本处理"
    MigrateDatabase
    _success "迁移方案处理完成"
fi