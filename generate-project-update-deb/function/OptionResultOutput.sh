#!/bin/bash
echo "packageDeployPath= $packageDeployPath"
echo "commonDate= $commonDate"
echo "needClean= $needClean"
echo "packageSkip= $packageSkip"
echo "packageMaintainer= $packageMaintainer"
echo "packageHomepage= $packageHomepage"
echo "packageName= $packageName"
echo "packageArchitecture= $packageArchitecture"
echo "packageDepends= $packageDepends"
echo "packageDescription= $packageDescription"
echo "packageMoreDescription= $packageMoreDescription"
echo "packageVersion= $packageVersion"
echo "packageSource= $packageSource"
echo "tomcatSkip= $tomcatSkip"
echo "tomcatVersion= $tomcatVersion"
echo "excludeJar= $excludeJar"
echo "catalinaOption= $catalinaOption"
echo "tomcatNewPort= $tomcatNewPort"
echo "tomcatPreviousPort= $tomcatPreviousPort"
echo "tomcatIntegrityCheckSkip= $tomcatIntegrityCheckSkip"
echo "mysqlSkip= $mysqlSkip"
echo "dependenciesInstalled= $dependenciesInstalled"
echo "sqlFileName= $sqlFileName"
echo "mysqlUsername= $mysqlUsername"
echo "mysqlPassword= $mysqlPassword"
echo "databaseOldName= $databaseOldName"
echo "databaseBaseName= $databaseBaseName"
echo "mysqlBinPath= $mysqlBinPath"
if [ -n "$mysqlBinPath" ]; then
    echo "mysqlRealCommand= $mysqlRealCommand"
    echo "mysqldumpRealCommand= $mysqldumpRealCommand"
fi

