# Dotfiles

## 1. Installation instructions
- Clone this repository:

      git clone https://github.com/jsanjoseg/dotfiles ~/.dotfiles

- Run installation script:

      cd .dotfiles/ && ./install.sh

## 2. gnome-terminal profile
- To backup profile:

      dconf dump /org/gnome/terminal/legacy/profiles:/ > \
      ~/.dotfiles/.gnome-terminal-profile.dconf

- To restore profile (done with installation script):

      dconf load /org/gnome/terminal/legacy/profiles:/ < \
      ~/.dotfiles/.gnome-terminal-profile.dconf
