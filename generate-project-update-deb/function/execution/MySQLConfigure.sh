#!/bin/bash
ImportNewSQLFileToOldDB(){
    cp -a component/scripts/ImportNewSQLFileToOldDB.sh build/"$packageSource"/combine
    cp -a source/"$sqlFileName" build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp
    local SHPath="build/combine/ImportNewSQLFileToOldDB.sh"
    sed -i '1d' "$SHPath"
    sed -i "s/MYSQL_REAL_COMMAND/$mysqlRealCommand/g" "$SHPath"
    sed -i "s/MYSQL_USERNAME/$mysqlUsername/g" "$SHPath"
    sed -i "s/MYSQL_PASSWORD/$mysqlPassword/g" "$SHPath"
    sed -i "s/DATABASE_OLD_NAME/$databaseOldName/g" "$SHPath"
    sed -i "s/SQL_FILE_NAME/$sqlFileName/g" "$SHPath"
}

MigrateDatabase(){
    cp -a source/"$sqlFileName" build/"$packageSource"/"$packageSource"-"$packageVersion"/tmp
    local SHPath="build/combine/MigrateDatabase.sh"
    sed -i '1d' "$SHPath"
    sed -i "s/MYSQL_REAL_COMMAND/$mysqlRealCommand/g" "$SHPath"
    sed -i "s/MYSQLDUMP_REAL_COMMAND/$mysqldumpRealCommand/g" "$SHPath"
    sed -i "s/MYSQL_USERNAME/$mysqlUsername/g" "$SHPath"
    sed -i "s/MYSQL_PASSWORD/$mysqlPassword/g" "$SHPath"
    sed -i "s/DATABASE_OLD_NAME/$databaseOldName/g" "$SHPath"
    sed -i "s/DATABASE_NEW_NAME/$databaseNewName/g" "$SHPath"
    sed -i "s/SQL_FILE_NAME/$sqlFileName/g" "$SHPath"
}

if [ "$tomcatSkip" -eq 1 ] || [ "$tomcatPlan" = "frontend" ]; then
    ImportNewSQLFileToOldDB
elif [[ "$tomcatPlan" =~ "backend"|"double"|"none" ]]; then
    MigrateDatabase
fi