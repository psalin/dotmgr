# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Source bashrc configuration files
dotfiles_dir="${HOME}/.dotfiles"
config_files=(
    .aliases.sh
    .environment.sh
    .exports.sh
    .functions.sh
    .prompt.sh
    .software-config.sh
)

for file in "${config_files[@]}"; do
    source "${dotfiles_dir}/${file}"
done

# Load extra configuration
extraconfig_dir="${dotfiles_dir}/extra-config"
if [ "$(ls "${extraconfig_dir}")" ]; then
    for file in "${extraconfig_dir}"/*; do
        source "${file}"
    done
fi
