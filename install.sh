#!/bin/bash

# TODO:
#   - dry run option

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# dotfiles array keeps the list of dotfiles with the next format:
#   "origin_dotfile destination_of_dotfile"
# The file will not be copied if it does not exist.
dotfiles=(
    "${dotfiles_dir}/.bashrc ${HOME}/.bashrc"
    "${dotfiles_dir}/.vimrc ${HOME}/.vimrc"
)
basic_packages=(
    git
    curl
    shellcheck
    flake8
    build-essential
    cmake
    python2.7-dev
)

# argument-related variables
install_with_parameters=false
parameter_basic_packages=false
parameter_no_source=false


function install_dotfiles() {
    local origin_file
    local destination_file
    local date_of_backup
    date_of_backup="$(date +%Y%m%d)"

    echo
    echo "Installing dotfiles:"
    for i in ${!dotfiles[*]}; do
        origin_file=$(echo "${dotfiles[$i]}" | cut -d " " -f1)
        destination_file=$(echo "${dotfiles[$i]}" | cut -d " " -f2)

        if [ ! -f "${origin_file}" ]; then
            echo -e "\t${origin_file} not found. Skipping..."
            continue
        fi

        echo -e "\t${origin_file} -> ${destination_file}"

        if [ -f "${destination_file}" ]; then
            if [ ! -h "${destination_file}" ]; then
                mv "${destination_file}" "${destination_file}_${date_of_backup}.bak"
            else
                rm "${destination_file}"
            fi
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
        if ! dpkg -l | grep ^ii | awk '{print $2}' | grep -Eq "^${package}$"; then
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
Usage: install.sh [OPTION]

Install dotfiles for the user.
If no argument is indicated, the script will perform only the copy
of the dotfiles.

List of arguments:
  --basic-packages          a list of basic packages (internally harcoded)
                             will be installed.
  --packages "package ..."  provide a list of packages that will be installed
                             in adition to the basic packages
  --no-source               do not source .bashrc file after the installation.
  -h, --help                show this help.
EOF
}


if [ ${#} -ne 0 ]; then
    install_with_parameters=true
fi

while (( "$#" )); do
    case "$1" in
        --basic-packages)
            parameter_basic_packages=true
            shift
            ;;
        --packages)
            basic_packages+=($2)
            shift 2
            ;;
        --no-source)
            parameter_no_source=true
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

install_dotfiles

if [ ${install_with_parameters} = true ]; then
    if [ "${parameter_basic_packages}" = true ]; then
        echo
        echo "Installing basic packages..."
        check_and_install_packages "${basic_packages[@]}"
    fi
fi

if [ "${parameter_no_source}" = false ]; then
    bashrc_file=$(echo "${dotfiles[@]}" | grep "bashrc" | cut -d " " -f2)
    echo
    echo Sourcing new .bashrc...
    source ${bashrc_file}
fi
echo
echo DONE
