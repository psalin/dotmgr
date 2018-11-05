#!/bin/bash

# TODO:
#   - dry run option
#   - help

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
dotfiles=(
    "${dotfiles_dir}/.bashrc ${HOME}/.bashrc"
    "${dotfiles_dir}/.vimrc ${HOME}/.vimrc"
)
packages=()
packages_to_install=()

install_with_parameters=false
parameter_dotfile=false
parameter_basic_packages=false
parameter_vim_markdown=false
update_package_index=true

if [ ${#} -ne 0 ]; then
    install_with_parameters=true
fi

while (( "$#" )); do
    case "$1" in
        --dotfiles)
            parameter_dotfile=true
            shift
            ;;
        --basic-packages)
            parameter_basic_packages=true
            shift
            ;;
        --vim-markdown)
            parameter_vim_markdown=true
            shift
            ;;
        --help)
            echo "TODO: show help"
            exit 0
            ;;
        *)
            echo "Error: Unsupported parameter $1" >&2
            exit 1
            ;;
    esac
done

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

    echo -e "\tgnome-terminal profiles"
    dconf load /org/gnome/terminal/legacy/profiles:/ < \
        "${dotfiles_dir}/.gnome-terminal-profile.dconf"
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
        if [ "${update_package_index}" = true ]; then
            update_package_index=false
            sudo apt-get update
        fi
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


echo "dotfiles and post-installation script"

if [ ${install_with_parameters} = true ]; then
    if [ "${parameter_dotfile}" = true ]; then
        install_dotfiles
    fi

    if [ "${parameter_basic_packages}" = true ]; then
        install_basic_packages
    fi

    if [ "${parameter_vim_markdown}" = true ]; then
        install_vim_markdown
    fi
else
    install_dotfiles
    install_basic_packages
    install_vim_markdown
fi
