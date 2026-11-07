#
# rpg - Random Password Generator: interactive password generation
#
rpg() {
    setopt localoptions nonomatch noxtrace noverbose 2>/dev/null

    local B=$'\033[1m' D=$'\033[2m' R=$'\033[0m'

    # Select generation method
    local method=$(echo -e "tr\nopenssl" | fzf \
        --height=~50% --reverse --no-info \
        --header=$'Select generation method:\n\n'"${B}↑↓${R} ${D}Navigate${R} | ${B}Enter${R}/${B}→${R} ${D}Select${R} | ${B}Esc${R} ${D}Cancel${R}" \
        --pointer="▶" --color="fg+:yellow,pointer:yellow" \
        --bind="right:accept,esc:abort")

    [[ -z "$method" ]] && return 1

    # Select special characters option
    local special=$(echo -e "yes\nno" | fzf \
        --height=~50% --reverse --no-info \
        --header=$'Include special characters?\n\n'"${B}↑↓${R} ${D}Navigate${R} | ${B}Enter${R}/${B}→${R} ${D}Select${R} | ${B}Esc${R} ${D}Cancel${R}" \
        --pointer="▶" --color="fg+:yellow,pointer:yellow" \
        --bind="right:accept,esc:abort")

    [[ -z "$special" ]] && return 1

    # Get length from user
    local length=$(fzf \
        --height=~50% --reverse --print-query --style=minimal --no-info \
        --header="${B}Enter${R} ${D}password length (default: 32)${R} | ${B}Esc${R} ${D}to cancel${R}" \
        --ghost="Password length..." \
        --prompt="▶ " --color="fg+:yellow,prompt:yellow" \
        --bind="esc:abort" < /dev/null | head -1)

    [[ -z "$length" ]] && length=32

    if ! [[ "$length" =~ ^[0-9]+$ ]]; then
        echo "✗ Invalid length: $length (must be a number)"
        return 1
    fi

    local password=""
    case "$method" in
        tr)
            if [[ "$special" == "yes" ]]; then
                password=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c "$length"; echo)
            else
                password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"; echo)
            fi
            ;;
        openssl)
            if [[ "$special" == "yes" ]]; then
                password=$(openssl rand -base64 "$length")
            else
                password=$(openssl rand -base64 "$((length * 2))" | tr -d '+/=' | head -c "$length"; echo)
            fi
            ;;
    esac

    echo ""
    echo -e "${B}Generated Password:${R}"
    echo "$password"
    echo ""
    echo "$password" | pbcopy
    echo "✓ Copied to clipboard"
}
