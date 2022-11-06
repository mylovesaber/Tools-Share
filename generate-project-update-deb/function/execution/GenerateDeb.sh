#!/bin/bash
GenerateOrigArchive(){
    _info "开始生成打包所需压缩包(根据需打包资源体积可能需要等待非常长的时间)"
    SpendingTime "dh_make --createorig -sy"
    _success "压缩包生成完成"
}

ModifyDebianFolder(){
    _info "开始设置安装包必要参数"
    cat > debian/control <<EOF
Source: $packageSource
Section: $packageSection
Priority: $packagePriority
Maintainer: $packageMaintainer
Build-Depends: debhelper (>=9)
Standards-Version: 3.9.6
Homepage: $packageHomepage
#Vcs-Git: git://anonscm.debian.org/collab-maint/$packageSource.git
#Vcs-Browser: https://anonscm.debian.org/cgit/collab-maint/$packageSource.git

Package: $packageName
Architecture: $packageArchitecture
Depends: $packageDepends
Description: $packageDescription
$packageMoreDescription
EOF

    cat << EOF >> debian/rules
override_dh_auto_build:

override_dh_shlibdeps:

override_dh_strip:

EOF

    cat > debian/install <<EOF
tmp/$packageSource /opt
usr/share/icons/hicolor/scalable/$projectIconName /usr/share/icons/hicolor/scalable
EOF
    _success "安装包必要参数设置完成"
}

HookScriptsCombine(){
    _info "开始整合钩子脚本"
    touch debian/postinst
    chmod +x debian/postinst
    echo -e "#!/bin/bash\n" > debian/postinst
    rm -rf debian/{*.ex,*.EX}
    if [ "$tomcatSkip" -eq 0 ] && [ "$mysqlSkip" -eq 0 ]; then
        case "$tomcatPlan" in
        "none"|"double")
            _info "开始合并 Tomcat 启动方案的钩子脚本"
            cat ../combine/StartProjectDirectly.sh >> debian/postinst
            _success "Tomcat 启动方案的钩子脚本合并完成"
        ;;
        "frontend"|"backend")
            _info "开始合并 Tomcat 迁移方案的钩子脚本"
            cat ../combine/MigrateProject.sh >> debian/postinst
            _success "Tomcat 迁移方案的钩子脚本合并完成"
        ;;
        *)
        esac

        case "$tomcatPlan" in
        "none"|"double"|"backend")
            _info "开始合并 MySQL 迁移方案的钩子脚本"
            cat ../combine/MigrateDatabase.sh >> debian/postinst
            _success "MySQL 迁移方案的钩子脚本合并完成"
        ;;
        "frontend")
            _info "开始合并 MySQL 导入方案的钩子脚本"
            cat ../combine/ImportNewSQLFileToOldDB.sh >> debian/postinst
            _success "MySQL 导入方案的钩子脚本合并完成"
        ;;
        *)
        esac

        _info "开始合并程序图标处理脚本"
        cat ../combine/PlaceDesktopFile.sh >> debian/postinst
        _info "程序图标处理脚本合并完成"
    elif [ "$tomcatSkip" -eq 0 ] && [ "$mysqlSkip" -eq 1 ]; then
        case "$tomcatPlan" in
        "none"|"double")
            _info "开始合并 Tomcat 启动方案的钩子脚本"
            cat ../combine/StartProjectDirectly.sh >> debian/postinst
            _success "Tomcat 启动方案的钩子脚本合并完成"
        ;;
        "frontend"|"backend")
            _info "开始合并 Tomcat 迁移方案的钩子脚本"
            cat ../combine/MigrateProject.sh >> debian/postinst
            _success "Tomcat 迁移方案的钩子脚本合并完成"
        ;;
        *)
        esac

        _info "开始合并程序图标处理脚本"
        cat ../combine/PlaceDesktopFile.sh >> debian/postinst
        _info "程序图标处理脚本合并完成"
    elif [ "$tomcatSkip" -eq 1 ] && [ "$mysqlSkip" -eq 0 ]; then
        _info "开始合并 MySQL 导入方案的钩子脚本"
        cat ../combine/ImportNewSQLFileToOldDB.sh >> debian/postinst
        _success "MySQL 导入方案的钩子脚本合并完成"
    fi
    _success "钩子脚本整合完成"
}

GenerateFinalDeb(){
    _info "开始生成最终安装包(根据需打包资源体积可能需要等待非常长的时间)"
    SpendingTime "debuild -i -us -uc -b"
    _success "安装包生成完成"
    _info "正在将生成的安装包复制到 output 文件夹中"
    cp -af ../*.deb ../../../output
    _success "打包流程结束，生成的安装包已放置到此路径下: $(pwd ../../../output)"
}

cd build/"$packageSource"/"$packageSource"-"$packageVersion" || exit 1
GenerateOrigArchive
ModifyDebianFolder
HookScriptsCombine
GenerateFinalDeb