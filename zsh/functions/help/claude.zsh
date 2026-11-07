# Help module: Claude session functions
# ---

_fh_claude_keywords="cs claude session search renamed all here"

function _fh_claude() {
    local BOLD="\033[1m"
    local GREEN="\033[38;5;114m"
    local YELLOW="\033[38;5;221m"
    local CYAN="\033[38;5;116m"
    local RESET="\033[0m"

    echo -e "${GREEN}${BOLD}Claude Session Functions${RESET}"
    echo -e "${YELLOW}────────────────────────${RESET}"
    echo ""
    echo -e "  ${CYAN}cs search${RESET} <keyword>                Search sessions by keyword"
    echo -e "  ${CYAN}cs all${RESET}                             List all sessions across all projects"
    echo -e "  ${CYAN}cs here${RESET}                            List sessions for current directory"
    echo -e "  ${CYAN}cs renamed${RESET}                         List sessions with custom names"
    echo ""
    echo -e "${YELLOW}Quick tips:${RESET}"
    echo "  • Search is fuzzy across file content"
    echo "  • Shows most recent interaction time"
    echo "  • Returns to original directory on open"
    echo "  • Use /rename <name> in Claude to name a session"
    echo "  • cs all shows every session grouped by project"
    echo "  • cs here filters to current directory only"
}
