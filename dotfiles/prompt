#!/bin/bash

# Show git brach
function parse_git_branch() {
    git branch --no-color 2>/dev/null | grep \* | sed "s/\* \(.*\)/ (\1)/"
}

function set_prompt() {
    local hostname=${1:-"\\h"}
    local prompt_color=${2:-"32"}

    if ! dpkg -l | grep -E "^ii\s\sgit\s+" &> /dev/null; then
        export PS1="\[\033[01;${prompt_color}m\]\u@${hostname}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
    else
        export PS1="\[\033[01;${prompt_color}m\]\u@${hostname}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$(parse_git_branch)\$ "
    fi
}


set_prompt
