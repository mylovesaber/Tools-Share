#!/bin/bash
# black=$(tput setaf 0)   ; red=$(tput setaf 1)          ; green=$(tput setaf 2)   ; yellow=$(tput setaf 3);  bold=$(tput bold)
# blue=$(tput setaf 4)    ; magenta=$(tput setaf 5)      ; cyan=$(tput setaf 6)    ; white=$(tput setaf 7) ;  normal=$(tput sgr0)
# on_black=$(tput setab 0); on_red=$(tput setab 1)       ; on_green=$(tput setab 2); on_yellow=$(tput setab 3)
# on_blue=$(tput setab 4) ; on_magenta=$(tput setab 5)   ; on_cyan=$(tput setab 6) ; on_white=$(tput setab 7)
# shanshuo=$(tput blink)  ; wuguangbiao=$(tput civis)    ; guangbiao=$(tput cnorm) ; jiacu=${normal}${bold}
# underline=$(tput smul)  ; reset_underline=$(tput rmul) ; dim=$(tput dim)
# standout=$(tput smso)   ; reset_standout=$(tput rmso)  ; title=${standout}
# baihuangse=${white}${on_yellow}; bailanse=${white}${on_blue}    ; bailvse=${white}${on_green}
# baiqingse=${white}${on_cyan}   ; baihongse=${white}${on_red}    ; baizise=${white}${on_magenta}
# heibaise=${black}${on_white}   ; heihuangse=${on_yellow}${black}
# CW="${bold}${baihongse} ERROR ${jiacu}";
# JG="${baihongse}${bold} WARNING ${jiacu}" ;
# ZY="${baihongse}${bold} ATTENTION ${jiacu}";

# echo "$black 测试颜色测试颜色测试颜色black $normal"
# echo "$red 测试颜色测试颜色测试颜色red $normal"
# echo "$green 测试颜色测试颜色测试颜色green $normal"
# echo "$yellow 测试颜色测试颜色测试颜色yellow $normal"
# echo "$blue 测试颜色测试颜色测试颜色blue $normal"
# echo "$magenta 测试颜色测试颜色测试颜色magenta $normal"
# echo "$cyan 测试颜色测试颜色测试颜色cyan $normal"
# echo "$white 测试颜色测试颜色测试颜色white $normal"
# echo ""
# echo "$on_black 测试颜色测试颜色测试颜色on_black $normal"
# echo "$on_red 测试颜色测试颜色测试颜色on_red $normal"
# echo "$on_green 测试颜色测试颜色测试颜色on_green $normal"
# echo "$on_yellow 测试颜色测试颜色测试颜色on_yellow $normal"
# echo "$on_blue 测试颜色测试颜色测试颜色on_blue $normal"
# echo "$on_magenta 测试颜色测试颜色测试颜色on_magenta $normal"
# echo "$on_cyan 测试颜色测试颜色测试颜色on_cyan $normal"
# echo "$on_white 测试颜色测试颜色测试颜色on_white $normal"
# echo ""
# echo "$shanshuo 测试颜色测试颜色测试颜色shanshuo $normal"
# echo "$wuguangbiao 测试颜色测试颜色测试颜色wuguangbiao $normal"
# echo "$guangbiao 测试颜色测试颜色测试颜色guangbiao $normal"
# echo "$bold 测试颜色测试颜色测试颜色bold $normal"
# echo "$normal 测试颜色测试颜色测试颜色normal $normal"
# echo "$underline 测试颜色测试颜色测试颜色underline $normal"
# echo "$reset_underline 测试颜色测试颜色测试颜色reset_underline $normal"
# echo "$dim 测试颜色测试颜色测试颜色dim $normal"
# echo "$standout 测试颜色测试颜色测试颜色standout $normal"
# echo "$reset_standout 测试颜色测试颜色测试颜色reset_standout $normal"
# echo ""
# echo "$title 测试颜色测试颜色测试颜色title $normal"
# echo "$baihuangse 测试颜色测试颜色测试颜色baihuangse $normal"
# echo "$bailanse 测试颜色测试颜色测试颜色bailanse $normal"
# echo "$bailvse 测试颜色测试颜色测试颜色bailvse $normal"
# echo "$baiqingse 测试颜色测试颜色测试颜色baiqingse $normal"
# echo "$baihongse 测试颜色测试颜色测试颜色baihongse $normal"
# echo "$baizise 测试颜色测试颜色测试颜色baizise $normal"
# echo "$heibaise 测试颜色测试颜色测试颜色heibaise $normal"
# echo "$heihuangse 测试颜色测试颜色测试颜色heihuangse $normal"
# echo "$jiacu 测试颜色测试颜色测试颜色jiacu $normal"
# echo "$CW 测试颜色测试颜色测试颜色 $normal"
# echo "$JG 测试颜色测试颜色测试颜色 $normal"
# echo "$ZY 测试颜色测试颜色测试颜色 $normal"

if ! which tput >/dev/null 2>&1;then
    _norm="\033[39m"
    _red="\033[31m"
    _green="\033[32m"
    _tan="\033[33m"
    _cyan="\033[36m"
else
    _norm=$(tput sgr0)
    _red=$(tput setaf 1)
    _green=$(tput setaf 2)
    _tan=$(tput setaf 3)
    _cyan=$(tput setaf 6)
fi

_print() {
	printf "${_norm}%s${_norm}\n" "$@"
}
_info() {
	printf "${_cyan}➜ %s${_norm}\n" "$@"
}
_success() {
	printf "${_green}✓ %s${_norm}\n" "$@"
}
_successnoblank() {
	printf "${_green}%s${_norm}\n" "$@"
}
_warning() {
	printf "${_tan}⚠ %s${_norm}\n" "$@"
}
_warningnoblank() {
	printf "${_tan}%s${_norm}\n" "$@"
}
_error() {
	printf "${_red}✗ %s${_norm}\n" "$@"
}
_errornoblank() {
	printf "${_red}%s${_norm}\n" "$@"
}