#!/bin/bash
echo "packageDeployPath= $packageDeployPath"
echo "packageInsidePath= $packageInsidePath"
echo "commonDate= $commonDate"
echo "needClean= $needClean"
echo ""
echo "packageSkip= $packageSkip"
if [ "$packageSkip" -eq 0 ]; then
    echo "packageMaintainer= $packageMaintainer"
    echo "packageHomepage= $packageHomepage"
    echo "packageName= $packageName"
    echo "packageArchitecture= $packageArchitecture"
    echo "packageDepends= $packageDepends"
    echo "packageDescription= $packageDescription"
    echo "packageMoreDescription= $packageMoreDescription"
    echo "packageVersion= $packageVersion"
    echo "packageSource= $packageSource"
fi
echo ""
echo "tomcatSkip= $tomcatSkip"
if [ "$tomcatSkip" -eq 0 ]; then
    echo "tomcatVersion= $tomcatVersion"
    echo "excludeJar= $excludeJar"
    echo "catalinaOption= $catalinaOption"
    echo "tomcatNewPort= $tomcatNewPort"
    echo "tomcatPreviousPort= $tomcatPreviousPort"
    echo "tomcatIntegrityCheckSkip= $tomcatIntegrityCheckSkip"
    if [ "$tomcatIntegrityCheckSkip" -eq 0 ] && [ "$deleteTomcatArchive" -eq 1 ]; then
        echo "deleteTomcatArchive= $deleteTomcatArchive"
    fi
fi
echo ""
echo "mysqlSkip= $mysqlSkip"
if [ "$mysqlSkip" -eq 0 ]; then
    echo "dependenciesInstalled= $dependenciesInstalled"
    if [ "$dependenciesInstalled" -eq 1 ]; then
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
    fi
fi

