#!/bin/bash

function show_script_help() {
    cat <<EOF

Available scripts:
  -s vim                    Install VIM 8 and VIM plugins
  -s gnome-terminal         Install the profile for GNOME-terminal
  -s xfce-terminal          Install the profile for xfce4-terminal
EOF
}

show_script_help
