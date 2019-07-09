#!/bin/bash

set -euo pipefail

: "${dotfiles_dir:?}"

function install_gnome_terminal_profile() {
    local gnome_profile
    gnome_profile="${dotfiles_dir}/gnome-terminal-profile.dconf"
    local filename
    filename=$(basename "${gnome_profile}")

    if [ ! -f "${gnome_profile}" ]; then
        __log_warning "${filename}: not found. Skipping..."
        return
    fi

    __log_warning "dconf utility not found. Skipping..."
    return

    # Create backup of the current profile
    if ! dconf dump /org/gnome/terminal/legacy/profiles:/ > \
        "${HOME}/.gnome-terminal-profile.dconf.bak" &> /dev/null; then
        __log_error "${filename}: Cannot backup current profile"
        __summary_error 1
    fi

    # Load the new configuration
    if ! dconf load /org/gnome/terminal/legacy/profiles:/ < \
        "${dotfiles_dir}/gnome-terminal-profile.dconf" &> /dev/null; then
        __log_error "${filename}: Cannot load profile"
        __summary_error 1
    fi
}

echo
echo "Installing GNOME-terminal profile"
install_gnome_terminal_profile
