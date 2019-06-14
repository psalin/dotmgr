#!/bin/bash

set -euo pipefail

# TODO:
#   - dry run option

# This script assumes the use of vim-plug as vim plugin manager, with default
# paths for files i.e. ~/.vim/plugged/

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# dotfiles array keeps the list of dotfiles with the next format:
#   "origin_dotfile destination_of_dotfile"
dotfiles=(
    "${dotfiles_dir}/.bashrc ${HOME}/.bashrc"
    "${dotfiles_dir}/.vimrc ${HOME}/.vimrc"
    "${dotfiles_dir}/.vimrc.plugins ${HOME}/.vimrc.plugins"
    "${dotfiles_dir}/.gitconfig ${HOME}/.gitconfig"
    "${dotfiles_dir}/.dircolors ${HOME}/.dircolors"
    "${dotfiles_dir}/.xfce4-terminal-nord.theme ${HOME}/.local/share/xfce4/terminal/colorschemes/nord.theme"
)

basic_packages=(
    vim
    git
    curl
    shellcheck
    flake8
    build-essential
    cmake
)

# argument-related variables
parameter_dotfiles=false
parameter_basic_packages=false
parameter_vim_plugins=false


function install_dotfiles() {
    local origin_file
    local destination_file
    local date_of_backup
    date_of_backup="$(date +%Y%m%d)"

    echo
    echo "Installing dotfiles as a symlinks:"
    for i in ${!dotfiles[*]}; do
        origin_file=$(echo "${dotfiles[$i]}" | cut -d " " -f1)
        destination_file=$(echo "${dotfiles[$i]}" | cut -d " " -f2)

        if [ ! -f "${origin_file}" ]; then
            echo -e "\t${origin_file} not found. Skipping..."
            continue
        fi

        echo -e "\t${origin_file} -> ${destination_file}"

        # Backup the original file
        if [ -f "${destination_file}" ]; then
            if [ ! -h "${destination_file}" ]; then
                mv "${destination_file}" "${destination_file}_${date_of_backup}.bak"
            else
                rm "${destination_file}"
            fi
        fi

        # Create destination directory if it does not exist
        dir="${destination_file%${destination_file##*/}}"
        if [ ! -d "${dir}" ]; then
            echo "${dir} does not exist!"
            mkdir -p "${dir}"
        fi

        ln -s "${origin_file}" "${destination_file}"
    done

    if [ -x "$(command -v dconf)" ]; then
        echo -e "\tgnome-terminal profiles"
        echo -e "\tCreating backup of current profiles"
        dconf dump /org/gnome/terminal/legacy/profiles:/ > \
            "${HOME}/.gnome-terminal-profile.dconf.bak"
        dconf load /org/gnome/terminal/legacy/profiles:/ < \
            "${dotfiles_dir}/.gnome-terminal-profile.dconf"
    fi
}

function check_and_install_packages() {
    local packages=("$@")
    local packages_to_install=()
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -E "^ii\s\s${package}\s+" &> /dev/null; then
            packages_to_install+=("${package}")
            echo -e "\t${package}: NOT INSTALLED"
        else
            echo -e "\t${package}: OK"
        fi
    done

    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo
        sudo apt-get update
        sudo apt-get install -y "${packages_to_install[@]}"
    fi
}

function show_help() {
    cat <<EOF
Usage: install.sh OPTION1 OPTION2 ...

Install dotfiles for the user.
If no argument is indicated, the script will not perform any action.

List of arguments:
  --dotfiles                dotfiles will be installed
  --basic-packages          a list of basic packages (internally harcoded)
                             will be installed.
  --packages "package ..."  provide a list of packages that will be installed
                             in adition to the basic packages
  --vim-plugins             vim plugin installation
  -h, --help                show this help.
EOF
}

if [ "$#" == 0 ]; then
    show_help
    exit 0
fi

while (( "$#" )); do
    case "$1" in
        --dotfiles)
            parameter_dotfiles=true
            shift
            ;;
        --basic-packages)
            parameter_basic_packages=true
            shift
            ;;
        --packages)
            basic_packages+=($2)
            shift 2
            ;;
        --vim-plugins)
            parameter_vim_plugins=true
            shift
            ;;
        --help | -h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unsupported parameter $1" >&2
            exit 1
            ;;
    esac
done

echo "dotfiles and post-installation script"

if [ "${parameter_dotfiles}" = true ]; then
    echo
    echo "Installing dotfiles..."
    install_dotfiles
fi

if [ "${parameter_basic_packages}" = true ]; then
    echo
    echo "Installing basic packages..."
    check_and_install_packages "${basic_packages[@]}"
fi

if [ "${parameter_vim_plugins}" = true ]; then
    echo
    echo "Installing vim plugins"
    if [ ! -f "${HOME}/.vim/autoload/plug.vim" ]; then
        echo "    vim-plug Plugin Manager: NOT INSTALLED"

        # Download vim-plug Plugin Manager if it is not in the system
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        echo "    vim-plug Plugin Manager: INSTALLED"
    fi

    vim -c 'PlugUpdate' -c 'q!' -c 'q!'
    echo "    Plugins updated"

    # If we have YouCompleteMe plugin in vim, the plugin will be installed
    # automatically, but we still need to compile the core
    if grep -Eq "^\s*Plug .*YouCompleteMe.*$" "${HOME}/.vimrc.plugins"; then
        "${HOME}"/.vim/plugged/YouCompleteMe/install.py
    else
        echo "    YouCompleteMe plugin not found in plugin configuration"
    fi
fi

echo
echo DONE
