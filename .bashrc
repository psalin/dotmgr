# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Source bashrc configuration files
DOTFILES_DIR="${HOME}/.dotfiles"
config_files=(
    .aliases.sh
    .environment.sh
    .exports.sh
    .functions.sh
    .prompt.sh
    .software-config.sh
)

for file in "${config_files[@]}"; do
    source "${DOTFILES_DIR}/${file}"
done

# Load extra configuration
for file in "${DOTFILES_DIR}/extra-config"; do
    source "${file}"
done
