#!/bin/bash
repeatPath="build/$packageSource/$packageSource-$packageVersion/tmp/tomcat-$tomcatVersion-$tomcatNewPort"
NewTomcatBaseConfigure(){
    mkdir -p "$repeatPath"
    echo "$commonDate" > "$repeatPath"/build-date
    tar -zxf build/apache-tomcat-"$tomcatVersion".tar.gz --strip-components 1 -C "$repeatPath"
    sed -i "s/<Connector port=\"8080/<Connector port=\"$tomcatNewPort/g" "$repeatPath"/conf/server.xml
    if [ -n "$excludeJar" ]; then
        sed -i "s/jarsToSkip=\\/jarsToSkip=\\$excludeJar/g" "$repeatPath"/conf/catalina.properties
    fi

    if [ -n "$catalinaOption" ]; then
        for i in "${!catalinaOptionList[@]}" ; do
            if [ "$i" -gt 0 ]; then
                echo "${catalinaOptionList[$i]}" >> "$repeatPath"/bin/setenv.sh
            elif [ "$i" -eq 0 ]; then
                echo "${catalinaOptionList[$i]}" > "$repeatPath"/bin/setenv.sh
            fi
        done
    fi
    chmod +x "$repeatPath"/bin/setenv.sh
}

NewTomcatSetProject(){
    case "$tomcatPlan" in
    "none")
        local mapfile -t folderList < <(find source -maxdepth 1 -type d)
        for i in "${folderList[@]}";do
            cp -a "$i" "$repeatPath"/webapps
        done
    ;;
    "double")
        cp -a source/"$tomcatFrontendName" "$repeatPath"/webapps
        cp -a source/"$tomcatBackendName" "$repeatPath"/webapps
    ;;
    "frontend")
        cp -a source/"$tomcatFrontendName" "$repeatPath"/webapps
    ;;
    "backend")
        cp -a source/"$tomcatBackendName" "$repeatPath"/webapps
    ;;
    *)
        _error "复制项目出现意外情况，请检查"
        exit 1
    esac
}

GenerateTomcatPostInst(){
    case "$tomcatPlan" in
    "none"|"double")
        cp -af component/scripts/StartProjectDirectly.sh build/"$packageSource"/combine
        local SHPath="build/combine/StartProjectDirectly.sh"
        sed -i '1d' "$SHPath"
        sed -i "s/TOMCAT_NEW_PORT/$tomcatNewPort/g" "$SHPath"
        sed -i "s/TOMCAT_VERSION/$tomcatVersion/g" "$SHPath"
        sed -i "s/TOMCAT_LATEST_RUNNING_VERSION/$tomcatLatestRunningVersion/g" "$SHPath"
        sed -i "s/TOMCAT_PREVIOUS_PORT/$tomcatPreviousPort/g" "$SHPath"
        sed -i "s/PACKAGE_DEPLOY_PATH/$packageDeployPath/g" "$SHPath"
        sed -i "s/JAVA_HOME_NAME/$javaHomeName/g" "$SHPath"
    ;;
    "frontend")
        local withoutMigrateFolderName="$tomcatFrontendName"
        cp -af component/scripts/MigrateProject.sh build/"$packageSource"/combine
        local SHPath="build/combine/MigrateProject.sh"
        sed -i '1d' "$SHPath"
        sed -i "s/TOMCAT_NEW_PORT/$tomcatNewPort/g" "$SHPath"
        sed -i "s/TOMCAT_VERSION/$tomcatVersion/g" "$SHPath"
        sed -i "s/TOMCAT_LATEST_RUNNING_VERSION/$tomcatLatestRunningVersion/g" "$SHPath"
        sed -i "s/TOMCAT_PREVIOUS_PORT/$tomcatPreviousPort/g" "$SHPath"
        sed -i "s/PACKAGE_DEPLOY_PATH/$packageDeployPath/g" "$SHPath"
        sed -i "s/JAVA_HOME_NAME/$javaHomeName/g" "$SHPath"
        sed -i "s/WITHOUT_MIGRATE_FOLDER_NAME/$withoutMigrateFolderName/g" "$SHPath"
    ;;
    "backend")
        local withoutMigrateFolderName="$tomcatBackendName"
        cp -af component/scripts/MigrateProject.sh build/"$packageSource"/combine
        local SHPath="build/combine/MigrateProject.sh"
        sed -i '1d' "$SHPath"
        sed -i "s/TOMCAT_NEW_PORT/$tomcatNewPort/g" "$SHPath"
        sed -i "s/TOMCAT_VERSION/$tomcatVersion/g" "$SHPath"
        sed -i "s/TOMCAT_LATEST_RUNNING_VERSION/$tomcatLatestRunningVersion/g" "$SHPath"
        sed -i "s/TOMCAT_PREVIOUS_PORT/$tomcatPreviousPort/g" "$SHPath"
        sed -i "s/PACKAGE_DEPLOY_PATH/$packageDeployPath/g" "$SHPath"
        sed -i "s/JAVA_HOME_NAME/$javaHomeName/g" "$SHPath"
        sed -i "s/WITHOUT_MIGRATE_FOLDER_NAME/$withoutMigrateFolderName/g" "$SHPath"
    ;;
    *)
        _error "复制项目出现意外情况，请检查"
        exit 1
    esac
}

NewTomcatBaseConfigure
NewTomcatSetProject
GenerateTomcatPostInst