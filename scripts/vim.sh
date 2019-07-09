#!/bin/bash

set -euo pipefail

: "${basic_packages_list:?}"

# This script assumes the use of vim-plug as vim plugin manager, with default
# paths for files i.e. ~/.vim/plugged/

function install_vim() {
    local packages_not_installed=()
    for package in "${basic_packages_list[@]}"; do
        if ! check_package "${package}"; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
            continue
        fi
    done

    if [ ${#packages_not_installed[@]} -ne 0 ]; then
        __log_warning "VIM 8: Basic packages are not installed. Skipping..."
        __log_warning "       Please use --basic-packages in addition to -s vim"
        return
    fi

    if ! vim --version | head -n1 | grep -E "^.*IMproved 8.*" &> /dev/null; then
        __log_info "VIM 8: Not installed"
        echo
        echo "Downloading and compiling VIM 8"
        build_directory="${HOME}/buildvim8"
        git clone https://github.com/vim/vim "${build_directory}"
        cd "${build_directory}"
        ./configure --prefix="${HOME}/.local/"
        make install
    fi
    __log_success "VIM 8: Installed"

    if [ ! -f "${HOME}/.vim/autoload/plug.vim" ]; then
        __log_info "vim-plug: Not installed"
        echo
        echo "Downloading vim-plug"
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    __log_success "vim-plug: Installed"

    vim -c 'PlugUpdate' -c 'q!' -c 'q!'
    __log_success "vim-plug: Plugins updated"

    # If we have YouCompleteMe plugin in vim, the plugin will be installed
    # automatically, but we still need to compile the core
    if grep -Eq "^\s*Plug .*YouCompleteMe.*$" "${HOME}/.vimrc.plugins"; then
        "${HOME}"/.vim/plugged/YouCompleteMe/install.py
        __log_success "YouCompleteMe: Plugin installed and core compiled"
    else
        __log_info "YouCompleteMe: plugin not activated in the configuration. Skipping..."
    fi
}

echo
echo "Installing VIM 8 and plugins"
install_vim
