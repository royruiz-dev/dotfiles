rfh() {
  if [[ -z "$1" ]]; then
    echo "Usage: rfh <string>"
    echo "Removes all history lines containing <string> (case-sensitive, substring match)"
    echo ""
    echo "Backups are saved to ~/.zsh_history.bak before each deletion"
    return 1
  fi

  local histfile="${HISTFILE:-$HOME/.zsh_history}"
  local search_string="$1"

  # Styling
  local B=$'\033[1m' D=$'\033[2m' R=$'\033[0m'
  local CYAN=$'\033[38;5;116m' YELLOW=$'\033[38;5;221m' RED=$'\033[38;5;203m'

  # Force history to disk first
  fc -W

  # Build arrays: group by display string, track counts
  # Use parallel arrays instead of associative arrays to avoid key issues
  local -a display_keys=()     # unique display strings
  local -a display_counts=()   # count per display key
  local -a display_raws=()     # raw lines per display key (newline-separated)

  while IFS= read -r line; do
    if [[ "$line" == *"$search_string"* ]]; then
      # Extract timestamp from history format ": timestamp:duration;command"
      local timestamp="${line#*:}"
      timestamp="${timestamp%%:*}"
      local readable_time=$(date -r "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null)
      # Extract just the command (after the semicolon)
      local command="${line#*;}"

      # Skip rfh commands themselves (trim leading spaces first)
      local cmd_trimmed="${command## }"
      [[ "$cmd_trimmed" == rfh\ * ]] && continue

      local display_cmd="${command:0:60}"
      [[ ${#command} -gt 60 ]] && display_cmd+="…"

      local display_key="${readable_time}  ${display_cmd}"

      # Find if this display_key already exists
      local found_idx=0
      for i in {1..${#display_keys[@]}}; do
        if [[ "${display_keys[$i]}" == "$display_key" ]]; then
          found_idx=$i
          break
        fi
      done

      if [[ $found_idx -eq 0 ]]; then
        # New entry
        display_keys+=("$display_key")
        display_counts+=(1)
        display_raws+=("$line")
      else
        # Existing entry - increment count and append raw line
        display_counts[$found_idx]=$((display_counts[$found_idx] + 1))
        display_raws[$found_idx]="${display_raws[$found_idx]}"$'\n'"$line"
      fi
    fi
  done < "$histfile"

  if [[ ${#display_keys[@]} -eq 0 ]]; then
    echo -e "${D}No matches found.${R}"
    return 0
  fi

  # Build header with styling
  local header="${D}Remove history matching:${R} ${B}${CYAN}${search_string}${R}"
  header+=$'\n\n'
  header+="  ${B}↑↓${R} ${D}Navigate${R} │ ${B}Tab${R} ${D}Select${R} │ ${B}Ctrl-A${R} ${D}All${R} │ ${B}Enter${R} ${D}Confirm${R} │ ${B}Esc${R} ${D}Cancel${R}"
  header+=$'\n\n'
  header+="  ${YELLOW}💡 Tip:${R} ${D}Backup saved to${R} ${B}~/.zsh_history.bak${R}"
  header+=$'\n'
  header+="          ${D}Restore with${R} ${B}cp ~/.zsh_history.bak ~/.zsh_history && exec zsh${R}"
  header+=$'\n\n'

  # Use fzf for multi-select
  local selected
  selected=$(for i in {1..${#display_keys[@]}}; do
    local dk="${display_keys[$i]}"
    local cnt="${display_counts[$i]}"
    if [[ $cnt -gt 1 ]]; then
      echo "${i}|${D}${dk%  *}${R} ${YELLOW}(${cnt}x)${R}  ${dk#*  }"
    else
      echo "${i}|${D}${dk%  *}${R}  ${dk#*  }"
    fi
  done | fzf --multi --ansi \
    --height=~50% --reverse --no-info \
    --prompt='' \
    --header="$header" \
    --pointer="▶" --marker="✓" \
    --color="fg+:yellow,pointer:yellow,marker:cyan" \
    --with-nth=2.. --delimiter='|' \
    --bind="ctrl-a:toggle-all,esc:abort")

  [[ -z "$selected" ]] && { echo -e "${D}Cancelled.${R}"; return 0; }

  # Extract indices of lines to delete
  local -a indices_to_delete=()
  while IFS= read -r sel; do
    indices_to_delete+=("${sel%%|*}")
  done <<< "$selected"

  # Build set of raw lines to delete
  local -a lines_to_delete=()
  for idx in "${indices_to_delete[@]}"; do
    # Split raw lines and add each
    while IFS= read -r raw_line; do
      [[ -n "$raw_line" ]] && lines_to_delete+=("$raw_line")
    done <<< "${display_raws[$idx]}"
  done

  local delete_count=${#lines_to_delete[@]}

  # ALWAYS create backup before modifying
  cp "$histfile" "${histfile}.bak"
  echo -e "${D}Backup saved to ${histfile}.bak${R}"

  # Create temporary file, excluding selected lines by exact match
  local temp_histfile="${histfile}.tmp.$$"
  local deleted=0

  while IFS= read -r line; do
    local should_delete=0
    for del_line in "${lines_to_delete[@]}"; do
      if [[ "$line" == "$del_line" ]]; then
        should_delete=1
        ((deleted++))
        break
      fi
    done
    if [[ $should_delete -eq 0 ]]; then
      printf '%s\n' "$line"
    fi
  done < "$histfile" > "$temp_histfile"

  # Verify the temp file looks reasonable (not empty, not drastically smaller)
  local orig_lines=$(wc -l < "$histfile")
  local new_lines=$(wc -l < "$temp_histfile")
  local expected_lines=$((orig_lines - delete_count))

  if [[ $new_lines -lt $((expected_lines - 5)) ]] || [[ $new_lines -eq 0 ]]; then
    echo -e "${RED}✗ Safety check failed: expected ~${expected_lines} lines, got ${new_lines}${R}"
    echo -e "${RED}  Original preserved. Temp file: ${temp_histfile}${R}"
    rm -f "$temp_histfile"
    return 1
  fi

  # Replace history file
  mv "$temp_histfile" "$histfile"

  # Purge in-memory history and reload from cleaned file
  local histsize_bak=$HISTSIZE
  HISTSIZE=0
  HISTSIZE=$histsize_bak
  fc -R

  echo -e "${B}${CYAN}✓ Removed ${YELLOW}$deleted${R}${B}${CYAN} line(s) from history${R}"
}
