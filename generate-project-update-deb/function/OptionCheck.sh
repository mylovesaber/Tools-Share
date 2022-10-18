#!/bin/bash
GetValue(){
    awk /^"$1"/'{print $0}' ../generate-deb.conf|cut -d'=' -f 2-
}

packageDeployPath=$(GetValue package-deploy-path)
packageSkip=$(GetValue package-skip)
packageMaintainer=$(GetValue package-maintainer)
packageHomepage=$(GetValue package-homepage)
packageName=$(GetValue package-name)
packageArchitecture=$(GetValue package-architecture)
packageDependsBaseName=$(GetValue package-depends-base-name)
packageDependsBaseVersion=$(GetValue package-depends-base-version)
packageMoreDescription=$(GetValue package-more-description)
packageVersion=$(GetValue package-version)
packageSource=$(GetValue package-source)
tomcatSkip=$(GetValue tomcat-skip)
tomcatVersion=$(GetValue tomcat-version)
excludeJar=$(GetValue exclude-jar)
catalinaOption=$(GetValue catalina-option)
mysqlSkip=$(GetValue mysql-skip)
mysqlUsername=$(GetValue mysql-username)
mysqlPassword=$(GetValue mysql-password)
mysqlBinPath=$(GetValue mysql-bin-path)
sqlFileName=$(GetValue sql-file-name)
commonDate=$(GetValue common-date)
needClean=$(GetValue need-clean)
databaseNewName=$(GetValue database-new-name)
databaseOldName=$(GetValue database-old-name)
tomcatNewPort=$(GetValue tomcat-new-port)
tomcatPreviousPort=$(GetValue tomcat-previous-port)

# 以下是测试选项读取情况
echo "packageDeployPath= $packageDeployPath"
echo "packageSkip= $packageSkip"
echo "packageMaintainer= $packageMaintainer"
echo "packageHomepage= $packageHomepage"
echo "packageName= $packageName"
echo "packageArchitecture= $packageArchitecture"
echo "packageDependsBaseName= $packageDependsBaseName"
echo "packageDependsBaseVersion= $packageDependsBaseVersion"
echo "packageMoreDescription= $packageMoreDescription"
echo "packageVersion= $packageVersion"
echo "packageSource= $packageSource"
echo "tomcatSkip= $tomcatSkip"
echo "tomcatVersion= $tomcatVersion"
echo "excludeJar= $excludeJar"
echo "catalinaOption= $catalinaOption"
echo "mysqlSkip= $mysqlSkip"
echo "mysqlUsername= $mysqlUsername"
echo "mysqlPassword= $mysqlPassword"
echo "mysqlBinPath= $mysqlBinPath"
echo "sqlFileName= $sqlFileName"
echo "commonDate= $commonDate"
echo "needClean= $needClean"
echo "databaseNewName= $databaseNewName"
echo "databaseOldName= $databaseOldName"
echo "tomcatNewPort= $tomcatNewPort"
echo "tomcatPreviousPort= $tomcatPreviousPort"
