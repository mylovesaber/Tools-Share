#!/bin/bash
echo "packageDeployPath: $packageDeployPath"
echo "commonDate: $commonDate"
echo "needClean: $needClean"
echo "dependenciesInstalled: $dependenciesInstalled"
echo ""
echo "packageSkip: $packageSkip"
if [ "$packageSkip" -eq 0 ]; then
    echo "packageMaintainer: $packageMaintainer"
    echo "packageHomepage: $packageHomepage"
    echo "packageName: $packageName"
    echo "packageArchitecture: $packageArchitecture"
    echo "packageDepends: $packageDepends"
    echo "packageDescription: $packageDescription"
    echo "packageMoreDescription: $packageMoreDescription"
    echo "packageVersion: $packageVersion"
    echo "packageSource: $packageSource"
fi
echo ""
echo "tomcatSkip: $tomcatSkip"
if [ "$tomcatSkip" -eq 0 ]; then
    echo "tomcatVersion: $tomcatVersion"
    if [ "$dependenciesInstalled" -eq 1 ]; then
        echo "tomcatLatestRunningVersion: $tomcatLatestRunningVersion"
    fi
    echo "excludeJar: $excludeJar"
    echo "tomcatNewPort: $tomcatNewPort"
    echo "tomcatPreviousPort: $tomcatPreviousPort"
    echo "tomcatIntegrityCheckSkip: $tomcatIntegrityCheckSkip"
    if [ "$tomcatIntegrityCheckSkip" -eq 0 ];then
        echo "上面是tomcatIntegrityCheckSkip"
        if [ "$deleteTomcatArchive" -eq 1 ]; then
            echo "进入 deleteTomcatArchive"
            echo "deleteTomcatArchive: $deleteTomcatArchive"
        fi
    fi
    for i in "${!catalinaOptionList[@]}" ; do
        echo "catalinaOption$i: ${catalinaOptionList[$i]}"
    done
fi
echo ""
echo "mysqlSkip: $mysqlSkip"
if [ "$mysqlSkip" -eq 0 ]; then
    echo "sqlFileName: $sqlFileName"
    echo "mysqlUsername: $mysqlUsername"
    echo "mysqlPassword: $mysqlPassword"
    echo "databaseOldName: $databaseOldName"
    echo "databaseBaseName: $databaseBaseName"
    if [ "$dependenciesInstalled" -eq 1 ]; then
        echo "mysqlBinPath: $mysqlBinPath"
        if [ -n "$mysqlBinPath" ]; then
            echo "mysqlRealCommand: $mysqlRealCommand"
            echo "mysqldumpRealCommand: $mysqldumpRealCommand"
        fi
    fi
fi

