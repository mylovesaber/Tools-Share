#!/bin/bash

old=${IFS}
#将内部域分隔符设置为换行
IFS=$'\n'
#自定义颜色
red='\E[1;31m'  
yellow='\E[1;33m' 
blue='\E[1;34m'  
green='\E[1;36m'  
reset='\E[0m'

##电影文件后缀
suffixes[0]='mkv'
suffixes[1]='mp4'
##目录层级（电影目录作为根目录算起，包括根目录）
level=4
##转义特殊字符
specChars[0]=' '
specChars[1]='['
specChars[2]=']'
specChars[3]='('
specChars[4]=')'

# #全局路径
# ##电影目录
moviePaths[0]='/mnt/user/media/movie/'
moviePaths[1]='/mnt/user/media/frighten/'
# ##Kodi电影硬链目录
kodiMoviesPath='/mnt/user/media/kodi/movie/'
# ##已保存的电影硬链信息文件
movieInfo='/mnt/user/media/movie/kodiMovies.info'

echo
echo
echo -e "${yellow}####################################################################${reset} "
echo
echo -e "                 ${green}1.为所有电影创建硬链接${reset} "
echo -e "                 ${green}2.为新增电影创建硬链接${reset} "
echo
echo -e "${yellow}####################################################################${reset} "
echo
echo
echo -e "${red}输入数字执行相应功能（第一次使用请执行1）：${reset}"
read order
echo
echo -e "${red}输入一个硬链接目录绝对路径（直接回车则使用内置目录，目录需要以/斜杠结尾）：${reset}"
read kodiMoviesPath
echo
    if [[ -z $kodiMoviesPath || ! -d $kodiMoviesPath ]]
    then
        kodiMoviesPath=$kodiDefaultMoviesPath
    fi
#配置路径
echo -e "${red}输入多个电影目录绝对路径（直接回车则使用内置目录，0终止，目录需要以/斜杠结尾）：${reset}"
watch=0
while read tempPaths[$watch]
do
    if [ -z ${tempPaths[$watch]} ]
    then
        watch=-1
        echo
        echo
        echo
        echo -e "${red}--------------->>>>>>开始解析......${reset}"
        break
    elif [ -d ${tempPaths[$watch]} ]
    then
        let watch++
    elif [ ${tempPaths[$watch]} == 0 ]
    then
        echo
        echo
        echo
        echo -e "${red}--------------->>>>>>开始解析......${reset}"
        break
    else
        watch=-1
        echo
        echo
        echo
        echo -e "${red}--------------->>>>>>开始解析......${reset}"
        break
    fi
done

#执行任务2
#为新电影创建硬链接
if [ $order == 2 ]
then
    ##判断是否采用内置路径
    if [[ $watch == -1 || ${tempPaths[0]} == 0 ]]
    then
        ##内置目录筛选新增电影
        watch=0
        for point in ${suffixes[@]}
        do
            startPoints[$watch]=$(cat $movieInfo | awk "/$point/ {print $NF}" | grep "$point" | wc -l)
            test=$(ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}")
            for char in ${specChars[@]}
            do
                ###//全局替换，/替换第一个出现的，${字符变量//匹配的字符/替换的字符}
                test=${test//$char/'\'$char}
            done
            movies[$watch]=$test
            let watch++
        done
        ##bash数组从0开始,为此起点不用加1
        success=0
        watch=0
        for perSpecific in "${movies[@]}"
        do
            i=${startPoints[$watch]}
            ###拼接成一维数组
            movie=($perSpecific)
            echo ${suffixes[$watch]}"后缀视频文件====>已硬链"$i"部电影 : 总共"${#movie[@]}"部电影"
            while [[ $i -lt ${#movie[@]} ]]
            do
                for path in ${moviePaths[@]}
                do
                    patternDir=''
                    levelForDir=$level
                    while [ $levelForDir -gt 0 ]
                    do
                        ls $path$patternDir${movie[$i]} > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            patternDir=$patternDir"*/"
                        else
                            ln $path$patternDir${movie[$i]}  $kodiMoviesPath
                            success=1
                            break
                        fi
                        let levelForDir--
                    done
                    if [ $success == 1 ]
                    then
                        success=0
                        break
                    fi
                done
                let i++
            done
            let watch++
        done
        #保存Movies文件信息
        watch=0
        for point in ${suffixes[@]}
        do
            if [ $point != ${suffixes[((${#suffixes[@]}-1))]} ]
            then
                ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" > $movieInfo
            else
                ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" >> $movieInfo
            fi
            countAll[$watch]=$(ls -Rl ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" | grep "^-" | wc -l)
            let watch++
        done
        #统计电影总数
        allMovies=0
        for count in ${countAll[@]}
        do
            let allMovies=allMovies+count
        done
        echo "共计$allMovies部电影"
    else
        ##先将最后终止时读入的0排除
        watch=0
        for tempPath in ${tempPaths[@]}
        do
            if [ tempPath != 0 ]
            then
                tempBoxes[$watch]=tempPath
                let watch++
            fi
        done
        ##筛选新增电影
        watch=0
        for point in ${suffixes[@]}
        do
            startPoints[$watch]=$(cat $movieInfo | awk "/$point/ {print $NF}" | grep "$point" | wc -l)
            test=$(ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}")
            for char in ${specChars[@]}
            do
                ###//全局替换，/替换第一个出现的，${字符变量//匹配的字符/替换的字符}
                test=${test//$char/'\'$char}
            done
            movies[$watch]=$test
            let watch++
        done
        ##bash数组从0开始,为此起点不用加1
        #为新增电影创建硬链接
        success=0
        watch=0
        for perSpecific in "${movies[@]}"
        do
            i=${startPoints[$watch]}
            ###拼接成一维数组
            movie=($perSpecific)
            echo ${suffixes[$watch]}"后缀视频文件====>已硬链"$i"部电影 : 总共"${#movie[@]}"部电影"
            while [[ $i -lt ${#movie[@]} ]]
            do
                for path in ${tempBoxes[@]}
                do
                    patternDir=''
                    levelForDir=$level
                    while [ $levelForDir -gt 0 ]
                    do
                        ls $path$patternDir${movie[$i]} > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            patternDir=$patternDir"*/"
                        else
                            ln $path$patternDir${movie[$i]}  $kodiMoviesPath
                            success=1
                            break
                        fi
                        let levelForDir--
                    done
                    if [ $success == 1 ]
                    then
                        success=0
                        break
                    fi
                done
                let i++
            done
            let watch++
        done
        #保存Movies文件信息
        watch=0
        for point in ${suffixes[@]}
        do
            if [ $point != ${suffixes[((${#suffixes[@]}-1))]} ]
            then
                ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" > $movieInfo
            else
                ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" >> $movieInfo
            fi
            countAll[$watch]=$(ls -Rl ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" | grep "^-" | wc -l)
            let watch++
        done
        #统计电影总数
        allMovies=0
        for count in ${countAll[@]}
        do
            let allMovies=allMovies+count
        done
        echo "共计$allMovies部电影"
    fi
#执行任务1
##为所有目录中的电影创建硬链接
else
    ###判断是否采用内置路径
    if [[ $watch == -1 || ${tempPaths[0]} == 0 ]]
    then
        ###筛选特定后缀电影
        watch=0
        for point in ${suffixes[@]}
        do
            test=$(ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}")
            for char in ${specChars[@]}
            do
                ###//全局替换，/替换第一个出现的，${字符变量//匹配的字符/替换的字符}
                test=${test//$char/'\'$char}
            done
            movies[$watch]=$test
            let watch++
        done
        ###为所有电影创建硬链接
        success=0
        watch=0
        ###for直接遍历一维或多维数组
        for movie in ${movies[@]}
        do
            for path in ${moviePaths[@]}
            do
                patternDir=''
                levelForDir=$level
                while [ $levelForDir -gt 0 ]
                do
                    ls $path$patternDir$movie > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        patternDir=$patternDir"*/"
                    else
                        ln $path$patternDir$movie  $kodiMoviesPath
                        success=1
                        break
                    fi
                    let levelForDir--
                done
                if [ $success == 1 ]
                then
                    success=0
                    break
                fi
            done
        done
        ###保存Movies文件信息
        watch=0
        for point in ${suffixes[@]}
        do
            if [ $point != ${suffixes[((${#suffixes[@]}-1))]} ]
            then
                ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" > $movieInfo
            else
                ls -Rrt ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" >> $movieInfo
            fi
            countAll[$watch]=$(ls -Rl ${moviePaths[@]} | awk -F / "/$point/ {print $NF}" | grep "^-" | wc -l)
            let watch++
        done
        ###统计电影总数
        allMovies=0
        for count in ${countAll[@]}
        do
            let allMovies=allMovies+count
        done
        echo "共计$allMovies部电影"
    else
        ###先将最后终止时读入的0排除
        watch=0
        for tempPath in ${tempPaths[@]}
        do
            if [ tempPath != 0 ]
            then
                tempBoxes[$watch]=tempPath
                let watch++
            fi
        done
        ###筛选特定后缀电影
        watch=0
        for point in ${suffixes[@]}
        do
            test=$(ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}")
            for char in ${specChars[@]}
            do
                ###//全局替换，/替换第一个出现的，${字符变量//匹配的字符/替换的字符}
                test=${test//$char/'\'$char}
            done
            movies[$watch]=$test
            let watch++
        done
        ###为所有电影创建硬链接
        success=0
        watch=0
        ###for直接遍历一维或多维数组
        for movie in ${movies[@]}
        do
            for path in ${tempBoxes[@]}
            do
                patternDir=''
                levelForDir=$level
                while [ $levelForDir -gt 0 ]
                do
                    ls $path$patternDir$movie > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        patternDir=$patternDir"*/"
                    else
                        ln $path$patternDir$movie  $kodiMoviesPath
                        success=1
                        break
                    fi
                    let levelForDir--
                done
                if [ $success == 1 ]
                then
                    success=0
                    break
                fi
            done
        done
        ###保存Movies文件信息
        watch=0
        for point in ${suffixes[@]}
        do
            if [ $point != ${suffixes[((${#suffixes[@]}-1))]} ]
            then
                ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" > $movieInfo
            else
                ls -Rrt ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" >> $movieInfo
            fi
            countAll[$watch]=$(ls -Rl ${tempBoxes[@]} | awk -F / "/$point/ {print $NF}" | grep "^-" | wc -l)
            let watch++
        done
        ###统计电影总数
        allMovies=0
        for count in ${countAll[@]}
        do
            let allMovies=allMovies+count
        done
        echo "共计$allMovies部电影"
    fi
fi
IFS=${old}
