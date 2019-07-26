#!/bin/bash
#########################################################################
# File Name: make_modem.sh
# Author: Edward.Tang
# mail:   @163.com
# Created Time: Sat 12 Jan 2019 10:10:47 AM CST
#########################################################################

# PROJECT="TK_MD_BASIC(LWTG_TB_8765).mak"

function inf()
{
    echo -e -n "\e[36m"
    echo "[INFO#]: $@"
    echo -e -n "\e[0m"
}

function warn()
{
    echo -e -n "\e[33m"
    echo "[WARN#]: ** $@"
    echo -e -n "\e[0m"
}

function error()
{
    echo
    echo -e -n "\e[31m"
    echo "[ERROR#]: **** $@ ****"
    echo -e -n "\e[0m"
    exit 1
}

unset LUNCH_MENU_CHOICES

function add_lunch_combo()
{
    local new_combo="$*"
    local c
    for c in "${LUNCH_MENU_CHOICES[@]}" ; do
        if [ "$new_combo" = "$c" ] ; then
            return
        fi
    done
    LUNCH_MENU_CHOICES=(${LUNCH_MENU_CHOICES[@]} $new_combo)
}

function print_lunch_menu()
{
    echo
    echo
    echo "Lunch menu... pick a combo:"

    local i=1
    local choice
    for choice in "${LUNCH_MENU_CHOICES[@]}"
    do
        echo "     $i. $choice"
        i=$(($i+1))
    done

    echo
}

function lunch()
{
    local answer

    if [ "$1" ] ; then
        answer=$1
    else
        print_lunch_menu
        echo -n "Which modem would you like: "
        read answer
    fi

    local selection=

    if [ -z "$answer" ]; then
        error "None selection"
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$"); then
        if [ $answer -le ${#LUNCH_MENU_CHOICES[@]} ]; then
            selection=${LUNCH_MENU_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n "${LUNCH_MENU_CHOICES[@]}" | grep -q -e "$answer"); then
        selection=$answer
    fi

    if [ -z "$selection" ]; then
        error "Invalid lunch combo: $answer"
    fi

    # export TARGET_PRODUCT=$selection
    TARGET_PRODUCT="$selection"
    inf TARGET_PRODUCT="$selection"
}

function _lunch()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    COMPREPLY=( $(compgen -W "${LUNCH_MENU_CHOICES[*]}" -- ${cur}) )
    return 0
}

complete -F _lunch lunch

function clean()
{
    inf "Clean up the environment"
    rm -rf mcu/build/ mcu/build_internal/
    rm -rf mcu/temp_modem
    rm -rf mcu/pcore/custom/modem/
    git checkout mcu/pcore/custom/modem/
}

# modem_rename=$(dirname $(readlink -f "$0"))/mcu/tools/modemRenameCopy.pl
function do_make()
{
    local modem_name="$*"

    # 0. Clean up the environment
    clean
    rm -rf Roco/"$TARGET_PRODUCT"/bin

    echo "Begin checkout mcu/pcore/custom/modem/ and Copy it"

    # 1. copy modem config
    if [ -e Roco/"$modem_name"/custom/modem ]; then
        cp Roco/"$modem_name"/custom/modem/* mcu/pcore/custom/modem/ -raf
    else
        cp Roco/"$modem_name"/* mcu/pcore/custom/modem/ -raf
    fi

    # 2. create output directory(bin)
    mkdir -p Roco/"$modem_name"/bin

    # 3. entry mcu and build.
    pushd mcu
    echo $(pwd)
    # ./m "TK_MD_BASIC(LWTG_TB_8765).mak" new -j24
    ./m "$PROJECT" new -j24
    # ./tools/modemRenameCopy.pl . TK_MD_BASIC\(LWTG_TB_8765\)
    ./tools/modemRenameCopy.pl . "${PROJECT%.mak}"
    echo "Done"
    echo $(pwd)
    popd

    # 4. copy bin files
    modem_target=Roco/"$modem_name"/bin/"$modem_name"
    if [ -e "$modem_target" ]; then
        rm -rf "$modem_target"
    fi
    mkdir -p "$modem_target"
    # 4.1 copy APPS library
    cp -raf Roco/APP/rel/* "$modem_target"/
    # 4.2 copy modem binary
    cp mcu/temp_modem/*  "$modem_target"/

    # 5. 还原 mcu/
    clean

    inf "COPY modem to "$modem_target" Done"
}

function find_mak()
{
    local answer

    PROJECT_MENU_CHOICES=()
    MAK=$(cd mcu/make/projects/ && ls *.mak)
    OLDIFS=$IFS
    IFS=$'\n'
    for c in $MAK ; do
        PROJECT_MENU_CHOICES=(${PROJECT_MENU_CHOICES[@]} $c)
    done
    IFS=$OLDIFS

    print_mak_menu

    read -e -p 'Which project would you want to build: ' answer

    if [ -z "$answer" ]; then
        error "Invaild selection"
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$"); then
        if [ $answer -le ${#PROJECT_MENU_CHOICES[@]} ]; then
            PROJECT=${PROJECT_MENU_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n "${PROJECT_MENU_CHOICES[@]}" | grep -q -e "$answer"); then
        PROJECT="$answer"
    fi

    if [ -z "$PROJECT" ]; then
        error "Invalid makefile: $answer. $PROJECT"
    fi

    inf PROJECT="$PROJECT"
}

function print_mak_menu()
{
    echo
    echo
    echo "Project menu... pick a mak:"

    local i=1
    local choice
    for choice in "${PROJECT_MENU_CHOICES[@]}"
    do
        echo "     $i. $choice"
        i=$(($i+1))
    done

    echo
}

function find_modem()
{
    local PRODUCTS=$(cd Roco && ls -d */)
    OLDIFS=$IFS
    IFS=$'\n'
    for c in $PRODUCTS ; do
        c=${c%/}
        add_lunch_combo $c
    done
    IFS=$OLDIFS
}

function check_modem()
{
    local c
    for c in "${LUNCH_MENU_CHOICES[@]}" ; do
        if [ "$@" = "$c" ] ; then
            return 0
        fi
    done
    error "Invalid modem name: $@"
}

function make_all()
{
    local choice
    for choice in "${@}"
    do
        check_modem "$choice"
        do_make $choice
    done
}

function main()
{
    if [ "$1" == "clean" ]; then
        clean
        exit 0
    fi

    find_mak
    find_modem

    if [ "$1" == "all" ]; then
        make_all "${LUNCH_MENU_CHOICES[@]}"
    elif (( $# > 0 )) ; then
        make_all "$@"
    else
        lunch
        do_make "$TARGET_PRODUCT"
    fi
}

main $@
