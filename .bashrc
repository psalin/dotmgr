# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Source bashrc configuration files
bashrc_location=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

for file in "${bashrc_location}/.bash/"*; do
    source "${file}"
done

# Source specific terminal configuration files (home, work...)
specific_terminal_config_file="${HOME}/bin/specific-terminal-config"

if [ -e ${specific_terminal_config_file} ]; then
    source ${specific_terminal_config_file}
fi
