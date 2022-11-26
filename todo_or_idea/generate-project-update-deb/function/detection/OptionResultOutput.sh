#!/bin/bash
echo "packageDeployPath: $packageDeployPath"
echo "commonDate: $commonDate"
echo "needClean: $needClean"
echo "dependenciesInstalled: $dependenciesInstalled"
echo "packageVersion: $packageVersion"
echo "packageSource: $packageSource"
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
fi
echo ""
echo "tomcatSkip: $tomcatSkip"
if [ "$tomcatSkip" -eq 0 ]; then
    echo "javaHomeName: $javaHomeName"
    echo "projectIconName: $projectIconName"
    echo "projectName: $projectName"
    echo "tomcatVersion: $tomcatVersion"
    echo "tomcatNewPort: $tomcatNewPort"
    echo "tomcatPreviousPort: $tomcatPreviousPort"
    echo "tomcatIntegrityCheckSkip: $tomcatIntegrityCheckSkip"
    if [ "$tomcatIntegrityCheckSkip" -eq 0 ]; then
        echo "tomcatLatestRunningVersion: $tomcatLatestRunningVersion"
    fi
    if [ "$tomcatIntegrityCheckSkip" -eq 0 ] && [ "$deleteTomcatArchive" -eq 1 ]; then
        echo "deleteTomcatArchive: $deleteTomcatArchive"
    fi
    for i in "${!excludeJarList[@]}" ; do
        echo "excludeJar$i: ${excludeJarList[$i]}"
    done
    for i in "${!catalinaOptionList[@]}" ; do
        echo "catalinaOption$i: ${catalinaOptionList[$i]}"
    done
    if [ -n "$tomcatFrontendName" ] && [ -n "$tomcatBackendName" ]; then
        tomcatPlan="double"
        echo "tomcatFrontendName: $tomcatFrontendName"
        echo "tomcatBackendName: $tomcatBackendName"
    elif [ -z "$tomcatFrontendName" ] && [ -z "$tomcatBackendName" ]; then
        tomcatPlan="none"
    elif [ -n "$tomcatFrontendName" ]; then
        tomcatPlan="frontend"
        echo "tomcatFrontendName: $tomcatFrontendName"
    elif [ -n "$tomcatBackendName" ]; then
        tomcatPlan="backend"
        echo "tomcatBackendName: $tomcatBackendName"
    fi
fi
echo ""
echo "mysqlSkip: $mysqlSkip"
if [ "$mysqlSkip" -eq 0 ]; then
    echo "sqlFileName: $sqlFileName"
    echo "mysqlUsername: $mysqlUsername"
    echo "mysqlPassword: $mysqlPassword"
    echo "databaseOldName: $databaseOldName"
    if [ "$tomcatSkip" -eq 0 ]; then
        echo "databaseBaseName: $databaseBaseName"
    fi
    if [ "$dependenciesInstalled" -eq 1 ]; then
        echo "mysqlBinPath: $mysqlBinPath"
        if [ -n "$mysqlBinPath" ]; then
            echo "mysqlRealCommand: $mysqlRealCommand"
            echo "mysqldumpRealCommand: $mysqldumpRealCommand"
        fi
    fi
fi

