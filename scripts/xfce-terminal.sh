#!/bin/bash

set -euo pipefail

: "${dotfiles_dir:?}"

function install_xfce_terminal_profile() {
    local xfce_profile
    xfce_profile=(
        "${dotfiles_dir}/xfce4-terminal-nord.theme ${HOME}/.local/share/xfce4/terminal/colorschemes/nord.theme"
    )
    install_dotfiles "${xfce_profile[@]}"
}

echo
echo "Installing xfce4-terminal profile"
install_xfce_terminal_profile
