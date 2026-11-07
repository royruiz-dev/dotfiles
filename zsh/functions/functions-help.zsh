# Functions help and discovery (dynamic loader)
# ---
# Loads help modules from:
#   ~/.zsh/functions/help/*.zsh  (general, git-tracked)
#   ~/.zsh/local/help/*.zsh      (machine-specific, gitignored)

# Source all help modules
for _fh_file in ~/.zsh/functions/help/*.zsh(N); do source "$_fh_file"; done
if [[ -d ~/.zsh/local/help ]]; then
    for _fh_file in ~/.zsh/local/help/*.zsh(N); do source "$_fh_file"; done
fi
unset _fh_file

function fh() {
    local category="${1:-}"

    # Colors
    local BOLD="\033[1m"
    local GREEN="\033[38;5;114m"
    local YELLOW="\033[38;5;221m"
    local CYAN="\033[38;5;116m"
    local BLUE="\033[38;5;33m"
    local RESET="\033[0m"

    if [[ -z "$category" || "$category" == "help" || "$category" == "-h" ]]; then
        echo -e "${CYAN}${BOLD}fh${RESET} - Function help and discovery"
        echo ""
        echo -e "${YELLOW}Usage:${RESET}"
        echo "  fh                    Show all available functions by category"
        echo "  fh <category>         Show functions in a specific category"
        echo "  fh list               List all categories"
        echo "  fh search <keyword>   Search functions by keyword"
        echo "  fh <function>         Show help for specific function (if available)"
        echo ""
        echo -e "${YELLOW}Examples:${RESET}"
        echo "  fh utilities          Show utility functions"
        echo "  fh claude             Show Claude session functions"
        echo "  fh search history     Find all history-related functions"
        return 0
    fi

    if [[ "$category" == "list" ]]; then
        echo -e "${GREEN}Available function categories:${RESET}"
        echo ""
        # General (always available)
        echo -e "  ${CYAN}claude${RESET}                 Claude session search and management"
        echo -e "  ${CYAN}utilities${RESET}              Shell utilities and helpers"
        # Machine-specific (only if loaded)
        [[ $(type -w _fh_git 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}git${RESET}                    Git workflow (push, sync, rebase)"
        [[ $(type -w _fh_concourse 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}concourse${RESET}              Concourse/Fly CI/CD operations"
        [[ $(type -w _fh_jumpbox 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}jumpbox${RESET}                SSH jumpbox and Docker connections"
        [[ $(type -w _fh_aws 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}aws${RESET}                    AWS credential and profile management"
        [[ $(type -w _fh_vault 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}vault${RESET}                  Vault credential fetching"
        [[ $(type -w _fh_kube 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}kube${RESET}                   Kubernetes context and shoot management"
        [[ $(type -w _fh_bins 2>/dev/null) == *function* ]] && \
            echo -e "  ${CYAN}bins${RESET}                   Custom binaries in ~/bin"
        echo ""
        echo -e "  ${CYAN}all${RESET}                    Show everything"
        echo ""
        return 0
    fi

    if [[ "$category" == "search" ]]; then
        local keyword="$2"
        if [[ -z "$keyword" ]]; then
            echo -e "${YELLOW}Error: search term required${RESET}"
            echo "Usage: fh search <keyword>"
            return 1
        fi
        _fh_search "$keyword"
        return 0
    fi

    case "$category" in
        git|workflow)
            [[ $(type -w _fh_git 2>/dev/null) == *function* ]] && _fh_git || echo "Git help not available"
            ;;
        claude|cs|session)
            _fh_claude
            ;;
        concourse|fly|f)
            [[ $(type -w _fh_concourse 2>/dev/null) == *function* ]] && _fh_concourse || echo "Concourse help not available"
            ;;
        jumpbox|jb)
            [[ $(type -w _fh_jumpbox 2>/dev/null) == *function* ]] && _fh_jumpbox || echo "Jumpbox help not available"
            ;;
        aws|awsp)
            [[ $(type -w _fh_aws 2>/dev/null) == *function* ]] && _fh_aws || echo "AWS help not available"
            ;;
        vault|vac)
            [[ $(type -w _fh_vault 2>/dev/null) == *function* ]] && _fh_vault || echo "Vault help not available"
            ;;
        utilities|utils)
            _fh_utilities
            ;;
        kube|kubernetes|k8s)
            [[ $(type -w _fh_kube 2>/dev/null) == *function* ]] && _fh_kube || echo "Kubernetes help not available"
            ;;
        bins|bin|binaries)
            [[ $(type -w _fh_bins 2>/dev/null) == *function* ]] && _fh_bins || echo "Bins help not available"
            ;;
        all)
            _fh_all
            ;;
        *)
            # Try to show help for the function directly
            if declare -f "$category" > /dev/null 2>&1; then
                echo -e "${BLUE}Function: ${CYAN}$category${RESET}"
                echo ""
                "$category" --help 2>/dev/null || "$category" help 2>/dev/null || echo "No help available for $category"
            else
                echo -e "${YELLOW}Unknown category or function: $category${RESET}"
                echo "Run ${CYAN}fh list${RESET} to see available categories"
            fi
            ;;
    esac
}

function _fh_all() {
    local RESET="\033[0m"
    local first=true

    # General (always available)
    _fh_claude
    echo ""
    _fh_utilities

    # Machine-specific (only if loaded)
    if [[ $(type -w _fh_git 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_git
    fi
    if [[ $(type -w _fh_concourse 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_concourse
    fi
    if [[ $(type -w _fh_jumpbox 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_jumpbox
    fi
    if [[ $(type -w _fh_aws 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_aws
    fi
    if [[ $(type -w _fh_vault 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_vault
    fi
    if [[ $(type -w _fh_kube 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_kube
    fi
    if [[ $(type -w _fh_bins 2>/dev/null) == *function* ]]; then
        echo ""
        _fh_bins
    fi
}

function _fh_search() {
    local keyword="$1"
    local BOLD="\033[1m"
    local GREEN="\033[38;5;114m"
    local YELLOW="\033[38;5;221m"
    local CYAN="\033[38;5;116m"
    local RESET="\033[0m"

    echo -e "${GREEN}${BOLD}Search results for: '${keyword}'${RESET}"
    echo ""

    local found=0

    # Check each module's keywords and call if matched
    if [[ -n "$_fh_claude_keywords" ]] && echo "$_fh_claude_keywords" | grep -qiw "$keyword"; then
        _fh_claude
        found=1
    fi

    if [[ -n "$_fh_utilities_keywords" ]] && echo "$_fh_utilities_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_utilities
        found=1
    fi

    if [[ -n "$_fh_git_keywords" ]] && echo "$_fh_git_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_git
        found=1
    fi

    if [[ -n "$_fh_concourse_keywords" ]] && echo "$_fh_concourse_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_concourse
        found=1
    fi

    if [[ -n "$_fh_jumpbox_keywords" ]] && echo "$_fh_jumpbox_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_jumpbox
        found=1
    fi

    if [[ -n "$_fh_aws_keywords" ]] && echo "$_fh_aws_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_aws
        found=1
    fi

    if [[ -n "$_fh_vault_keywords" ]] && echo "$_fh_vault_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_vault
        found=1
    fi

    if [[ -n "$_fh_kube_keywords" ]] && echo "$_fh_kube_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_kube
        found=1
    fi

    if [[ -n "$_fh_bins_keywords" ]] && echo "$_fh_bins_keywords" | grep -qiw "$keyword"; then
        [[ $found -eq 1 ]] && echo ""
        _fh_bins
        found=1
    fi

    if [[ $found -eq 0 ]]; then
        echo -e "${YELLOW}No functions found matching '${keyword}'${RESET}"
    fi
}
