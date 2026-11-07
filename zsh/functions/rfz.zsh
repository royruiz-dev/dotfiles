rfz() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: rfz [pattern]"
    echo "Removes directories from zoxide database (interactive multi-select)"
    echo ""
    echo "Arguments:"
    echo "  pattern    Optional filter for paths (case-insensitive substring match)"
    echo ""
    echo "Backups are saved to ~/Library/Application Support/zoxide/db.zo.bak before each deletion"
    return 0
  fi

  local pattern="$1"
  local zoxide_db="$HOME/Library/Application Support/zoxide/db.zo"

  if [[ ! -f "$zoxide_db" ]]; then
    echo "Zoxide database not found: $zoxide_db"
    return 1
  fi

  # Styling (same as rfh)
  local B=$'\033[1m' D=$'\033[2m' R=$'\033[0m'
  local CYAN=$'\033[38;5;116m' YELLOW=$'\033[38;5;221m' RED=$'\033[38;5;203m'

  # Parse zoxide db to get rank, timestamp, path
  local entries
  local pyscript='import struct, datetime, sys
db_path = sys.argv[1]
with open(db_path, "rb") as f:
    data = f.read()
pos = 4
count = struct.unpack("<Q", data[pos:pos+8])[0]; pos += 8
items = []
for i in range(count):
    path_len = struct.unpack("<Q", data[pos:pos+8])[0]; pos += 8
    path = data[pos:pos+path_len].decode("utf-8"); pos += path_len
    rank = struct.unpack("<d", data[pos:pos+8])[0]; pos += 8
    ts = struct.unpack("<Q", data[pos:pos+8])[0]; pos += 8
    items.append((rank, ts, path))
items.sort(key=lambda x: -x[0])
for rank, ts, path in items:
    dt = datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M")
    print(f"{rank:.1f}|{dt}|{path}")'

  entries=$(/usr/bin/python3 -c "$pyscript" "$zoxide_db" 2>&1)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to parse zoxide database${R}"
    echo "$entries"
    return 1
  fi

  # Filter by pattern if provided
  if [[ -n "$pattern" ]]; then
    entries=$(echo "$entries" | /usr/bin/grep -i "$pattern")
  fi

  if [[ -z "$entries" ]]; then
    echo -e "${D}No matches found.${R}"
    return 0
  fi

  local entry_count=$(echo "$entries" | /usr/bin/wc -l | /usr/bin/tr -d ' ')

  # Build header with styling
  local header="${D}Remove directories from zoxide${R}"
  if [[ -n "$pattern" ]]; then
    header+=": ${B}${CYAN}${pattern}${R}"
  fi
  header+=$'\n\n'
  header+="  ${B}↑↓${R} ${D}Navigate${R} │ ${B}Tab${R} ${D}Select${R} │ ${B}Ctrl-A${R} ${D}All${R} │ ${B}Enter${R} ${D}Confirm${R} │ ${B}Esc${R} ${D}Cancel${R}"
  header+=$'\n\n'
  header+="  ${YELLOW}💡 Tip:${R} ${D}Backup saved to${R} ${B}~/Library/Application Support/zoxide/db.zo.bak${R}"
  header+=$'\n'
  header+="          ${D}Restore with${R} ${B}cp ~/Library/Application\\ Support/zoxide/db.zo.bak ~/Library/Application\\ Support/zoxide/db.zo${R}"
  header+=$'\n\n'
  header+="  ${D}Total entries:${R} ${B}${entry_count}${R}"
  header+=$'\n'

  # Format entries for fzf: idx|score|date|path -> display as "score  date  path"
  local idx=0
  local fzf_input=""
  while IFS='|' read -r score dt zpath; do
    ((idx++))
    # Truncate path for display
    local display_path="${zpath:0:70}"
    [[ ${#zpath} -gt 70 ]] && display_path+="…"
    fzf_input+="${idx}|${zpath}|${D}${score}${R}  ${D}${dt}${R}  ${display_path}"$'\n'
  done <<< "$entries"

  # Use fzf for multi-select
  local selected
  selected=$(echo -n "$fzf_input" | /opt/homebrew/bin/fzf --multi --ansi \
    --height=~50% --reverse --no-info \
    --prompt='' \
    --header="$header" \
    --pointer="▶" --marker="✓" \
    --color="fg+:yellow,pointer:yellow,marker:cyan" \
    --with-nth=3.. --delimiter='|' \
    --bind="ctrl-a:toggle-all,esc:abort")

  [[ -z "$selected" ]] && { echo -e "${D}Cancelled.${R}"; return 0; }

  # Extract paths to delete
  local -a paths_to_delete=()
  while IFS='|' read -r idx zpath _; do
    paths_to_delete+=("$zpath")
  done <<< "$selected"

  local delete_count=${#paths_to_delete[@]}

  # Create backup before modifying
  /bin/cp "$zoxide_db" "${zoxide_db}.bak"
  echo -e "${D}Backup saved to ${zoxide_db}.bak${R}"

  # Remove each selected path
  local removed=0
  for zpath in "${paths_to_delete[@]}"; do
    if /opt/homebrew/bin/zoxide remove "$zpath" 2>/dev/null; then
      ((removed++))
    fi
  done

  echo -e "${B}${CYAN}✓ Removed ${YELLOW}$removed${R}${B}${CYAN} path(s) from zoxide${R}"
}
