hst() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: hst [start] [end]"
    echo "Browse shell history within a date/time range (Berlin time)"
    echo ""
    echo "Arguments:"
    echo "  start    Start date/time"
    echo "  end      End date/time (optional, defaults to now)"
    echo ""
    echo "If no arguments given, prompts interactively for range."
    echo ""
    echo "Supported formats:"
    echo "  2024-01-15              Date only (starts at 00:00)"
    echo "  2024-01-15 14:00        Date and time"
    echo "  today 14:00             Relative date with time"
    echo "  yesterday               Relative date"
    echo "  2 hours ago             Relative time"
    echo ""
    echo "Examples:"
    echo "  hst                           # Interactive prompts"
    echo "  hst 'today 14:00'             # From 2 PM today to now"
    echo "  hst '2024-01-15'              # From Jan 15 to now"
    echo "  hst '2024-01-15' '2024-01-16' # Between Jan 15-16"
    echo "  hst '2 hours ago'             # Last 2 hours"
    return 0
  fi

  local histfile="${HISTFILE:-$HOME/.zsh_history}"
  local tz="Europe/Berlin"

  # Styling
  local B=$'\033[1m' D=$'\033[2m' R=$'\033[0m'
  local CYAN=$'\033[38;5;116m' YELLOW=$'\033[38;5;221m' RED=$'\033[38;5;203m'
  local GREEN=$'\033[38;5;114m'

  _hst_parse_date() {
    local input="$1"
    local ts=""
    if command -v gdate &>/dev/null; then
      ts=$(TZ=$tz gdate -d "$input" "+%s" 2>/dev/null)
    fi
    if [[ -z "$ts" ]]; then
      ts=$(TZ=$tz date -j -f "%Y-%m-%d %H:%M" "$input" "+%s" 2>/dev/null)
    fi
    if [[ -z "$ts" ]]; then
      ts=$(TZ=$tz date -j -f "%Y-%m-%d" "$input" "+%s" 2>/dev/null)
    fi
    echo "$ts"
  }

  fc -W

  local start_ts end_ts

  if [[ -z "$1" ]]; then
    echo -e "${D}Enter start date/time (Berlin):${R}"
    echo -e "${D}  Examples: 'today 14:00', '2024-01-15', 'yesterday', '2 hours ago'${R}"
    read -r "start_input?> "
    [[ -z "$start_input" ]] && { echo -e "${D}Cancelled.${R}"; return 0; }

    echo -e "${D}Enter end date/time (Berlin, empty for now):${R}"
    read -r "end_input?> "

    start_ts=$(_hst_parse_date "$start_input")
    if [[ -z "$end_input" ]]; then
      end_ts=$(date "+%s")
    else
      end_ts=$(_hst_parse_date "$end_input")
    fi
  else
    local start_input="$1"
    local end_input="${2:-}"
    start_ts=$(_hst_parse_date "$start_input")
    if [[ -z "$end_input" ]]; then
      end_ts=$(date "+%s")
    else
      end_ts=$(_hst_parse_date "$end_input")
    fi
  fi

  if [[ -z "$start_ts" ]]; then
    echo -e "${RED}Could not parse start date${R}"
    return 1
  fi
  if [[ -z "$end_ts" ]]; then
    echo -e "${RED}Could not parse end date${R}"
    return 1
  fi

  local start_readable=$(TZ=$tz date -r "$start_ts" "+%Y-%m-%d %H:%M")
  local end_readable=$(TZ=$tz date -r "$end_ts" "+%Y-%m-%d %H:%M")

  # Temp files for commands and display lines
  local cmd_file=$(mktemp)
  local display_file=$(mktemp)
  local preview_file=$(mktemp)

  trap "rm -f $cmd_file $display_file $preview_file" EXIT

  # Extract matching commands
  # Awk outputs: timestamp<TAB>command per line
  # We process line by line, encoding commands as base64
  local line_num=0

  LC_ALL=C awk -v start="$start_ts" -v end="$end_ts" -v OFS='\t' '
    /^: [0-9]+:[0-9]+;/ {
      sub(/^: /, "")
      split($0, parts, ":")
      ts = parts[1]
      if (ts >= start && ts <= end) {
        idx = index($0, ";")
        cmd = substr($0, idx + 1)
        print ts, cmd
      }
    }
  ' "$histfile" > "$cmd_file.raw"

  # Calculate dynamic truncation based on terminal width
  local term_width=$(tput cols)
  local prefix_width=22  # timestamp (16) + spaces (2) + fzf chrome (4)
  local max_cmd_width=$((term_width - prefix_width))
  [[ $max_cmd_width -lt 40 ]] && max_cmd_width=40  # minimum

  # Process each line - use cut to separate fields, avoiding read interpretation issues
  while IFS= read -r rawline; do
    ((line_num++))
    local ts="${rawline%%	*}"  # everything before first tab
    local cmd="${rawline#*	}"  # everything after first tab
    local readable_time=$(TZ=$tz date -r "$ts" "+%Y-%m-%d %H:%M")
    # Store command as base64
    printf '%s' "$cmd" | base64 >> "$cmd_file"
    # Display line with dynamic truncation and slight vertical padding
    local display_cmd="${cmd:0:$max_cmd_width}"
    [[ ${#cmd} -gt $max_cmd_width ]] && display_cmd+="…"
    printf '%s│\033[2m%s\033[0m  %s\n' "$line_num" "$readable_time" "$display_cmd" >> "$display_file"
  done < "$cmd_file.raw"
  rm -f "$cmd_file.raw"

  local match_count=$line_num

  if [[ "$match_count" -eq 0 ]]; then
    echo -e "${D}No commands found between ${start_readable} and ${end_readable}${R}"
    return 0
  fi

  # Create preview script (using zsh for proper parsing)
  cat > "$preview_file" << 'PREVIEW_EOF'
#!/bin/zsh
line_num="$1"
cmd_file="$2"
PATH="$3"

# Source custom functions and aliases
for f in ~/.zsh/functions/*.zsh ~/.zsh/local/*.zsh(N); do source "$f" 2>/dev/null; done

# Colors
D=$'\033[2m' R=$'\033[0m'
GREEN=$'\033[38;5;114m' RED=$'\033[38;5;203m' YELLOW=$'\033[38;5;221m' CYAN=$'\033[38;5;116m'

# Decode base64 to get original command (still has history escaping)
cmd_escaped=$(sed -n "${line_num}p" "$cmd_file" | base64 -d)

# Unescape for validation: history stores \\ where user typed \
cmd_unescaped=$(printf '%s' "$cmd_escaped" | awk '{gsub(/\\\\/, "\\"); print}')

# Check syntax with zsh -n
syntax_ok=1
syntax_err=$(zsh -n <<< "$cmd_unescaped" 2>&1)
[[ $? -ne 0 ]] && syntax_ok=0

# Check if commands exist by parsing with zsh's (z) flag
missing_cmds=()
words=("${(z)cmd_unescaped}")
in_cmd_position=1
for word in "${words[@]}"; do
  if [[ "$word" == "|" || "$word" == ";" || "$word" == "&&" || "$word" == "||" || "$word" == $'\n' ]]; then
    in_cmd_position=1; continue
  fi
  if [[ "$word" == ">" || "$word" == "<" || "$word" == ">>" || "$word" == "2>" || "$word" == "&>" ]]; then
    in_cmd_position=0; continue
  fi
  # Skip variable assignments (VAR=value or VAR=$(cmd))
  if [[ "$word" == *=* ]]; then
    in_cmd_position=0; continue
  fi
  if (( in_cmd_position )); then
    whence "$word" &>/dev/null || missing_cmds+=("$word")
    in_cmd_position=0
  fi
done

# Display: command → <actual command>
# Manually wrap long commands with indentation to align under the command start
local prefix="${D}command →${R} "
local indent="          ${D}↳${R} "  # 10 spaces + arrow to align under command start
local term_width=$(tput cols 2>/dev/null || echo 80)
local cmd_width=$((term_width - 14))
[[ $cmd_width -lt 40 ]] && cmd_width=40

printf '%s' "$prefix"
local pos=0
local len=${#cmd_unescaped}
local first=1
while [[ $pos -lt $len ]]; do
  local chunk="${cmd_unescaped:$pos:$cmd_width}"
  if [[ $first -eq 1 ]]; then
    printf '%s\n' "$chunk"
    first=0
  else
    printf '%s%s\n' "$indent" "$chunk"
  fi
  pos=$((pos + cmd_width))
done
echo ""

# Validation result (indented under command)
if [[ $syntax_ok -eq 0 ]]; then
  echo -e "          ${RED}✗ Syntax error${R}"
  echo -e "            ${D}${syntax_err}${R}"
elif [[ ${#missing_cmds[@]} -gt 0 ]]; then
  echo -e "          ${RED}✗ Invalid command${R}"
  for c in "${missing_cmds[@]}"; do
    display_c="${c//$'\n'/\\n}"; display_c="${display_c//$'\t'/\\t}"
    printf '            %s%s%s\n' "${YELLOW}" "$display_c" "${R}"
    if [[ "$c" =~ ^[a-z]+\' ]]; then
      base_cmd="${c%%\'*}"
      whence "$base_cmd" &>/dev/null && printf '            %sTry:%s %s%s '\''...'\''%s\n' "${D}" "${R}" "${CYAN}" "$base_cmd" "${R}"
    fi
  done
else
  echo -e "          ${GREEN}✓ Valid command${R}"
fi
PREVIEW_EOF
  chmod +x "$preview_file"

  # Build header (position counter will be added dynamically via focus binding)
  local header="${D}History from${R} ${B}${CYAN}${start_readable}${R} ${D}to${R} ${B}${CYAN}${end_readable}${R} ${D}(Berlin)${R}"
  header+=$'\n\n'
  header+="  ${B}↑↓${R} ${D}Navigate${R} │ ${B}Tab${R} ${D}Select${R} │ ${B}Ctrl-A${R} ${D}All${R} │ ${B}Enter${R} ${D}Copy${R} │ ${B}Esc${R} ${D}Cancel${R}"
  header+=$'\n\n'
  header+="  ${YELLOW}💡${R} ${D}Preview shows command validation${R}"
  header+=$'\n'

  # Run fzf with multi-select
  local selected
  selected=$(cat "$display_file" | fzf --multi --ansi \
    --height=~70% --reverse --no-info \
    --gap=1 --gap-line \
    --prompt='' \
    --header="$header" \
    --pointer="▶" --marker="✓" \
    --color="fg+:yellow,pointer:yellow,marker:cyan" \
    --delimiter='│' \
    --with-nth=2.. \
    --bind="ctrl-a:toggle-all,esc:abort" \
    --bind="focus:transform-header:echo \"$header\"; echo; echo \"  ${D}Viewing:${R} ${B}\$(({n}+1))${R} ${D}/${R} ${B}${match_count}${R}\"" \
    --preview="$preview_file {1} $cmd_file \"$PATH\"" \
    --preview-window='down:12')

  [[ -z "$selected" ]] && { echo -e "${D}Cancelled.${R}"; return 0; }

  # Process all selected commands
  local -a commands=()
  while IFS= read -r line; do
    local selected_num="${line%%│*}"
    local full_cmd=$(sed -n "${selected_num}p" "$cmd_file" | base64 -d)
    # Unescape: history stores \\ where user typed \
    local full_cmd_unescaped=$(printf '%s' "$full_cmd" | awk '{gsub(/\\\\/, "\\"); print}')
    commands+=("$full_cmd_unescaped")
  done <<< "$selected"

  local count=${#commands[@]}
  local output=$(printf '%s\n' "${commands[@]}")

  printf '%s' "$output" | pbcopy
  echo -e "${B}${CYAN}✓ Copied ${count} command(s) to clipboard:${R}"
  echo ""
  echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
  printf '%s\n' "${commands[@]}"
  echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}
