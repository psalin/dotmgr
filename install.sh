#!/bin/bash

# TODO:
#   - dry run option

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# dotfiles array keeps the list of dotfiles with the next format:
#   "origin_dotfile destionation_of_dotfile"
dotfiles=(
    "${dotfiles_dir}/.bashrc ${HOME}/.bashrc"
    "${dotfiles_dir}/.vimrc ${HOME}/.vimrc"
)
packages=()
packages_to_install=()

# argument-related variables
install_with_parameters=false
parameter_basic_packages=false
parameter_vim_markdown=false
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

        echo -e "\t${destination_file}"

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
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep ^ii | awk '{print $2}' | grep -Eq "^${package}$"; then
            packages_to_install+=(${package})
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

function install_basic_packages() {
    packages=(
        git
        curl
        shellcheck
        flake8
    )

    echo
    echo "Installing basic packages..."
    check_and_install_packages
}

function install_vim_markdown() {
    packages=(
        nodejs
        npm
        xdg-utils
        curl
    )

    echo
    echo "Installing vim plugin dependencies..."
    check_and_install_packages
    sudo npm -g install instant-markdown-d
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
  --vim-markdown            vim-markdown plugin will be installed in vim.
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
        --vim-markdown)
            parameter_vim_markdown=true
            shift
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
        install_basic_packages
    fi

    if [ "${parameter_vim_markdown}" = true ]; then
        install_vim_markdown
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
