# Wrapper for cd that strips trailing slashes before passing to zoxide
# Falls back to builtin cd if zoxide fails (for paths like ../foo)
function cd() {
    local target="${1%/}"  # Strip trailing slash
    if [[ -z "$target" ]]; then
        z
    elif [[ -d "$target" ]] || [[ "$target" = '-' ]]; then
        builtin cd "$target"
    else
        local tmpfile=$(mktemp)
        z "$target" 2>"$tmpfile"
        local ret=$?
        local err=$(<"$tmpfile")
        rm -f "$tmpfile"
        if [[ $ret -ne 0 ]]; then
            # Zoxide failed — fall back to builtin cd
            builtin cd "$target"
            return $?
        fi
        if [[ -n "$err" && "$err" != *"already in the only match"* ]]; then
            echo "$err" >&2
        fi
        [[ "$err" == *"already in the only match"* ]] && return 0
        return $ret
    fi
}
