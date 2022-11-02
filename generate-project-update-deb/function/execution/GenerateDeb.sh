#!/bin/bash
PlaceDesktopFile(){
    cp -a source/"$projectIconName" build/"$packageSource"/"$packageSource"-"$packageVersion"/usr/share/icons/hicolor/scalable
    cp -a component/desktopfile/* build/"$packageSource"/"$packageSource"-"$packageVersion"/usr/share/applications
}