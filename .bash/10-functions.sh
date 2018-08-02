# Show git brach
function parse_git_branch
{
    git branch --no-color 2>/dev/null | grep \* | sed "s/\* \(.*\)/ (\1)/"
}

function weather
{
    local args=${@:-}
    curl "wttr.in/${args}"
}
