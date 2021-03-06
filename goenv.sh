#!/bin/bash


# 
# 为 Golang 创建隔离的工作空间，包括创建独立目录，设置 GOPATH 环境变量。
# 参考 virtualenvwrapper、github/goenv 等项目源码。
# 
# 更新: https://github.com/qyuhen
# 
# 使用: 
#
#   1. 下载本文件，可保存到任意目录。
#   2. 在启动文件中添加工作空间根目录环境变量，并启动本脚本文件。
#      $ vim .bashrc
#      export GOHOME=$HOME/go.workspaces
#      source goenv.sh
#   3. 输入 goe 显示帮助信息。
# 

GOHOME=${GOHOME:-"$HOME/go"}

function goe() {
    cmd=$1

    case $cmd in 
        # --- A. 名称相关命令 --------------------------------------------------- #
        mk|rm|on|bak)
            # 检查名称是否为空，输出帮助信息。
            if [ -z $2 ]; then
                goe
                return 1
            fi

            name=$2
            dir="$GOHOME/$name"
            dep="$GOHOME/.deps/$name"

            case $cmd in
                mk)
                    # 检查目标目录是否已存在。
                    if [ -d $dir ]; then
                        echo "Error: environment '$name' has exists!"
                        return 2
                    fi

                    # 创建目录结构。
                    subnames=("src" "pkg" "bin")
                    for sub in ${subnames[@]}
                    do
                        mkdir -p "$dir/$sub" "$dep/$sub"
                    done
                    ;;
                rm)
                    # 如果目标已激活，则放弃。
                    if [ "$GOENV" = "$name" ]; then
                        echo "Error: environment '$name' must be deactivated!"
                        return 2
                    fi

                    # 检查目标是否存在。
                    if [ ! -d $dir ]; then
                        echo "Error: environment '$name' not exists!"
                        return 2
                    fi

                    # 删除目标目录。
                    read -r -p "Are you sure? [y/N]" x
                    if [[ $x =~ ^([yY][eE][sS]|[yY])$ ]]; then
                        echo "delete $dir ..."
                        echo "delete $dep ..."
                        rm -rf "$dir" "$dep"
                    fi
                    ;;
                on)
                    # 检查是否已经激活某目标。
                    if [ "$GOENV" ]; then
                        goe off
                        goe on $name
                        return
                    fi

                    # 检查目标是否已存在。
                    if [ ! -d $dir ]; then
                        echo "Error: environment '$name' not exists!"
                        return 2
                    fi

                    # 保存原设置。
                    export GOOLD_GOPATH=$GOPATH
                    export GOOLD_PATH=$PATH    
                    export GOOLD_PS1=$PS1

                    # 导出新设置。
                    export GOENV="$name"
                    export GOPATH="$dep:$dir:$GOPATH"
                    export PATH="$dep/bin:$dir/bin:$PATH"
                    export PS1="(go.$name)$PS1"    

                    # 切换目录。
                    goe cd
                    ;;
                bak)
                    # 检查目标是否存在。
                    if [ ! -d $dir ]; then
                        echo "Error: environment '$name' not exists!"
                        return 2
                    fi

                    tar czf "$GOHOME/$name.tar.gz" -C "$GOHOME" \
                        --exclude ".git" --exclude ".DS_Store" --exclude "bin/" --exclude "pkg/" \
                        "$name" ".deps/$name" 
                    ;;
            esac
            ;;

        # --- B. 状态相关命令 --------------------------------------------------- #
        off|cd|cde|deps|inst|wipe|gets)
            # 检查是否已处于激活状态。
            if [ ! $GOENV ]; then
                echo "Error: no environment activated!"
                return 1
            fi

            src="$GOHOME/$GOENV/src"
            dep="$GOHOME/.deps/$GOENV"

            case $cmd in
                off)
                    # 恢复原设置。
                    export GOPATH=$GOOLD_GOPATH
                    export PATH=$GOOLD_PATH
                    export PS1=$GOOLD_PS1

                    # 取消新导出变量。
                    unset GOENV GOOLD_GOPATH GOOLD_PATH GOOLD_PS1

                    cd "$GOHOME"
                    ;;
                cd)
                    # 切换到源码目录。
                    cd "$src"
                    ;;
                cde)
                    # 切换到依赖包目录。
                    cd "$dep"
                    ;;
                deps)
                    # 显示所有第三方依赖包。
                    IFS=' ' read -a array <<< `go list -f {{.Deps}}`
                    for s in "${array[@]}" 
                    do
                        if [[ $s = *\.*\/* ]]; then  # 包含 "./" 字符。
                            echo ${s//[\[\]]/}       # 移除括号字符。
                        fi
                    done
                    ;;
                inst)
                    # 安装依赖包。
                    go clean
                    goe deps | xargs go get -v -u
                    ;;
                wipe)
                    # 删除所有依赖包文件。
                    subnames=("src" "pkg" "bin")
                    for sub in ${subnames[@]}
                    do
                        p="$dep/$sub"
                        if [ -d "$p" ]; then
                            echo "Remove $p ..."
                            rm -rf "$p"
                        fi
                    done

                    goe cd
                    ;;
                gets)
                    # 显示所有安装的第三方包。
                    tree -d -L 3 "$dep/src"
                    ;;
            esac
            ;;

        # --- C. 无参数命令 --------------------------------------------------- #
        list|home)
            case $cmd in
                list)
                    # 显示所有目标。
                    ls "$GOHOME"
                    ;;
                home)
                    cd "$GOHOME"
                    ;;
            esac
            ;;

        # --- D. 使用帮助 ----------------------------------------------------- #
        *)
            echo "Virtual Isolated Environment for Golang."
            echo ""
            echo "Usage:"
            echo "  goe <command> [arg]"
            echo ""
            echo "Command:"
            echo "  mk <name>  : create workspace directory."
            echo "  rm <name>  : remove workspace directory."
            echo "  on <name>  : activate workspace."
            echo "  off        : deactivate workspace."
            echo "  list       : list all workspaces."
            echo "  gets       : list installed 3rd-party directory."
            echo "  deps       : list imported 3rd-party packages."
            echo "  inst       : install imported 3rd-party packages."
            echo "  cd         : goto source directory."
            echo "  cde        : goto 3rd-party packages source directory."
            echo "  home       : goto \$GOHOME directory."
            echo "  wipe       : wipe all 3rd-party packages."
            echo "  bak <name> : backup workspace to \$GOHOME."
            echo ""
            echo "Q.yuhen, 2014. https://github.com/qyuhen"
            echo ""
            ;;
    esac
}

# 命令参数自动完成。
_goe_complete() {
    cur=${COMP_WORDS[COMP_CWORD]}
    case $COMP_CWORD in
        1)
            # 补全第一命令参数。
            use="mk rm on off list gets deps inst cd cde home wipe bak"
            ;;
        2)
            # 补全第二名称参数。
            use=`goe list` # 所有空间名称。
            ;;
    esac

    COMPREPLY=( $( compgen -W "$use" -- $cur ) )
}

complete -o default -o nospace -F _goe_complete goe
