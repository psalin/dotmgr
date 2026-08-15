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
parameter_script_args=()

# Distro in use, set on first detection, cached for the rest of the execution
dotmgr_distro_family=""

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
    printf "%b" "${_ctb_success}[OK] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}" >&2
}

__log_warning() {
    printf "%b" "${_ctb_warning}[WARN] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}" >&2
}

__log_info() {
    printf "%b" "${_ctb}[INFO] ${_ct}$1${_c_reset}\n" | tee -a "${log_file}" >&2
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

function run_cmd() {
    if [[ "${parameter_dry_run}" == true ]]; then
        __log_info "DRY RUN: $*"
    else
        "$@" &>> "${log_file}"
    fi
}

# The effective UID used for privilege decisions.
# Overridable by DOTMGR_FORCE_EUID for test purposes.
function __current_euid() {
    printf '%s' "${DOTMGR_FORCE_EUID:-${EUID}}"
}

# Returns 0 if sudo passes, 1 otherwise
function __sudo_available() {
    # Overridable for testing purposes
    if [[ -n "${DOTMGR_FORCE_SUDO:-}" ]]; then
        if [[ "${DOTMGR_FORCE_SUDO}" == "1" ]]; then
            return 0
        fi
        return 1
    fi

    command -v sudo > /dev/null 2>&1 || return 1

    if sudo -n true > /dev/null 2>&1; then
        return 0
    fi

    # Only try sudo if we have a controlling terminal where we can enter the
    # password. The above sudo -n already takes care of the ones where we don't
    # need to enter one.
    if { : < /dev/tty; } 2>/dev/null; then
        sudo -v > /dev/null 2>&1
        return
    fi

    return 1
}

# Runs a command directly as root, otherwise using sudo.
function run_privileged() {
    if [[ "$(__current_euid)" -eq 0 ]]; then
        run_cmd "$@"
    elif __sudo_available; then
        run_cmd sudo "$@"
    else
        __log_warning "Couldn't run privileged, no sudo rights"
        return 1
    fi
}

# Checks whether privileged operations can proceed
function __have_privileges() {
    [[ "$(__current_euid)" -eq 0 ]] || __sudo_available
}

function read_conffile() {
    local -r conffile="$1"

    if [[ ! -f "${conffile}" ]]; then
        __log_error "Configuration file not found: ${conffile}"
        __summary_error 1
    fi

    # shellcheck source=/dev/null
    source "${conffile}"

    cd "$(dirname "${conffile}")" # working dir = dir of the conffile

    # Normalize log_file (relative to conffile dir now). Use -m because the
    # file need not exist yet; create_log_file will create it.
    log_file="$(realpath -m "${log_file}")"

    create_log_file
    __log_success "Found configuration file: ${conffile}\n"
}

function create_log_file() {
    if [[ -z "${log_file}" ]]; then
        __log_error "log_file is not set"
        __summary_error 1
    fi

    if ! mkdir -p "${log_file%/*}"; then
        __log_error "${log_file}: Cannot create log file directory"
        __summary_error 1
    fi

    : > "${log_file}"
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
        symlink_file "${file}" "${destination_dir}${file#"${origin_dir}"}"
    done < <(find "${origin_dir}" -type f -print0)
}

function symlink_file() {
    local -r origin_file="$1"
    local -r destination_file="$2"
    local dir="${destination_file%"${destination_file##*/}"}"
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

# Detects the distro if not yet detected, currently supports debian, fedora or arch
function detect_distro_family() {
    if [[ -n "${dotmgr_distro_family}" ]]; then
        return 0
    fi

    local -r os_release="${DOTMGR_OS_RELEASE:-/etc/os-release}"
    local id="" id_like=""
    local key value

    if [[ ! -r "${os_release}" ]]; then
        __log_error "Cannot read os-release file: ${os_release}"
        return 1
    fi

    while IFS='=' read -r key value; do
        # Strip surrounding double quotes, if any.
        value="${value%\"}"
        value="${value#\"}"
        case "${key}" in
            ID) id="${value}" ;;
            ID_LIKE) id_like="${value}" ;;
        esac
    done < "${os_release}"

    # ID first, then each ID_LIKE token; first supported family wins.
    local token
    for token in "${id}" ${id_like}; do
        case "${token}" in
            debian | fedora | arch)
                dotmgr_distro_family="${token}"
                __log_info "Detected distro family: ${dotmgr_distro_family}"
                return 0
                ;;
        esac
    done

    __log_error "Unsupported distribution: ID='${id:-unknown}' does not map to a supported family (debian, fedora, arch)"
    return 1
}

# Prints the distro family, for usage in dotfile scripts
function distro_family() {
    detect_distro_family || return

    printf '%s' "${dotmgr_distro_family}"
}

function install_packages() {
    local -r packages=("$@")
    local packages_not_installed=()

    if ! detect_distro_family; then
        return 1
    fi

    if [[ ${#packages[@]} -eq 0 ]]; then
        __log_success "All packages are already installed"
        return 0
    fi

    for package in "${packages[@]}"; do
        if ! check_package "${package}"; then
            __log_info "${package}: Not installed"
            packages_not_installed+=("${package}")
        else
            __log_info "${package}: Already installed"
        fi
    done

    if [[ ${#packages_not_installed[@]} -eq 0 ]]; then
        __log_success "All packages are already installed"
        return 0
    fi

    if ! __have_privileges; then
        __log_warning "Could not install packages, no sudo rights"
        return 1
    fi

    __log_info "Installing packages: ${packages_not_installed[*]}"
    if ! pm_install "${packages_not_installed[@]}"; then
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

# Failing the update doesn't fail the install, we use the cached index in that
# case. Use DEBIAN_FRONTEND and -y to prevent prompts.
function pm_install_debian() {
    run_privileged apt-get update || true
    run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

function pm_install_fedora() {
    run_privileged dnf install -y "$@"
}

# For arch we don't refresh the database because we would need to upgrade
# everything. It is up to the user to decide when to refresh to database.
function pm_install_arch() {
    run_privileged pacman -S --needed --noconfirm "$@"
}

# Installs known-missing packages through the detected family's backend.
function pm_install() {
    case "${dotmgr_distro_family}" in
        debian) pm_install_debian "$@" ;;
        fedora) pm_install_fedora "$@" ;;
        arch) pm_install_arch "$@" ;;
        *)
            __log_error "Unsupported distro family for package install: '${dotmgr_distro_family}'"
            return 1
            ;;
    esac
}

function pm_check_debian() {
    local -r package="$1"
    dpkg-query -W --showformat='${Status}\n' "${package}" 2>/dev/null \
        | grep -q "install ok installed"
}

function pm_check_fedora() {
    local -r package="$1"
    rpm -q "${package}" > /dev/null 2>&1
}

function pm_check_arch() {
    local -r package="$1"
    pacman -Q "${package}" > /dev/null 2>&1
}

function check_package() {
    local -r package="$1"

    if [[ -z "${dotmgr_distro_family}" ]] && ! detect_distro_family; then
        return 1
    fi

    case "${dotmgr_distro_family}" in
        debian) pm_check_debian "${package}" ;;
        fedora) pm_check_fedora "${package}" ;;
        arch) pm_check_arch "${package}" ;;
        *)
            __log_error "Unsupported distro family for package check: '${dotmgr_distro_family}'"
            return 1
            ;;
    esac
}

function run_scripts() {
    local -r scripts=("$@")
    local idx=0

    for script in "${scripts[@]}"; do
        # Get the arguments for this script from the parallel array
        local -a script_args=()
        if [[ -n "${parameter_script_args[idx]:-}" ]]; then
            # Split the stored args back into an array
            read -ra script_args <<< "${parameter_script_args[idx]}"
        fi
        ((idx++)) || true

        if ! run_script "${script}" "${script_args[@]}"; then
            __summary_error 1
        fi
    done
}

function run_script() {
    local -r script="$1"
    shift
    local script_params=("$@")
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


    # Disable exit on error when sourcing the script. The caller decides whether to exit or not.
    set +e

    __log_info "Running script: ${script} ${script_params[*]}"
    set -- "${script_params[@]}"
    # shellcheck source=/dev/null
    if source "${script_path}"; then
        __log_success "Script executed: ${script}\n"
        popd > /dev/null  # Make sure we are always at the original dir after script execution
        set -e
        return 0
    else
        __log_error "Script executed with errors: ${script}\n"
        popd > /dev/null  # Make sure we are always at the original dir after script execution
        set -e
        return 1
    fi
}

function install_main() {
    # Show help if requested or no action options given
    if [[ "${parameter_help}" == true \
              || ("${parameter_dotfiles}" == false \
                      && ${#parameter_packages[@]} -eq 0 \
                      && ${#parameter_scripts[@]} -eq 0) ]]; then
        show_help
        exit 0
    fi

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
                current_script="$2"
                shift 2
                # Collect remaining arguments for this script
                script_args_list=()
                while [[ $# -gt 0 && "$1" != -* ]]; do
                    script_args_list+=("$1")
                    shift
                done
                # Store script name and args separately
                parameter_scripts+=("${current_script}")
                parameter_script_args+=("${script_args_list[*]}")
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
    readonly parameter_script_args
}

function main() {
    parse_arguments "$@"
    install_main
}

#################################################################################
trap '__log_error "User aborted." && exit 1' SIGINT SIGTERM

main "$@"
