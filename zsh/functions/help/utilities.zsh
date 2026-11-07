# Help module: Utility functions
# ---

_fh_utilities_keywords="rfh rfz rpg remove history cleanup utils utilities zoxide password generator"

function _fh_utilities() {
    local BOLD="\033[1m"
    local GREEN="\033[38;5;114m"
    local YELLOW="\033[38;5;221m"
    local CYAN="\033[38;5;116m"
    local RESET="\033[0m"

    echo -e "${GREEN}${BOLD}Utilities${RESET}"
    echo -e "${YELLOW}──────────${RESET}"
    echo ""
    echo -e "  ${CYAN}rfh${RESET} <string>                         Remove lines containing <string> from history"
    echo -e "  ${CYAN}rfz${RESET} [pattern]                         Remove directories from zoxide (interactive)"
    echo -e "  ${CYAN}rpg${RESET}                                   Interactive random password generator"
    echo ""
    echo -e "${YELLOW}Quick tips:${RESET}"
    echo "  • rfh: Case-sensitive substring matching"
    echo "  • rfh: Shows matches before confirming deletion"
    echo "  • rfh: Removed entries won't appear in Ctrl+R"
    echo "  • rfz: Shows frecency score and last access time"
    echo "  • rfz: Multi-select with fzf, backups before deletion"
    echo "  • rpg: Choose tr or openssl, with/without special chars, custom length"
}
