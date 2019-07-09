#!/bin/bash

set -euo pipefail

# TODO:
#   - dry run option


basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# Disable unused warning because scripts might use this
# shellcheck disable=SC2034
dotfiles_dir="${basedir}/../dotfiles"
script_dir="${basedir}/../scripts"
script_help_cmd="${script_dir}/help.sh"

# dotfiles_list keeps the list of dotfiles with the next format:
#   "origin_dotfile destination_of_dotfile"
#
# - if the origin_dotfile is a file, it is symlinked from the destination.
# - if the origin_dotfile is a directory, all files under it are symlinked
#   from the same directory structure under the destination directory
dotfiles_list=(
)

# basic_packages_list defines the packages to be installed when
# the --basic-packages option is given
basic_packages_list=(
)

packages_not_installed=()

# Variables to hold calling options
parameter_conffile="${basedir}/../dotfiles.conf" # Set default to empty to disable the conffile and conf inline in this script
parameter_help=false
parameter_dotfiles=false
parameter_basic_packages=false
parameter_packages=false
parameter_scripts=()

# Log output handling from installation script of Nord theme
# https://github.com/arcticicestudio/

# Not yet used, commented to prevent shellcheck warnings, uncomment when needed
#_ct_error="\e[0;31m"
#_ct_success="\e[0;32m"
#_ct_warning="\e[0;33m"
#_ct_highlight="\e[0;34m"
#_ct_primary="\e[0;36m"
#_ctb_subtle="\e[1;30m"
#_ctb_highlight="\e[1;34m"
#_ctb_primary="\e[1;36m"

_ct="\e[0;37m"
_ctb_error="\e[1;31m"
_ctb_success="\e[1;32m"
_ctb_warning="\e[1;33m"
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
  printf "%b" "${_ctb_error}[ERROR] ${_ct}$1${_c_reset}\n"
}

__log_success() {
  printf "%b" "${_ctb_success}[OK] ${_ct}$1${_c_reset}\n"
}

__log_warning() {
  printf "%b" "${_ctb_warning}[WARN] ${_ct}$1${_c_reset}\n"
}

__log_info() {
  printf "%b" "${_ctb}[INFO] ${_ct}$1${_c_reset}\n"
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
    local filename

    for i in ${!dotfiles[*]}; do
        origin_file=$(realpath -sm "$(echo "${dotfiles[$i]}" | cut -d " " -f1)")
        destination_file=$(realpath -sm "$(echo "${dotfiles[$i]}" | cut -d " " -f2)")
        filename=$(basename "${origin_file}")

        if [ -f "${origin_file}" ]; then
            symlink_file "${origin_file}" "${destination_file}"

        elif [ -d "${origin_file}" ]; then
            symlink_files_in_dirtree "${origin_file}" "${destination_file}"

        else
            __log_warning "${filename}: not found."

        fi
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
    local filename
    filename=$(basename "${origin_file}")

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

function check_package() {
    local package="$1"
    if ! dpkg-query -W --showformat='${Status}\n' "${package}" | grep -q "install ok installed"; then
        return 1
    fi

    return 0
}

function install_packages() {
    local packages=("$@")
    local packages_not_installed=()
    for package in "${packages[@]}"; do
        if ! check_package "${package}"; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
            continue
        fi
        __log_success "${package}: Installed"
    done

    if [ ${#packages_not_installed[@]} -ne 0 ]; then
        echo
        echo "Installing following packages: ${packages_not_installed[*]}"
        sudo apt-get update
        echo
        sudo apt-get install -y "${packages_not_installed[@]}"
        echo
        echo "Checking packages"
        for package in "${packages[@]}"; do
            if ! check_package "${package}"; then
                __log_error "${package}: not installed"
                __summary_error 1
            fi
        done
    fi
}

function read_conffile() {
    local conffile="$1"

    if [ ! -f "${conffile}" ]; then
        __log_error "Configuration file not found: ${conffile}"
        __summary_error 1
    fi

    # shellcheck source=/dev/null
    source "${conffile}"
    cd "$(dirname "${conffile}")" # set the working dir to the dir of the conffile
    __log_success "Found configuration file: ${conffile}"
}

function run_scripts() {
    local scripts=("$@")
    local script_path

    for script in "${scripts[@]}"; do
        if ! script_path=$(realpath -e "${script_dir}/${script}" 2> /dev/null); then
            if ! script_path=$(realpath -e "${script_dir}/${script}.sh" 2> /dev/null); then
                __log_warning "${script_dir}/${script}: Script does not exist"
                continue
            fi
        fi
        # shellcheck source=/dev/null
        source "${script_path}"
        __log_success "${script}: Script was executed"
    done
}

function install_main() {
    if [ -n "${parameter_conffile}" ]; then
        read_conffile "${parameter_conffile}"
    fi

    if [ "${parameter_help}" = true ]; then
        show_help
        exit 0
    fi
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

    if [ ${#parameter_scripts[@]} -ne 0 ]; then
        echo
        echo "Running scripts"
        run_scripts "${parameter_scripts[@]}"
    fi

    echo
}

function show_help() {
    cat <<EOF
Usage: install.sh OPTION1 [OPTION2] ...

Install dotfiles and packages for the user.
If no argument is indicated, the script will not perform any action.

List of arguments:
  --conffile conffile       Path to the configuration file to use
  --dotfiles                Install the dotfiles
  --basic-packages          Install basic packages:
                                - curl
                                - git
                                - shellcheck
                                - flake8
                                - build-essential
                                - cmake
  --packages "package ..."  Install a list of packages
  -s, --script SCRIPTNAME   Executes script SCRIPTNAME
  -h, --help                Show this help.
EOF

    if [ -f "${script_help_cmd}" ]; then
        bash "${script_help_cmd}"
    fi
}

#################################################################################
trap 'printf "\n${_ctb_error}User aborted.${_ctb_reset}\n" && exit 1' SIGINT SIGTERM

if [ "$#" == 0 ]; then
    show_help
    exit 0
fi

while (( "$#" )); do
    case "$1" in
        --conffile)
            parameter_conffile="$2"
            shift 2
            ;;
        --dotfiles)
            parameter_dotfiles=true
            shift
            ;;
        --basic-packages)
            parameter_basic_packages=true
            shift
            ;;
        --packages)
            parameter_packages=true
            aditional_packages_list+=("$2")
            shift 2
            ;;
        --script | -s)
            parameter_scripts+=("$2")
            shift 2
            ;;
        --help | -h)
            parameter_help=true
            shift
            ;;
        *)
            echo "Error: Unsupported parameter $1" >&2
            exit 1
            ;;
    esac
done

install_main
__cleanup
