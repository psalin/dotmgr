#!/bin/bash

echo "Installing dotfiles and packages..."
echo

DOTFILES_DIR="${HOME}/.dotfiles"
packages=()
packages_to_install=()


function install_dotfiles() {
    local date_of_backup
    date_of_backup="$(date +%Y%m%d)"
    if [ -f "${HOME}/.bashrc" ]; then
        mv "${HOME}/.bashrc" "${HOME}/.bashrc_${date_of_backup}.bak"
    fi
    ln -s "${DOTFILES_DIR}/.bashrc" "${HOME}/.bashrc"

    if [ -f "${HOME}/.vimrc" ]; then
        mv "${HOME}/.vimrc" "${HOME}/.vimrc_${date_of_backup}.bak"
    fi
    ln -s "${DOTFILES_DIR}/.vimrc" "${HOME}/.vimrc"

    dconf load /org/gnome/terminal/legacy/profiles:/ < \
        "${DOTFILES_DIR}/.gnome-terminal-profile.dconf"
}

function check_and_install_packages() {
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep ^ii | awk '{print $2}' | grep -Eq "^${package}$"; then
            packages_to_install+=(${package})
            echo "${package} is not installed"
        else
            echo "${package} is installed"
        fi
    done

    if [ ${#packages_to_install[@]} -ne 0 ]; then
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

    check_and_install_packages
}

function install_vim_markdown() {
    packages=(
        nodejs
        npm
        xdg-utils
        curl
    )

   check_and_install_packages
   sudo npm -g install instant-markdown-d
}


install_dotfiles
install_basic_packages
install_vim_markdown
