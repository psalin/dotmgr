#!/bin/bash
#
# Tool for managing dotfile installation and environment setup

# Don't allow sourcing this script
(return 0 2>/dev/null) && echo "ERROR: ${BASH_SOURCE[0]##*/} must not be sourced!" >&2 && return 1

set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
readonly basedir

# Configuration file parameter defaults, see dotfiles.conf.example for descriptions
dotfiles_dir="${basedir}/../dotfiles"
dotfiles_list=()
script_dir="${basedir}/../scripts"
log_file="${basedir}/../log/dotmgr.log"
script_help_cmd="${script_dir}/help.sh"

# Variables to hold calling options
parameter_conffile="${basedir}/../dotfiles.conf" # Set to empty to disable file and use inline conf
parameter_help=false
parameter_dotfiles=false
parameter_dry_run=false
parameter_packages=()
parameter_scripts=()

# Log output handling originally from installation script of Nord theme
# https://github.com/arcticicestudio/
readonly _ct="\e[0;37m"
readonly _ctb_error="\e[1;31m"
readonly _ctb_success="\e[1;32m"
readonly _ctb_warning="\e[1;33m"
readonly _ctb="\e[1;37m"
readonly _c_reset="\e[0m"

__log_error() {
    printf "%b" "${_ctb_error}[ERROR] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}" >&2
}

__log_success() {
    printf "%b" "${_ctb_success}[OK] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}"
}

__log_warning() {
    printf "%b" "${_ctb_warning}[WARN] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}"
}

__log_info() {
    printf "%b" "${_ctb}[INFO] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}"
}

__summary_success() {
    __log_success "Local installation completed"
    exit 0
}

__summary_error() {
    __log_error "An error occurred during the installation!"
    __log_error "Log file: ${log_file}"
    __log_error "Exit code: $1"
    exit 1
}

function create_log_file() {
    mkdir -p "${log_file%/*}"
    : > "${log_file}"
}

function run_cmd() {
    if [[ "${parameter_dry_run}" == true ]]; then
        __log_info "DRY RUN: $*"
    else
        "$@" &>> "${log_file}"
    fi
}

function install_dotfiles() {
    local -r dotfiles=("$@")
    local origin_file
    local destination_file
    local filename

    for dotfile in "${dotfiles[@]}"; do
        origin_file="$(realpath -sm "$(echo "${dotfile}" | cut -d " " -f1)")"
        destination_file="$(realpath -sm "$(echo "${dotfile}" | cut -d " " -f2)")"
        filename="$(basename "${origin_file}")"

        if [[ -f "${origin_file}" ]]; then
            symlink_file "${origin_file}" "${destination_file}"

        elif [[ -d "${origin_file}" ]]; then
            symlink_files_in_dirtree "${origin_file}" "${destination_file}"

        else
            __log_warning "${filename}: not found."

        fi
    done
}

function symlink_files_in_dirtree() {
    local -r origin_dir="$1"
    local -r destination_dir="$2"

    while IFS= read -r -d '' file; do
        symlink_file "${file}" "${destination_dir}${file#${origin_dir}}"
    done < <(find "${origin_dir}" -type f -print0)
}

function symlink_file() {
    local -r origin_file="$1"
    local -r destination_file="$2"
    local dir="${destination_file%${destination_file##*/}}"
    local date_of_backup
    local filename
    date_of_backup="$(date +%Y%m%d)"
    filename="$(basename "${origin_file}")"
    readonly date_of_backup
    readonly filename

    if [[ ! -d "${dir}" ]]; then
        if ! run_cmd mkdir -p "${dir}"; then
            __log_error "${filename}: Cannot create destination directory"
            __summary_error 1
        fi
    fi

    if [[ -h "${destination_file}" ]]; then
        if ! run_cmd rm "${destination_file}"; then
            __log_error "${filename}: Cannot remove the old symlink"
            __summary_error 1
        fi
    elif [[ -f "${destination_file}" ]]; then
        if ! run_cmd mv "${destination_file}" "${destination_file}_${date_of_backup}.bak"; then
            __log_error "${filename}: Cannot create backup from original file"
            __summary_error 1
        fi
    fi

    if ! run_cmd ln -s "${origin_file}" "${destination_file}"; then
        __log_error "${filename}: Cannot create symlink"
        __summary_error 1
    fi

    __log_success "${filename}: ${origin_file} -> ${destination_file}"
}

function check_package() {
    local -r package="$1"
    if ! dpkg-query -W --showformat='${Status}\n' "${package}" 2>/dev/null \
            | grep -q "install ok installed"; then
        return 1
    fi

    return 0
}

function install_packages() {
    local -r packages=("$@")
    local packages_not_installed=()

    for package in "${packages[@]}"; do
        if ! check_package "${package}"; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
        else
            __log_info "${package}: Already installed"
        fi
    done

    if [[ ${#packages_not_installed[@]} -ne 0 ]]; then
        if ! run_cmd sudo -v; then
            __log_warning "Could not install packages, no sudo rights"
            return 1
        fi
    else
        __log_success "All packages are already installed"
        return 0
    fi

    __log_info "Installing packages: ${packages_not_installed[*]}"
    run_cmd sudo apt-get update
    if ! run_cmd sudo apt-get install -y "${packages_not_installed[@]}"; then
        for package in "${packages[@]}"; do
            if ! check_package "${package}"; then
                __log_error "${package}: not installed"
            fi
        done
        return 1
    fi

    __log_success "Packages successfully installed"
    return 0
}

function read_conffile() {
    local -r conffile="$1"

    if [[ ! -f "${conffile}" ]]; then
        __log_error "Configuration file not found: ${conffile}"
        __summary_error 1
    fi

    # shellcheck source=/dev/null
    source "${conffile}"
    cd "$(dirname "${conffile}")" # set the working dir to the dir of the conffile
    create_log_file               # the log file location is in the conffile
    __log_success "Found configuration file: ${conffile}\n"
}

function run_scripts() {
    local -r scripts=("$@")

    for script in "${scripts[@]}"; do
        if ! run_script "${script}"; then
            __summary_error 1
        fi
    done
}

function run_script() {
    local -r script="$1"
    local script_path

    if ! script_path="$(realpath -e "${script_dir}/${script}" 2> /dev/null)"; then
        if ! script_path="$(realpath -e "${script_dir}/${script}.sh" 2> /dev/null)"; then
            __log_warning "${script_dir}/${script}: Script does not exist"
            return 1
        fi
    fi

    if [[ "${parameter_dry_run}" == true ]]; then
        __log_info "DRY RUN: Not executing script: ${script}"
        return 0
    fi

    pushd "$PWD" > /dev/null

    __log_info "Running script: ${script}"
    # shellcheck source=/dev/null
    if source "${script_path}"; then
        __log_success "Script executed: ${script}\n"
        popd > /dev/null  # Make sure we are always at the original dir after script execution
        return 0
    else
        __log_error "Script executed with errors: ${script}\n"
        popd > /dev/null  # Make sure we are always at the original dir after script execution
        return 1
    fi
}

function install_main() {
    if [[ -n "${parameter_conffile}" ]]; then
        read_conffile "${parameter_conffile}"
    fi

    # Prevent conf param changes after initialization
    # shellcheck disable=SC2034
    readonly dotfiles_dir     # Disable unused warning because scripts might use this
    readonly dotfiles_list
    readonly script_dir
    readonly log_file
    readonly script_help_cmd

    if [[ "${parameter_help}" == true \
              || ("${parameter_dotfiles}" == false \
                      && ${#parameter_packages[@]} -eq 0 \
                      && ${#parameter_scripts[@]} -eq 0) ]]; then
        show_help
        exit 0
    fi
    if [[ "${parameter_dotfiles}" == true ]]; then
        __log_info "Installing dotfiles as symlinks"
        install_dotfiles "${dotfiles_list[@]}"
        __log_success "Finished installing dotfiles\n"
    fi

    if [[ ${#parameter_packages[@]} -ne 0 ]]; then
        __log_info "Installing packages"
        install_packages "${parameter_packages[@]}" || __summary_error 1
        __log_success "Finished installing packages\n"
    fi

    if [[ ${#parameter_scripts[@]} -ne 0 ]]; then
        __log_info "Running scripts"
        run_scripts "${parameter_scripts[@]}"
        __log_success "Finished running scripts\n"
    fi
}

function show_help() {
    cat <<EOF
Usage: dotmgr.sh OPTION1 [OPTION2] ...

Install dotfiles and packages for the user.
If no argument is indicated, the script will not perform any action.

List of arguments:
  -c, --conffile conffile   Path to the configuration file to use
  -d, --dotfiles            Install the dotfiles
      --dry-run             Simulation only, don't run any commands or scripts
  -P, --packages PKG        Install a package
  -s, --script SCRIPTNAME   Execute script SCRIPTNAME
  -h, --help                Show this help.
EOF

    if [[ -f "${script_help_cmd}" ]]; then
        bash "${script_help_cmd}"
    fi
}

function parse_arguments() {
    if [[ "$#" -eq 0 ]]; then
        show_help
        exit 0
    fi

    while (( "$#" )); do
        case "$1" in
            --conffile | -c)
                parameter_conffile="$2"
                shift 2
                ;;
            --dotfiles | -d)
                parameter_dotfiles=true
                shift
                ;;
            --dry-run)
                parameter_dry_run=true
                shift
                ;;
            --packages | -P)
                parameter_packages+=("$2")
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
                __log_error "Unsupported parameter $1"
                exit 1
                ;;
        esac
    done

    readonly parameter_conffile
    readonly parameter_help
    readonly parameter_dotfiles
    readonly parameter_dry_run
    readonly parameter_packages
    readonly parameter_scripts
}

function main() {
    parse_arguments "$@"
    install_main
}

#################################################################################
trap '__log_error "User aborted." && exit 1' SIGINT SIGTERM

main "$@"
