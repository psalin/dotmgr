#!/bin/bash

set -euo pipefail

# TODO:
#   - dry run option

# This script assumes the use of vim-plug as vim plugin manager, with default
# paths for files i.e. ~/.vim/plugged/

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# dotfiles array keeps the list of dotfiles with the next format:
#   "origin_dotfile destination_of_dotfile"
dotfiles_list=(
    "${dotfiles_dir}/bashrc ${HOME}/.bashrc"
    "${dotfiles_dir}/vimrc ${HOME}/.vimrc"
    "${dotfiles_dir}/vimrc.plugins ${HOME}/.vimrc.plugins"
    "${dotfiles_dir}/gitconfig ${HOME}/.gitconfig"
    "${dotfiles_dir}/dircolors ${HOME}/.dircolors"
)

gnome_profile="${dotfiles_dir}/gnome-terminal-profile.dconf"
xfce_profile=(
    "${dotfiles_dir}/xfce4-terminal-nord.theme ${HOME}/.local/share/xfce4/terminal/colorschemes/nord.theme"
)
basic_packages_list=(
    curl
    git
)

packages_not_installed=()

# Variables to hold calling options
parameter_dotfiles=false
parameter_basic_packages=false
parameter_packages=false
parameter_vim=false
parameter_xfce_terminal=false
parameter_gnome_terminal=false

# Log output handling from installation script of Nord theme
# https://github.com/arcticicestudio/
_ct_error="\e[0;31m"
_ct_success="\e[0;32m"
_ct_warning="\e[0;33m"
_ct_highlight="\e[0;34m"
_ct_primary="\e[0;36m"
_ct="\e[0;37m"
_ctb_subtle="\e[1;30m"
_ctb_error="\e[1;31m"
_ctb_success="\e[1;32m"
_ctb_warning="\e[1;33m"
_ctb_highlight="\e[1;34m"
_ctb_primary="\e[1;36m"
_ctb="\e[1;37m"
_c_reset="\e[0m"
_ctb_reset="\e[0m"

__cleanup() {
  trap '' SIGINT SIGTERM
  unset -v _ct_error _ct_success _ct_warning _ct_highlight _ct_primary _ct
  unset -v _ctb_error _ctb_success _ctb_warning _ctb_highlight _ctb_primary _ctb _c_reset
  unset -v NORD_XFCE_TERMINAL_SCRIPT_OPTS THEME_FILE VERBOSE LOCAL_INSTALL NORD_XFCE_TERMINAL_VERSION
  unset -f __help __cleanup __log_error __log_success __log_warning __log_info
  unset -f __validate_file __local_install
}

__log_error() {
  printf "${_ctb_error}[ERROR] ${_ct}$1${_c_reset}\n"
}

__log_success() {
  printf "${_ctb_success}[OK] ${_ct}$1${_c_reset}\n"
}

__log_warning() {
  printf "${_ctb_warning}[WARN] ${_ct}$1${_c_reset}\n"
}

__log_info() {
  printf "${_ctb}[INFO] ${_ct}$1${_c_reset}\n"
}

__summary_success() {
  __log_success "Local installation completed"
  __cleanup
  exit 0
}

__summary_error() {
  __log_error "An error occurred during the installation!"
  __log_error "Exit code: $1"
  __cleanup
  exit 1
}

function install_dotfiles() {
    local dotfiles=("$@")
    local origin_file
    local destination_file

    for i in ${!dotfiles[*]}; do
        origin_file=$(echo "${dotfiles[$i]}" | cut -d " " -f1)
        destination_file=$(echo "${dotfiles[$i]}" | cut -d " " -f2)
        filename=$(basename "${origin_file}")

        if [ ! -f "${origin_file}" ]; then
            __log_warning "${filename}: not found. Skipping..."
            continue
        fi

        symlink_file "${origin_file}" "${destination_file}"
    done
}

function symlink_files_in_dirtree() {
    local origin_dir="$1"
    local destination_dir="$2"

    find "${origin_dir}" -type f -print0 | while IFS= read -r -d '' file; do
        symlink_file "${file}" "${destination_dir}${file#${origin_dir}}"
    done
}

function symlink_file() {
    local origin_file="$1"
    local destination_file="$2"
    local date_of_backup
    date_of_backup="$(date +%Y%m%d)"

    dir="${destination_file%${destination_file##*/}}"
    if [ ! -d "${dir}" ]; then
        if ! mkdir -p "${dir}" &> /dev/null; then
            __log_error "${filename}: Cannot create destination directory"
            __summary_error 1
        fi
    fi

    if [ -h "${destination_file}" ]; then
        if ! rm "${destination_file}" &> /dev/null; then
            __log_error "${filename}: Cannot remove the old symlink"
            __summary_error 1
        fi
    elif [ -f "${destination_file}" ]; then
        if ! mv "${destination_file}" "${destination_file}_${date_of_backup}.bak" &> /dev/null; then
            __log_error "${filename}: Cannot create backup from original file"
            __summary_error 1
        fi
    fi

    if ! ln -s "${origin_file}" "${destination_file}" &> /dev/null; then
        __log_error "${filename}: Cannot create symlink"
        __summary_error 1
    fi

    __log_success "${filename}: ${origin_file} -> ${destination_file}"
}

function install_gnome_terminal_profile() {
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

function check_package() {
    local package="$1"
    if ! dpkg -l | grep -E "^ii\s\s${package}\s+" &> /dev/null; then
        return 1
    fi

    return 0
}

function install_packages() {
    local packages=("$@")
    local packages_not_installed=()
    for package in "${packages[@]}"; do
        # Returned values different than 0 from a function will cause the
        # script to stop if "set -e" is used.
        set +e
        check_package "${package}"
        if [ $? -ne 0 ]; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
            continue
        fi
        set -e
        __log_success "${package}: Installed"
    done

    if [ ${#packages_not_installed[@]} -ne 0 ]; then
        echo
        echo "Installing following packages: ${packages_not_installed[@]}"
        sudo apt-get update
        echo
        sudo apt-get install -y "${packages_not_installed[@]}"
        echo
        echo "Checking packages"
        for package in "${packages[@]}"; do
            check_package "${package}"
        done
    fi
}

function install_vim() {
    local packages_not_installed=()
    for package in "${basic_packages_list[@]}"; do
        # Returned values different than 0 from a function will cause the
        # script to stop if "set -e" is used.
        set +e
        check_package "${package}"
        if [ $? -ne 0 ]; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
            continue
        fi
        set -e
    done

    if [ ${#packages_not_installed[@]} -ne 0 ]; then
        __log_warning "VIM 8: Basic packages are not installed. Skipping..."
        __log_warning "       Please use --basic-packages in addition to --vim"
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

function install() {
    if [ "${parameter_dotfiles}" = true ]; then
        echo
        echo "Installing dotfiles as symlinks"
        install_dotfiles "${dotfiles_list[@]}"
    fi

    if [ "${parameter_basic_packages}" = true ]; then
        echo
        echo "Installing basic packages"
        install_packages "${basic_packages_list[@]}"
    fi

    if [ "${parameter_packages}" = true ]; then
        echo
        echo "Installing aditional packages"
        install_packages "${aditional_packages_list[@]}"
    fi

    if [ "${parameter_gnome_terminal}" = true ]; then
        echo
        echo "Installing GNOME-terminal profile"
        install_gnome_terminal_profile
    fi

    if [ "${parameter_xfce_terminal}" = true ]; then
        echo
        echo "Installing xfce4-terminal profile"
        install_dotfiles "${xfce_profile[@]}"
    fi

    if [ "${parameter_vim}" = true ]; then
        echo
        echo "Installing VIM 8 and plugins"
        install_vim
    fi
    echo
}

function show_help() {
    cat <<EOF
Usage: install.sh OPTION1 [OPTION2] ...

Install dotfiles and packages for the user.
If no argument is indicated, the script will not perform any action.

List of arguments:
  --dotfiles                Install the dotfiles
  --vim                     Install VIM 8 and VIM plugins
  --basic-packages          Install basic packages:
                                - curl
                                - git
                                - shellcheck
                                - flake8
                                - build-essential
                                - cmake
  --packages "package ..."  Install a list of packages
  --gnome-terminal          Install the profile for GNOME-terminal
  --xfce-terminal           Install the profile for xfce4-terminal
  -h, --help                Show this help.
EOF
}

#################################################################################
trap "printf '\n${_ctb_error}User aborted.${_ctb_reset}\n' && exit 1" SIGINT SIGTERM

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
        --vim)
            parameter_vim=true
            shift
            ;;
        --basic-packages)
            parameter_basic_packages=true
            shift
            ;;
        --packages)
            parameter_packages=true
            aditional_packages_list+=($2)
            shift 2
            ;;
        --gnome-terminal)
            parameter_gnome_terminal=true
            shift
            ;;
        --xfce-terminal)
            parameter_xfce_terminal=true
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

install
__cleanup
