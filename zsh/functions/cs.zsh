# Claude Session Manager (cs)
# Search and open Claude sessions by keyword or custom name
#
# Usage:
#   cs search <keyword> [keyword2 ...]  - Find sessions containing ALL keywords
#   cs named                            - List sessions with custom names
#   cs delete [session-id|name]          - Delete session (interactive if no arg)
#   cs here                             - List sessions for current directory
#
# Dependencies: rg (ripgrep), jq, fzf

# --- Colors (global) ---
typeset -g _CS_GREEN="\033[38;5;114m"
typeset -g _CS_YELLOW="\033[38;5;221m"
typeset -g _CS_CYAN="\033[38;5;116m"
typeset -g _CS_RED="\033[38;5;203m"
typeset -g _CS_MAGENTA="\033[38;5;205m"
typeset -g _CS_ORANGE="\033[38;5;208m"
typeset -g _CS_RESET="\033[0m"

# --- Helper: fzf selector with toggle between # and text filtering ---
# Usage: _cs_fzf <alt_field_name> [--expect-left] [--no-expand] [--pos=N] [--show-hide=Show|Hide]
# Reads from stdin, outputs: line1=key_pressed (alt-d/alt-c/left/empty), line2=selected_line
function _cs_fzf() {
    local alt_field="$1"
    local has_left=0 has_expand=1 start_pos=0 show_hide="Show" toggle_nth="2,3"

    # Parse optional flags
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --expect-left) has_left=1 ;;
            --no-expand) has_expand=0 ;;
            --pos=*) start_pos="${1#--pos=}" ;;
            --show-hide=*) show_hide="${1#--show-hide=}" ;;
            --toggle-nth=*) toggle_nth="${1#--toggle-nth=}" ;;
        esac
        shift
    done

    # Bold styling for keys, dim for descriptors
    local B=$'\033[1m' D=$'\033[2m' R=$'\033[0m'

    # Build header based on flags
    local header="${B}↑↓${R} ${D}Navigate${R} | ${B}Enter${R}/${B}→${R} ${D}Select${R}"
    [[ $has_left -eq 1 ]] && header+=" | ${B}←${R} ${D}Back${R}"
    header+=" | ${B}⌥ Opt-d${R} ${D}Delete${R}"
    [[ $has_expand -eq 1 ]] && header+=" | ${B}⌥ Opt-c${R} ${D}${show_hide} Count${R}"
    header+=" | ${B}Tab${R} ${D}Toggle # / $alt_field${R} | ${B}Esc${R} ${D}Cancel${R}"

    # Build expect_keys based on flags
    local expect_keys="alt-d"
    [[ $has_left -eq 1 ]] && expect_keys+=",left"
    [[ $has_expand -eq 1 ]] && expect_keys+=",alt-c"

    # Build command string
    local cmd="fzf --no-multi"
    cmd+=" --height=~50% --reverse --no-info"
    cmd+=" --exact --tiebreak=index --cycle"
    cmd+=" --ansi --header=\"$header\""
    cmd+=" --prompt=\"[Filter by #] \" --pointer=\"▶\""
    cmd+=" --color=\"fg+:yellow,pointer:yellow\""
    cmd+=" --delimiter='\t' --nth=1"
    cmd+=" --bind=\"esc:abort,right:accept\""
    cmd+=" --bind='tab:transform:[[ \$FZF_PROMPT =~ \"#\" ]] && echo \"change-prompt([Filter by $alt_field] )+change-nth($toggle_nth)+clear-query\" || echo \"change-prompt([Filter by #] )+change-nth(1)+clear-query\"'"
    cmd+=" --expect=$expect_keys"
    [[ $start_pos -gt 0 ]] && cmd+=" --sync --bind 'start:pos($start_pos)'"

    eval "$cmd"
}

# --- Helper: Extract selection number from "[N]|..." format ---
function _cs_extract_selection() {
    local selected="$1"
    local num="${selected#\[}"
    echo "${num%%\]*}"
}

# --- Helper: Confirm and delete a session file ---
# Usage: _cs_confirm_delete <session_file> <display_name> [cwd]
function _cs_confirm_delete() {
    local session_file="$1"
    local display_name="$2"
    local cwd="$3"

    [[ -z "$cwd" ]] && cwd=$(grep -m1 '"cwd"' "$session_file" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
    local short_path="${cwd/#$HOME/~}"

    echo -ne "Delete ${_CS_CYAN}$display_name${_CS_RESET} in ${_CS_YELLOW}$short_path${_CS_RESET}? [y/N]: "
    read -r confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$session_file" && {
            echo -e "${_CS_GREEN}Deleted.${_CS_RESET}"
            return 0
        } || {
            echo -e "${_CS_RED}Failed to delete.${_CS_RESET}"
            return 1
        }
    else
        echo -e "${_CS_YELLOW}Cancelled.${_CS_RESET}"
        return 1
    fi
}

# --- Helper: Open a session file ---
function _cs_open_session() {
    local session_file="$1"
    local display_name="${2:-}"  # Optional display name (for renamed sessions)

    local session_id=$(basename "$session_file" .jsonl)
    local session_cwd=$(grep -m1 '"cwd"' "$session_file" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
    local temp_dir_created=""
    local original_dir="$PWD"

    if [[ -n "$session_cwd" && "$session_cwd" != "null" && -d "$session_cwd" ]]; then
        cd "$session_cwd" || return 1
    elif [[ -n "$session_cwd" && "$session_cwd" != "null" ]]; then
        # Directory doesn't exist - try to create it temporarily so claude can find the session
        echo -e "${_CS_YELLOW}Warning: $session_cwd not found, creating temporarily...${_CS_RESET}"
        mkdir -p "$session_cwd" 2>/dev/null
        if [[ -d "$session_cwd" ]]; then
            cd "$session_cwd" || return 1
            temp_dir_created="$session_cwd"
        else
            echo -e "${_CS_RED}Error: Cannot create $session_cwd${_CS_RESET}"
            return 1
        fi
    fi

    local name="${display_name:-$session_id}"
    echo -e "${_CS_GREEN}Opening session: ${_CS_CYAN}$name${_CS_RESET}"
    claude --resume "$session_id"

    # Clean up temporarily created directory (only if empty)
    if [[ -n "$temp_dir_created" && -d "$temp_dir_created" ]]; then
        # Go back to original directory first
        cd "$original_dir" 2>/dev/null || cd "$HOME"
        # Only remove the leaf directory we created, not parents
        rmdir "$temp_dir_created" 2>/dev/null || true
    fi
}

# --- Helper: Get relative time since last Claude response ---
function _cs_last_interaction() {
    local session_file="$1"
    local iso_timestamp=$(tac "$session_file" 2>/dev/null | grep '"type":"assistant"' | grep -v '"model":"<synthetic>"' | head -1 | jq -r '.timestamp // empty' 2>/dev/null)

    local mtime
    if [[ -z "$iso_timestamp" ]]; then
        mtime=$(stat -f %m "$session_file" 2>/dev/null)
        [[ -z "$mtime" ]] && { echo "unknown"; return; }
    else
        mtime=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${iso_timestamp:0:19}" +%s 2>/dev/null)
        [[ -z "$mtime" ]] && { echo "unknown"; return; }
    fi

    local now=$(date +%s)
    local diff=$((now - mtime))

    if   [[ $diff -lt 60 ]];     then echo "now"
    elif [[ $diff -lt 3600 ]];   then echo "$((diff / 60))m ago"
    elif [[ $diff -lt 86400 ]];  then echo "$((diff / 3600))h ago"
    elif [[ $diff -lt 604800 ]]; then echo "$((diff / 86400))d ago"
    else echo "$((diff / 604800))w ago"
    fi
}

# --- Helper: Check if match is in chat vs tool context ---
function _cs_match_location() {
    local session_file="$1"
    local search_term="$2"
    local matching_lines=$(rg -i -F "$search_term" "$session_file" 2>/dev/null)

    [[ -z "$matching_lines" ]] && { echo "context"; return; }

    local in_chat=0 in_context=0
    while IFS= read -r line; do
        if echo "$line" | rg -q 'tool_result|tool_use_id|"content":"[0-9]+\\t' 2>/dev/null; then
            in_context=1
        else
            in_chat=1
        fi
    done <<< "$matching_lines"

    if   [[ $in_chat -eq 1 && $in_context -eq 1 ]]; then echo "both"
    elif [[ $in_chat -eq 1 ]]; then echo "chat"
    else echo "context"
    fi
}

# --- Helper: Format location indicator ---
function _cs_format_location() {
    local has_chat="$1"
    local has_context="$2"

    local loc=""
    [[ "$has_chat" -eq 1 ]] && loc="${_CS_GREEN}[chat]${_CS_RESET}"
    if [[ "$has_context" -eq 1 ]]; then
        [[ -n "$loc" ]] && loc="$loc ${_CS_YELLOW}[context]${_CS_RESET}" || loc="${_CS_YELLOW}[context]${_CS_RESET}"
    fi
    echo "$loc"
}

# --- Helper: Get custom title for a session file (if any) ---
function _cs_get_custom_title() {
    local session_file="$1"
    local title_line=$(grep '"type":"custom-title"' "$session_file" 2>/dev/null | tail -1)
    [[ -z "$title_line" ]] && return
    local custom_title=$(echo "$title_line" | jq -r '.customTitle // empty' 2>/dev/null)
    [[ -n "$custom_title" && "$custom_title" != "null" ]] && echo "$custom_title"
}

# --- Main entry point ---
function cs() {
    setopt localoptions noxtrace noverbose 2>/dev/null

    # Check dependencies
    local missing_deps=()
    command -v rg  &>/dev/null || missing_deps+=("rg (brew install ripgrep)")
    command -v jq  &>/dev/null || missing_deps+=("jq (brew install jq)")
    command -v fzf &>/dev/null || missing_deps+=("fzf (brew install fzf)")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${_CS_RED}Missing dependencies:${_CS_RESET}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${_CS_YELLOW}$dep${_CS_RESET}"
        done
        return 1
    fi

    case "${1:-}" in
        search)
            shift
            [[ $# -eq 0 ]] && { echo -e "${_CS_RED}Usage: cs search <keyword> [...]${_CS_RESET}"; return 1; }
            _cs_search "$@"
            ;;
        all)
            _cs_all
            ;;
        named)
            _cs_renamed
            ;;
        delete)
            shift
            _cs_delete "$1"
            ;;
        here)
            _cs_here
            ;;
        *)
            echo -e "${_CS_CYAN}Usage:${_CS_RESET}"
            echo "  cs search <keyword> [...]  - Find sessions with ALL keywords"
            echo "  cs all                     - List all sessions"
            echo "  cs named                   - List named sessions"
            echo "  cs delete [session-id|name] - Delete session (interactive if no arg)"
            echo "  cs here                    - List sessions for current directory"
            ;;
    esac
}

# --- Search sessions by keyword(s) ---
function _cs_search() {
    setopt localoptions noxtrace noverbose 2>/dev/null

    local search_terms=("$@")
    local projects_dir="$HOME/.claude/projects"

    [[ ! -d "$projects_dir" ]] && { echo -e "${_CS_RED}Error: $projects_dir not found${_CS_RESET}"; return 1; }

    # Find files matching first term, then filter by remaining terms (AND logic)
    local candidates=($(rg -i -F -l --glob '*.jsonl' "${search_terms[1]}" "$projects_dir" 2>/dev/null | sort))
    local matches=()

    if [[ ${#search_terms[@]} -gt 1 ]]; then
        for file in "${candidates[@]}"; do
            local all_match=1
            for ((t = 2; t <= ${#search_terms[@]}; t++)); do
                rg -i -F -q "${search_terms[$t]}" "$file" 2>/dev/null || { all_match=0; break; }
            done
            [[ $all_match -eq 1 ]] && matches+=("$file")
        done
    else
        matches=("${candidates[@]}")
    fi

    [[ ${#matches[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions found matching: ${_CS_CYAN}${search_terms[*]}${_CS_RESET}"; return 1; }

    # Pre-calculate occurrence data for all matched files (cache for instant expansion)
    # Optimized: single pass per file, categorize all terms at once
    typeset -A cache_chat_count cache_context_count cache_last_interact cache_loc_indicator

    # Build a single regex pattern for context detection (compiled once)
    local context_pattern='tool_result|tool_use_id|"content":"[0-9]+\\t'
    local file_has_chat file_has_context is_context cache_key

    for match in "${matches[@]}"; do
        # Cache last interaction time
        cache_last_interact[$match]=$(_cs_last_interaction "$match")

        # Initialize counts for all terms
        file_has_chat=0
        file_has_context=0
        for term in "${search_terms[@]}"; do
            cache_chat_count["$match:$term"]=0
            cache_context_count["$match:$term"]=0
        done

        # Single pass through file - check each line against all terms
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            # Determine if this line is context (once per line)
            is_context=0
            if [[ "$line" =~ $context_pattern ]]; then
                is_context=1
            fi

            # Check each term against this line
            for term in "${search_terms[@]}"; do
                # Case-insensitive match using zsh pattern
                if [[ "${line:l}" == *"${term:l}"* ]]; then
                    cache_key="$match:$term"
                    if [[ $is_context -eq 1 ]]; then
                        (( cache_context_count["$cache_key"]++ ))
                        file_has_context=1
                    else
                        (( cache_chat_count["$cache_key"]++ ))
                        file_has_chat=1
                    fi
                fi
            done
        done < "$match"

        cache_loc_indicator[$match]=$(_cs_format_location "$file_has_chat" "$file_has_context")
    done

    # Group by cwd (use cached location data)
    typeset -A cwd_files_map cwd_has_chat cwd_has_context
    local display_order=()

    for match in "${matches[@]}"; do
        local file_cwd=$(grep -m1 '"cwd"' "$match" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
        [[ -z "$file_cwd" || "$file_cwd" == "null" ]] && file_cwd="$HOME"

        if [[ -z "${cwd_files_map[$file_cwd]}" ]]; then
            cwd_files_map[$file_cwd]="$match"
            cwd_has_chat[$file_cwd]=0
            cwd_has_context[$file_cwd]=0
            display_order+=("$file_cwd")
        else
            cwd_files_map[$file_cwd]="${cwd_files_map[$file_cwd]},$match"
        fi

        # Derive chat/context from cached counts
        for term in "${search_terms[@]}"; do
            local cache_key="$match:$term"
            [[ ${cache_chat_count["$cache_key"]} -gt 0 ]] && cwd_has_chat[$file_cwd]=1
            [[ ${cache_context_count["$cache_key"]} -gt 0 ]] && cwd_has_context[$file_cwd]=1
        done
    done

    # Main selection loop
    local i j
    local max_width=${#${#display_order[@]}}
    typeset -A cwd_expanded  # Track which projects are expanded
    local last_selection=0
    local last_selected_cwd=""

    while true; do
        local terms_display="$(IFS=', '; echo "${search_terms[*]}")"
        echo -e "${_CS_GREEN}Found ${#display_order[@]} project(s) with ${#matches[@]} session(s) matching: \033[2m${_CS_MAGENTA}${terms_display}${_CS_RESET}"
        echo ""

        local fzf_input=""
        for ((i = 1; i <= ${#display_order[@]}; i++)); do
            local cwd="${display_order[$i]}"
            local files="${cwd_files_map[$cwd]}"
            local match_count=$(echo "$files" | tr ',' '\n' | wc -l | tr -d ' ')
            local clean_path="${cwd/#$HOME/~}"
            local loc_indicator=$(_cs_format_location "${cwd_has_chat[$cwd]}" "${cwd_has_context[$cwd]}")

            local padded_num=$(printf "%${max_width}d" $i)
            local style_prefix=""
            local style_suffix=""
            if [[ "${cwd_expanded[$cwd]}" == "1" ]]; then
                style_prefix="\033[1m"
                style_suffix="\033[0m"
            fi
            echo -e "${style_prefix}${_CS_YELLOW}[${padded_num}]${_CS_RESET} ${style_prefix}${_CS_CYAN}$clean_path${_CS_RESET} $loc_indicator — ${match_count} session(s)"

            # Show expanded breakdown if this project is expanded (using cache)
            if [[ "${cwd_expanded[$cwd]}" == "1" ]]; then
                local exp_files=()
                IFS=',' read -rA exp_files <<< "$files"
                local max_term_len=0
                for term in "${search_terms[@]}"; do
                    [[ ${#term} -gt $max_term_len ]] && max_term_len=${#term}
                done
                for exp_file in "${exp_files[@]}"; do
                    local exp_session_id=$(basename "$exp_file" .jsonl)
                    local exp_last_interact="${cache_last_interact[$exp_file]}"
                    local exp_loc_indicator="${cache_loc_indicator[$exp_file]}"
                    echo -e "    $(printf '%*s' $max_width '')\033[38;5;231m$exp_session_id${_CS_RESET} $exp_loc_indicator \033[2m${_CS_MAGENTA}($exp_last_interact)${_CS_RESET}"
                    for term in "${search_terms[@]}"; do
                        local cache_key="$exp_file:$term"
                        local chat_count="${cache_chat_count["$cache_key"]}"
                        local context_count="${cache_context_count["$cache_key"]}"
                        local total=$((chat_count + context_count))
                        local breakdown=""
                        if [[ $chat_count -gt 0 && $context_count -gt 0 ]]; then
                            breakdown="($chat_count ${_CS_GREEN}chat${_CS_RESET}, $context_count ${_CS_YELLOW}context${_CS_RESET})"
                        elif [[ $chat_count -gt 0 ]]; then
                            breakdown="(${_CS_GREEN}chat${_CS_RESET})"
                        elif [[ $context_count -gt 0 ]]; then
                            breakdown="(${_CS_YELLOW}context${_CS_RESET})"
                        fi
                        printf "    $(printf '%*s' $max_width '')  \033[1m${_CS_MAGENTA}%-${max_term_len}s${_CS_RESET}  \033[1m${_CS_ORANGE}%3d${_CS_RESET} %b\n" "$term" "$total" "$breakdown"
                    done
                done
            fi

            fzf_input+="[$padded_num]"$'\t'"$clean_path"$'\n'
        done

        # Determine show/hide text based on last selected item's state
        local show_hide_text="Show"
        [[ -n "$last_selected_cwd" && "${cwd_expanded[$last_selected_cwd]}" == "1" ]] && show_hide_text="Hide"

        local selected=$(echo -n "$fzf_input" | _cs_fzf "cwd" --pos=$last_selection --show-hide=$show_hide_text)
        local key_pressed=$(echo "$selected" | head -1)
        local selection_line=$(echo "$selected" | tail -1)

        [[ -z "$selection_line" ]] && return 0

        local selection=$(_cs_extract_selection "$selection_line")
        local selected_cwd="${display_order[$selection]}"
        local files_str="${cwd_files_map[$selected_cwd]}"
        local matching_files=()
        IFS=',' read -rA matching_files <<< "$files_str"

        # Handle delete at project level - only allowed for single session
        if [[ "$key_pressed" == "alt-d" ]]; then
            if [[ ${#matching_files[@]} -eq 1 ]]; then
                local session_id=$(basename "${matching_files[1]}" .jsonl)
                _cs_confirm_delete "${matching_files[1]}" "$session_id" "$selected_cwd" && {
                    unset "cwd_files_map[$selected_cwd]"
                    unset "cwd_has_chat[$selected_cwd]"
                    unset "cwd_has_context[$selected_cwd]"
                    display_order=("${(@)display_order:#$selected_cwd}")
                    matches=("${(@)matches:#${matching_files[1]}}")
                    [[ ${#display_order[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions remaining.${_CS_RESET}"; return 0; }
                }
            else
                echo -e "${_CS_YELLOW}Multiple sessions in project. Select a specific session to delete.${_CS_RESET}"
            fi
            continue
        fi

        # Handle expand/collapse at project level
        if [[ "$key_pressed" == "alt-c" ]]; then
            if [[ "${cwd_expanded[$selected_cwd]}" == "1" ]]; then
                cwd_expanded[$selected_cwd]=0
            else
                cwd_expanded[$selected_cwd]=1
            fi
            last_selection=$selection
            last_selected_cwd="$selected_cwd"
            continue
        fi

        # Single file - open directly
        if [[ ${#matching_files[@]} -eq 1 ]]; then
            _cs_open_session "${matching_files[1]}"
            return 0
        fi

        # Multiple sessions - show session list (inner loop)
        while true; do
            echo ""
            echo -e "${_CS_CYAN}Multiple matching sessions in this project:${_CS_RESET}"
            echo ""

            local session_fzf_input=""
            local session_max_width=${#${#matching_files[@]}}

            for ((j = 1; j <= ${#matching_files[@]}; j++)); do
                local session_file="${matching_files[$j]}"
                local session_id=$(basename "$session_file" .jsonl)
                local last_interact="${cache_last_interact[$session_file]}"
                local loc_indicator="${cache_loc_indicator[$session_file]}"

                local padded_j=$(printf "%${session_max_width}d" $j)
                echo -e "  ${_CS_YELLOW}[${padded_j}]${_CS_RESET} $session_id $loc_indicator ${_CS_CYAN}($last_interact)${_CS_RESET}"

                # Per-keyword breakdown (from cache)
                local max_term_len=0
                for term in "${search_terms[@]}"; do
                    [[ ${#term} -gt $max_term_len ]] && max_term_len=${#term}
                done
                for term in "${search_terms[@]}"; do
                    local cache_key="$session_file:$term"
                    local chat_count="${cache_chat_count["$cache_key"]}"
                    local context_count="${cache_context_count["$cache_key"]}"
                    local total=$((chat_count + context_count))
                    local breakdown=""
                    if [[ $chat_count -gt 0 && $context_count -gt 0 ]]; then
                        breakdown="($chat_count ${_CS_GREEN}chat${_CS_RESET}, $context_count ${_CS_YELLOW}context${_CS_RESET})"
                    elif [[ $chat_count -gt 0 ]]; then
                        breakdown="(${_CS_GREEN}chat${_CS_RESET})"
                    elif [[ $context_count -gt 0 ]]; then
                        breakdown="(${_CS_YELLOW}context${_CS_RESET})"
                    fi
                    printf "      ${_CS_MAGENTA}%-${max_term_len}s${_CS_RESET}  ${_CS_ORANGE}%3d${_CS_RESET} %b\n" "$term" "$total" "$breakdown"
                done

                session_fzf_input+="[$padded_j]"$'\t'"$session_id ($last_interact)"$'\n'
            done

            local session_selected=$(echo -n "$session_fzf_input" | _cs_fzf "session" --expect-left --no-expand)
            local sess_key_pressed=$(echo "$session_selected" | head -1)
            local sess_selection_line=$(echo "$session_selected" | tail -1)

            [[ "$sess_key_pressed" == "left" ]] && break  # Go back to project level
            [[ -z "$sess_selection_line" ]] && return 0

            local session_selection=$(_cs_extract_selection "$sess_selection_line")

            # Handle delete at session level
            if [[ "$sess_key_pressed" == "alt-d" ]]; then
                local del_file="${matching_files[$session_selection]}"
                local del_session_id=$(basename "$del_file" .jsonl)
                _cs_confirm_delete "$del_file" "$del_session_id" "$selected_cwd" && {
                    # Remove from matching_files array
                    matching_files[$session_selection]=()
                    matching_files=("${(@)matching_files:#}")
                    # Update cwd_files_map
                    cwd_files_map[$selected_cwd]="${(j:,:)matching_files}"
                    # Remove from global matches
                    matches=("${(@)matches:#$del_file}")
                    # If no more files in this project, remove from display_order
                    if [[ ${#matching_files[@]} -eq 0 ]]; then
                        unset "cwd_files_map[$selected_cwd]"
                        unset "cwd_has_chat[$selected_cwd]"
                        unset "cwd_has_context[$selected_cwd]"
                        display_order=("${(@)display_order:#$selected_cwd}")
                        [[ ${#display_order[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions remaining.${_CS_RESET}"; return 0; }
                        # No more sessions in this project - go back to project list
                        break
                    fi
                }
                # Stay at session level
                continue
            fi

            _cs_open_session "${matching_files[$session_selection]}"
            return 0
        done
    done
}

# --- List all sessions ---
function _cs_all() {
    setopt localoptions noxtrace noverbose 2>/dev/null

    local projects_dir="$HOME/.claude/projects"

    [[ ! -d "$projects_dir" ]] && { echo -e "${_CS_RED}Error: $projects_dir not found${_CS_RESET}"; return 1; }

    # Find all session files
    local all_files=($(find "$projects_dir" -name "*.jsonl" -type f 2>/dev/null | sort))

    [[ ${#all_files[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions found.${_CS_RESET}"; return 1; }

    # Cache last interaction times
    typeset -A cache_last_interact

    for file in "${all_files[@]}"; do
        cache_last_interact[$file]=$(_cs_last_interaction "$file")
    done

    # Group by cwd
    typeset -A cwd_files_map
    local display_order=()

    for file in "${all_files[@]}"; do
        local file_cwd=$(grep -m1 '"cwd"' "$file" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
        [[ -z "$file_cwd" || "$file_cwd" == "null" ]] && file_cwd="$HOME"

        if [[ -z "${cwd_files_map[$file_cwd]}" ]]; then
            cwd_files_map[$file_cwd]="$file"
            display_order+=("$file_cwd")
        else
            cwd_files_map[$file_cwd]="${cwd_files_map[$file_cwd]},$file"
        fi
    done

    # Main selection loop
    local i j
    local max_width=${#${#display_order[@]}}

    while true; do
        echo -e "${_CS_GREEN}Found ${#display_order[@]} project(s) with ${#all_files[@]} session(s)${_CS_RESET}"
        echo ""

        local fzf_input=""
        for ((i = 1; i <= ${#display_order[@]}; i++)); do
            local cwd="${display_order[$i]}"
            local files="${cwd_files_map[$cwd]}"
            local session_count=$(echo "$files" | tr ',' '\n' | wc -l | tr -d ' ')
            local clean_path="${cwd/#$HOME/~}"

            local padded_num=$(printf "%${max_width}d" $i)
            echo -e "${_CS_YELLOW}[${padded_num}]${_CS_RESET} ${_CS_CYAN}$clean_path${_CS_RESET} — ${session_count} session(s)"

            fzf_input+="[$padded_num]"$'\t'"$clean_path"$'\n'
        done

        local selected=$(echo -n "$fzf_input" | _cs_fzf "cwd" --no-expand)
        local key_pressed=$(echo "$selected" | head -1)
        local selection_line=$(echo "$selected" | tail -1)

        [[ -z "$selection_line" ]] && return 0

        local selection=$(_cs_extract_selection "$selection_line")
        local selected_cwd="${display_order[$selection]}"
        local files_str="${cwd_files_map[$selected_cwd]}"
        local matching_files=()
        IFS=',' read -rA matching_files <<< "$files_str"

        # Handle delete at project level - only allowed for single session
        if [[ "$key_pressed" == "alt-d" ]]; then
            if [[ ${#matching_files[@]} -eq 1 ]]; then
                local session_id=$(basename "${matching_files[1]}" .jsonl)
                _cs_confirm_delete "${matching_files[1]}" "$session_id" "$selected_cwd" && {
                    unset "cwd_files_map[$selected_cwd]"
                    display_order=("${(@)display_order:#$selected_cwd}")
                    all_files=("${(@)all_files:#${matching_files[1]}}")
                    [[ ${#display_order[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions remaining.${_CS_RESET}"; return 0; }
                }
            else
                echo -e "${_CS_YELLOW}Multiple sessions in project. Select a specific session to delete.${_CS_RESET}"
            fi
            continue
        fi

        # Single file - open directly
        if [[ ${#matching_files[@]} -eq 1 ]]; then
            _cs_open_session "${matching_files[1]}"
            return 0
        fi

        # Multiple sessions - show session list (inner loop)
        while true; do
            echo ""
            echo -e "${_CS_CYAN}Sessions in this project:${_CS_RESET}"
            echo ""

            local session_fzf_input=""
            local session_max_width=${#${#matching_files[@]}}

            for ((j = 1; j <= ${#matching_files[@]}; j++)); do
                local session_file="${matching_files[$j]}"
                local session_id=$(basename "$session_file" .jsonl)
                local last_interact="${cache_last_interact[$session_file]}"
                local custom_title=$(_cs_get_custom_title "$session_file")

                local padded_j=$(printf "%${session_max_width}d" $j)
                if [[ -n "$custom_title" ]]; then
                    echo -e "  ${_CS_YELLOW}[${padded_j}]${_CS_RESET} \033[38;5;231m$session_id${_CS_RESET} ${_CS_CYAN}($custom_title)${_CS_RESET} \033[2m${_CS_MAGENTA}($last_interact)${_CS_RESET}"
                    session_fzf_input+="[$padded_j]"$'\t'"$session_id ($custom_title) ($last_interact)"$'\n'
                else
                    echo -e "  ${_CS_YELLOW}[${padded_j}]${_CS_RESET} \033[38;5;231m$session_id${_CS_RESET} \033[2m${_CS_MAGENTA}($last_interact)${_CS_RESET}"
                    session_fzf_input+="[$padded_j]"$'\t'"$session_id ($last_interact)"$'\n'
                fi
            done

            local session_selected=$(echo -n "$session_fzf_input" | _cs_fzf "session" --expect-left --no-expand)
            local sess_key_pressed=$(echo "$session_selected" | head -1)
            local sess_selection_line=$(echo "$session_selected" | tail -1)

            [[ "$sess_key_pressed" == "left" ]] && break  # Go back to project level
            [[ -z "$sess_selection_line" ]] && return 0

            local session_selection=$(_cs_extract_selection "$sess_selection_line")

            # Handle delete at session level
            if [[ "$sess_key_pressed" == "alt-d" ]]; then
                local del_file="${matching_files[$session_selection]}"
                local del_session_id=$(basename "$del_file" .jsonl)
                _cs_confirm_delete "$del_file" "$del_session_id" "$selected_cwd" && {
                    # Remove from matching_files array
                    matching_files[$session_selection]=()
                    matching_files=("${(@)matching_files:#}")
                    # Update cwd_files_map
                    cwd_files_map[$selected_cwd]="${(j:,:)matching_files}"
                    # Remove from global all_files
                    all_files=("${(@)all_files:#$del_file}")
                    # If no more files in this project, remove from display_order
                    if [[ ${#matching_files[@]} -eq 0 ]]; then
                        unset "cwd_files_map[$selected_cwd]"
                        display_order=("${(@)display_order:#$selected_cwd}")
                        [[ ${#display_order[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions remaining.${_CS_RESET}"; return 0; }
                        break
                    fi
                }
                continue
            fi

            _cs_open_session "${matching_files[$session_selection]}"
            return 0
        done
    done
}

# --- Delete session by ID ---
function _cs_delete() {
    local session_id="$1"
    local projects_dir="$HOME/.claude/projects"

    # If no argument, show interactive selector
    if [[ -z "$session_id" ]]; then
        local all_files=($(find "$projects_dir" -name "*.jsonl" -type f 2>/dev/null | sort))
        [[ ${#all_files[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions found.${_CS_RESET}"; return 1; }

        echo -e "${_CS_GREEN}Select session to delete:${_CS_RESET}"
        echo ""

        local fzf_input=""
        local max_width=${#${#all_files[@]}}

        # First pass: cache data and calculate column widths
        typeset -A cache_title cache_path cache_time
        local max_name_len=0
        local max_path_len=0
        local max_time_len=0

        for ((i = 1; i <= ${#all_files[@]}; i++)); do
            local session_file="${all_files[$i]}"
            local custom_title=$(_cs_get_custom_title "$session_file")
            local file_cwd=$(grep -m1 '"cwd"' "$session_file" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
            local clean_path="${file_cwd/#$HOME/~}"
            local last_interact=$(_cs_last_interaction "$session_file")

            cache_title[$session_file]="$custom_title"
            cache_path[$session_file]="$clean_path"
            cache_time[$session_file]="$last_interact"

            # Track max widths for alignment
            [[ ${#custom_title} -gt $max_name_len ]] && max_name_len=${#custom_title}
            [[ ${#clean_path} -gt $max_path_len ]] && max_path_len=${#clean_path}
            [[ ${#last_interact} -gt $max_time_len ]] && max_time_len=${#last_interact}
        done

        # Add space for parentheses around custom_title
        [[ $max_name_len -gt 0 ]] && ((max_name_len += 3))  # for "() "

        # Second pass: display with aligned columns
        for ((i = 1; i <= ${#all_files[@]}; i++)); do
            local session_file="${all_files[$i]}"
            local sid=$(basename "$session_file" .jsonl)
            local custom_title="${cache_title[$session_file]}"
            local clean_path="${cache_path[$session_file]}"
            local last_interact="${cache_time[$session_file]}"

            local padded_i=$(printf "%${max_width}d" $i)
            local name_field=""
            if [[ -n "$custom_title" ]]; then
                name_field="($custom_title)"
            fi

            # Aligned echo output
            printf "  ${_CS_YELLOW}[%s]${_CS_RESET} \033[38;5;231m%s${_CS_RESET} ${_CS_CYAN}%-${max_name_len}s${_CS_RESET} \033[2m%-${max_path_len}s\033[0m \033[2m${_CS_MAGENTA}(%s)${_CS_RESET}\n" \
                "$padded_i" "$sid" "$name_field" "$clean_path" "$last_interact"

            # fzf input (simple display like cs here session view)
            if [[ -n "$custom_title" ]]; then
                fzf_input+="[$padded_i]"$'\t'"$sid ($custom_title) ($last_interact)"$'\n'
            else
                fzf_input+="[$padded_i]"$'\t'"$sid ($last_interact)"$'\n'
            fi
        done

        local selected=$(echo -n "$fzf_input" | _cs_fzf "session" --no-expand)
        local key_pressed=$(echo "$selected" | head -1)
        local selection_line=$(echo "$selected" | tail -1)

        [[ -z "$selection_line" ]] && return 0

        local selection=$(_cs_extract_selection "$selection_line")
        local selected_file="${all_files[$selection]}"
        session_id=$(basename "$selected_file" .jsonl)

        # Handle delete (either Enter or ⌥d)
        if [[ "$key_pressed" == "alt-d" || -z "$key_pressed" ]]; then
            _cs_confirm_delete "$selected_file" "$session_id"
        fi
        return 0
    fi

    # Direct delete by session-id or custom name
    local session_file=$(find "$projects_dir" -name "${session_id}.jsonl" -type f 2>/dev/null | head -1)

    # If not found by ID, try finding by custom name
    if [[ -z "$session_file" ]]; then
        for f in "$projects_dir"/*/*.jsonl; do
            [[ ! -f "$f" ]] && continue
            local title=$(_cs_get_custom_title "$f")
            if [[ "$title" == "$session_id" ]]; then
                session_file="$f"
                break
            fi
        done
    fi

    if [[ -z "$session_file" ]]; then
        echo -e "${_CS_RED}Session not found: ${_CS_CYAN}$session_id${_CS_RESET}"
        return 1
    fi

    _cs_confirm_delete "$session_file" "$session_id"
}

# --- List sessions for current directory ---
function _cs_here() {
    setopt localoptions noxtrace noverbose 2>/dev/null

    local projects_dir="$HOME/.claude/projects"
    local current_dir="$PWD"

    # Find all sessions with cwd matching current directory
    local session_files=()
    for f in "$projects_dir"/*/*.jsonl; do
        [[ ! -f "$f" ]] && continue
        local file_cwd=$(grep -m1 '"cwd"' "$f" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
        [[ "$file_cwd" == "$current_dir" ]] && session_files+=("$f")
    done

    [[ ${#session_files[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions found for: ${_CS_CYAN}${current_dir/#$HOME/~}${_CS_RESET}"; return 1; }

    # Single session - open directly
    if [[ ${#session_files[@]} -eq 1 ]]; then
        local session_id=$(basename "${session_files[1]}" .jsonl)
        echo -e "${_CS_GREEN}Found 1 session for: ${_CS_CYAN}${current_dir/#$HOME/\~}${_CS_RESET}"
        _cs_open_session "${session_files[1]}"
        return 0
    fi

    # Multiple sessions - show fzf list
    while true; do
        [[ ${#session_files[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No sessions remaining.${_CS_RESET}"; return 0; }

        echo -e "${_CS_GREEN}Found ${#session_files[@]} session(s) for: ${_CS_CYAN}${current_dir/#$HOME/\~}${_CS_RESET}"
        echo ""

        local fzf_input=""
        local max_width=${#${#session_files[@]}}

        for ((i = 1; i <= ${#session_files[@]}; i++)); do
            local session_file="${session_files[$i]}"
            local session_id=$(basename "$session_file" .jsonl)
            local last_interact=$(_cs_last_interaction "$session_file")
            local custom_title=$(_cs_get_custom_title "$session_file")

            local padded_i=$(printf "%${max_width}d" $i)
            if [[ -n "$custom_title" ]]; then
                echo -e "  ${_CS_YELLOW}[${padded_i}]${_CS_RESET} $session_id ${_CS_CYAN}($custom_title)${_CS_RESET} \033[2m${_CS_MAGENTA}($last_interact)${_CS_RESET}"
                fzf_input+="[$padded_i]"$'\t'"$session_id ($custom_title) ($last_interact)"$'\n'
            else
                echo -e "  ${_CS_YELLOW}[${padded_i}]${_CS_RESET} $session_id \033[2m${_CS_MAGENTA}($last_interact)${_CS_RESET}"
                fzf_input+="[$padded_i]"$'\t'"$session_id ($last_interact)"$'\n'
            fi
        done

        local selected=$(echo -n "$fzf_input" | _cs_fzf "session" --no-expand)
        local key_pressed=$(echo "$selected" | head -1)
        local selection_line=$(echo "$selected" | tail -1)

        [[ -z "$selection_line" ]] && return 0

        local selection=$(_cs_extract_selection "$selection_line")

        # Handle delete
        if [[ "$key_pressed" == "alt-d" ]]; then
            local del_file="${session_files[$selection]}"
            local del_session_id=$(basename "$del_file" .jsonl)
            _cs_confirm_delete "$del_file" "$del_session_id" "$current_dir" && {
                session_files[$selection]=()
                session_files=("${(@)session_files:#}")
            }
            echo ""
            continue
        fi

        _cs_open_session "${session_files[$selection]}"
        return 0
    done
}

# --- List renamed sessions ---
function _cs_renamed() {
    setopt localoptions noxtrace noverbose 2>/dev/null

    local projects_dir="$HOME/.claude/projects"
    local renamed_sessions=()

    for project_dir in "$projects_dir"/*; do
        [[ ! -d "$project_dir" ]] && continue

        local session_files=($(find "$project_dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null))

        for session_file in "${session_files[@]}"; do
            local custom_title_lines=$(grep '"type":"custom-title"' "$session_file" 2>/dev/null)

            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local custom_title=$(echo "$line" | jq -r '.customTitle' 2>/dev/null)
                local session_id=$(echo "$line" | jq -r '.sessionId' 2>/dev/null)

                if [[ -n "$custom_title" && "$custom_title" != "null" && -n "$session_id" && "$session_id" != "null" ]]; then
                    renamed_sessions+=("$custom_title|$session_id|$session_file")
                fi
            done < <(echo "$custom_title_lines")
        done
    done

    if [[ ${#renamed_sessions[@]} -eq 0 ]]; then
        echo -e "${_CS_YELLOW}No renamed sessions found.${_CS_RESET}"
        echo ""
        echo "To rename a session, use within Claude:"
        echo -e "${_CS_CYAN}  /rename <new-name>${_CS_RESET}"
        return 0
    fi

    # Deduplicate: keep latest per session_id
    typeset -A seen_ids
    local unique_sessions=()

    for ((i = ${#renamed_sessions[@]}; i >= 1; i--)); do
        local entry="${renamed_sessions[$i]}"
        local session_id="${entry#*|}"
        session_id="${session_id%%|*}"

        [[ -z "${seen_ids[$session_id]}" ]] && {
            unique_sessions+=("$entry")
            seen_ids[$session_id]=1
        }
    done

    IFS=$'\n' sorted_sessions=($(printf '%s\n' "${unique_sessions[@]}" | sort))
    unset IFS

    while true; do
        [[ ${#sorted_sessions[@]} -eq 0 ]] && { echo -e "${_CS_YELLOW}No renamed sessions remaining.${_CS_RESET}"; return 0; }

        echo -e "${_CS_GREEN}Found ${#sorted_sessions[@]} renamed session(s):${_CS_RESET}"
        echo ""

        local fzf_input=""
        local renamed_max_width=${#${#sorted_sessions[@]}}

        # Calculate max custom_title length for alignment
        local max_name_len=0
        for ((j = 1; j <= ${#sorted_sessions[@]}; j++)); do
            local entry="${sorted_sessions[$j]}"
            local title="${entry%%|*}"
            [[ ${#title} -gt $max_name_len ]] && max_name_len=${#title}
        done

        for ((i = 1; i <= ${#sorted_sessions[@]}; i++)); do
            local entry="${sorted_sessions[$i]}"
            local custom_title="${entry%%|*}"
            local session_file="${entry##*|}"
            local last_interact=$(_cs_last_interaction "$session_file")

            local padded_i=$(printf "%${renamed_max_width}d" $i)
            printf "  ${_CS_YELLOW}[%s]${_CS_RESET} ${_CS_CYAN}%-${max_name_len}s${_CS_RESET} \033[2m${_CS_MAGENTA}(%s)${_CS_RESET}\n" \
                "$padded_i" "$custom_title" "$last_interact"
            fzf_input+="[$padded_i]"$'\t'"$(printf "%-${max_name_len}s" "$custom_title")"$'\t'"($last_interact)"$'\n'
        done

        local selected=$(echo -n "$fzf_input" | _cs_fzf "name" --no-expand --toggle-nth=2)
        local key_pressed=$(echo "$selected" | head -1)
        local selection_line=$(echo "$selected" | tail -1)

        [[ -z "$selection_line" ]] && return 0

        local selection=$(_cs_extract_selection "$selection_line")
        local entry="${sorted_sessions[$selection]}"
        local custom_title="${entry%%|*}"
        local session_file="${entry##*|}"

        # Handle delete
        if [[ "$key_pressed" == "alt-d" ]]; then
            _cs_confirm_delete "$session_file" "$custom_title" && {
                sorted_sessions[$selection]=()
                sorted_sessions=("${(@)sorted_sessions:#}")
            }
            echo ""
            continue
        fi

        _cs_open_session "$session_file" "$custom_title"
        return 0
    done
}
